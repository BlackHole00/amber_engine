package amber_engine_common

import "base:intrinsics"
import "core:mem"
import "core:sync"

// A Resource_Manager is a general purpose manager for resources that have a low
// lifespan, and are frequently allocated and freed. If resources are rarely, if
// ever freed consider using Static_Resource_Manager
// @parameters: T = The resource type
//              I = The resource id type (must be unsigned)
// @note: This implementation uses generational ids to ensure performace, so the
//        generated id will not be linear. This system is inspired by the memory
//        management in the Vale language.
//        Here follows an id example:
//            Example id type (I): uint
//                uint ->  | gen | internal id  |
//                         16 bits    48 bits 
//        In every id type the first size_of(I)/4 bits are used for the 
//        generation. And the remaining bits will be used as the index on the
//        resources field.
//        Every time a resource is generated it will be associated with a 
//        generation and a location of the resources field. When that resource
//        will be removed its associated location will "age" and change its
//        generation, so the location can be reused for another resource (which
//        will use a different generation). If someone tries to gen the removed
//        resource it is possible to tell that the location does not contain the
//        required data, even if something else is occupying the resource.
//        Once a location reaches its max generation (it is no longer 
//        representable in the Id) it is considered unusable. If the first 
//        location becames unusable, the resources array field will shift its
//        elements until the first becames usable or is currently in use
//        This allows to skip an hash map lookup.
//        Inspiration: https://verdagon.dev/blog/generational-references
// @thread_safety: Thread-safe
//odinfmt: disable
Resource_Manager :: struct(
	$T: typeid, 
	$I: typeid,
) where intrinsics.type_is_ordered_numeric(I) && intrinsics.type_is_unsigned(I) {
	allocator:           mem.Allocator,
	starting_number:     uint,
	first_free_location: uint,
	resources:           #soa[dynamic]Resource_Manager_Cell(T),
	resources_mutex:     sync.Mutex,
}

// Initializes a Resource_Manager
//odinfmt: enable
resourcemanager_init :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
	allocator := context.allocator,
) {
	context.allocator = allocator
	resource_manager.allocator = allocator

	resource_manager.resources = make_soa(#soa[dynamic]Resource_Manager_Cell(U))
	resize_soa(&resource_manager.resources, 1)
}

// Frees a Resource_Manager and all its associated resources
// @thread_safe: Not thread-safe
resourcemanager_free :: proc(resource_manager: $T/Resource_Manager($U, $I)) {
	for cell in resource_manager.resources {
		rc_force_free(cell.data)
	}

	delete_soa(resource_manager.resources)
}

// Generates a new zero-initialized resource
// @retuns: The generated resource's id
// @thread_safe: Thread-safe
resourcemanager_generate_new_empty :: proc(resource_manager: $T/^Resource_Manager($U, $I)) -> I {
	resource_id, resource_ptr := resourcemanager_generate_new_empty_and_get(resource_manager)
	arc_drop(resource_ptr)

	return resource_id
}

// Generates a new resource initializes with data
// @retuns: The generated resource's id
// @thread_safe: Thread-safe
resourcemanager_generate_new_with_data :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
	resource: U,
) -> I {
	resource_id, resource_ptr := resourcemanager_generate_new_with_data_and_get(
		resource_manager,
		resource,
	)
	arc_drop(resource_ptr)

	return resource_id
}

// Generates a new zero-initialized resource and returns its associated pointer
// @retuns: I = The generated resource's id
//          ^Arc(U) = The pointer to the generated resource
// @note: The returned Arc must be dropped after it is no longer needed
// @thread_safe: Thread-safe
resourcemanager_generate_new_empty_and_get :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
) -> (
	I,
	^Arc(U),
) {
	resource_ptr := arc_new(U, resource_manager.allocator)

	if sync.guard(&resource_manager.resources_mutex) {
		resource_id, idx := resourcemanager_generate_id(resource_manager)

		resource_manager.resources[idx].data = resource_ptr

		return resource_id, arc_clone(resource_ptr)
	}

	unreachable()
}

// Generates a new resource initializes with data and returns its associated 
// pointer
// @retuns: I = The generated resource's id
//          ^Arc(U) = The pointer to the generated resource
// @note: The returned Arc must be dropped after it is no longer needed
// @thread_safe: Thread-safe
resourcemanager_generate_new_with_data_and_get :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
	resource: U,
) -> (
	I,
	^Arc(U),
) {
	resource_ptr := arc_new(U, resource_manager.allocator)
	rc_as_ptr(resource_ptr)^ = resource

	if sync.guard(&resource_manager.resources_mutex) {
		resource_id, idx := resourcemanager_generate_id(resource_manager)

		resource_manager.resources[idx].data = resource_ptr

		return resource_id, arc_clone(resource_ptr)
	}

	unreachable()
}

// Checks if an id is currently valid
// @thread_safe: Thread-safe
resourcemanager_is_id_valid :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
	id: I,
) -> bool {
	number := id_get_number(id)
	generation := id_get_generation(id)

	if sync.guard(&resource_manager.resources_mutex) {
		return(
			resourcemanager_is_id_number_and_generation_valid(
				resource_manager,
				number,
				generation,
			) &&
			resource_manager.resources[number - resource_manager.starting_number].data != nil \
		)
	}

	unreachable()
}

// Gets the pointer associated to a determined id
// @note: The returned Arc must be dropped after it is no longer needed
// @thread_safe: Thread-safe
resourcemanager_get :: proc(resource_manager: $T/^Resource_Manager($U, $I), id: I) -> ^Arc(U) {
	number := id_get_number(id)
	generation := id_get_generation(id)

	if sync.guard(&resource_manager.resources_mutex) {
		if !resourcemanager_is_id_number_and_generation_valid(
			   resource_manager,
			   number,
			   generation,
		   ) {
			return nil
		}

		return resource_manager.resources[number].data
	}

	unreachable()
}

// Removes a resource from the manager. Its id will thus be considered invalid
// @thread_safe: Thread-safe
resourcemanager_remove :: proc(resource_manager: $T/^Resource_Manager($U, $I), id: I) -> bool {
	number := id_get_number(id)
	generation := id_get_generation(id)

	if sync.guard(&resource_manager.resources_mutex) {
		if !resourcemanager_is_id_number_and_generation_valid(
			   resource_manager,
			   number,
			   generation,
		   ) {
			return false
		}

		arc_drop(resource_manager.resources[number].data)

		resource_manager.resources[number].data = nil
		resource_manager.resources[number].generation += 1

		if number != 0 {
			return true
		}

		i: uint = 0
		for resource_manager.resources[i].generation > id_get_max_generation(I) {
			i += 1
		}

		if i != 0 {
			resourcemanager_relocate_positions(resource_manager, i)
		}
	}

	return true
}

resourcemanager_generate_new :: proc {
	resourcemanager_generate_new_empty,
	resourcemanager_generate_new_with_data,
}

resourcemanager_generate_new_and_get :: proc {
	resourcemanager_generate_new_empty_and_get,
	resourcemanager_generate_new_with_data_and_get,
}

@(private = "file")
Resource_Manager_Cell :: struct($T: typeid) {
	data:       ^Arc(T),
	generation: uint,
}

// @thread_safety: Not thread-safe
@(private = "file")
resourcemanager_generate_id :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
) -> (
	id: I,
	index: uint,
) {
	number := resource_manager.first_free_location + resource_manager.starting_number
	generation := resource_manager.resources[resource_manager.first_free_location].generation

	id = id_create(I, generation, number)
	index = resource_manager.first_free_location

	i := resource_manager.first_free_location + 1
	for i < len(resource_manager.resources) &&
	    resource_manager.resources[i].data != nil &&
	    resource_manager.resources[i].generation <= id_get_max_generation(I) {
		i += 1
	}

	resource_manager.first_free_location = i

	if i >= len(resource_manager.resources) {
		resize_soa(&resource_manager.resources, (int)(i + 1))
	}

	return
}

// @thread_safety: Not thread-safe
@(private = "file")
resourcemanager_relocate_positions :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
	offset: uint,
) {
	for i in offset ..< (uint)(len(resource_manager.resources)) {
		resource_manager.resources[i - offset].data = resource_manager.resources[i].data
		resource_manager.resources[i - offset].generation =
			resource_manager.resources[i].generation
	}

	resource_manager.starting_number += offset
	resource_manager.first_free_location -= offset
}

// @thread_safety: Not thread-safe
@(private = "file")
resourcemanager_is_id_number_and_generation_valid :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
	number: uint,
	generation: uint,
) -> bool {
	return(
		resourcemanager_is_id_number_valid(resource_manager, number) &&
		resourcemanager_is_id_generation_valid(resource_manager, number, generation) \
	)
}

// @thread_safety: Not thread-safe
@(private = "file")
resourcemanager_is_id_number_valid :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
	number: uint,
) -> bool {
	return (uint)(len(resource_manager.resources)) + resource_manager.starting_number < number
}

// @thread_safety: Not thread-safe
@(private = "file")
resourcemanager_is_id_generation_valid :: proc(
	resource_manager: $T/^Resource_Manager($U, $I),
	number: uint,
	generation: uint,
) -> bool {
	return resource_manager.resources[number].generation == generation
}

@(private = "file")
id_get_generation_bits :: proc($I: typeid) -> uint where intrinsics.type_is_ordered_numeric(I) {
	return size_of(I) / 4
}

@(private = "file")
id_get_max_generation :: proc($I: typeid) -> uint where intrinsics.type_is_ordered_numeric(I) {
	return (1 << id_get_generation_bits(I)) - 1
}

@(private = "file")
id_get_number_bits :: proc($I: typeid) -> uint where intrinsics.type_is_ordered_numeric(I) {
	return (size_of(I) / 4) * 3
}

@(private = "file")
id_create :: proc(
	$I: typeid,
	generation: uint,
	number: uint,
) -> I where intrinsics.type_is_ordered_numeric(I) {
	return (I)((generation << id_get_generation_bits(I)) | number)
}

@(private = "file")
id_get_generation :: proc(id: $I) -> uint {
	return id >> id_get_number_bits(I)
}

@(private = "file")
id_get_number :: proc(id: $I) -> uint {
	return id << id_get_generation_bits(I) >> id_get_generation_bits(I)
}

_ :: intrinsics
_ :: mem
_ :: sync

