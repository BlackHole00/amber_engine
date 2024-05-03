package amber_engine_utils

import "core:mem"
import "core:mem/virtual"
import "core:sync"

// A Linear Resource Manager is a manager for static resources that are rarely, 
// if ever, removed/freed
// @parameters: T = The resource type
//              I = The resource id type
// @note: Once a resource is freed it will not be accessible to the user, but 
//        its memory will not be freed until the manager destruction. This 
//        allows to implement many performance improvements. If a manager
//        for a resource with many allocations/free is needed please use
//        Resource_Manager
// @memory_safety: All the resource are allocated by the manager and will be
//                 freed automatically
// @thread_safety: Thread-safe
Static_Resource_Manager :: struct($T: typeid, $I: typeid) {
	arena:           virtual.Arena,
	id_generator:    Id_Generator(I),
	// @index_by: I
	// @note: len(resources) = idgenerator_peek_next(id_generator)
	resources:       [dynamic]^T,
	resources_mutex: sync.Mutex,
}

// Initialializes a Static_Resource_Manager
staticresourcemanager_init :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
	allocator := context.allocator,
) {
	context.allocator = allocator

	assert(virtual.arena_init_growing(&resource_manager.arena) == .None)

	resource_manager.resources = make([dynamic]^U)
}

// Frees a Static_Resource_Manager and all the associated resources
// @thread_safety: Not thread-safe
staticresourcemanager_free :: proc(resource_manager: $T/^Static_Resource_Manager($U, $I)) {
	delete(resource_manager.resources)

	virtual.arena_destroy(&resource_manager.arena)
}

// Allocates a new resource zero-initializing it. The generated id and the 
// provided data pointer will be valid for the entire manager lifetime
// @returns: I = the resource id
//           U = the resource data ptr
// @thread_safety: Thread-safe
staticresourcemanager_generate_new_empty :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
) -> (
	I,
	^U,
) {
	resource_id := idgenerator_generate(&resource_manager.id_generator)
	resource_ptr := new(U, staticresourcemanager_arena_allocator(resource_manager))

	staticresourcemanager_set_ptr(resource_manager, resource_id, resource_ptr)

	return resource_id, resource_ptr
}

// Allocates a new resource initializing it with the provided data. The 
// generated id and provided data pointer will be valid for the entire manager 
// lifetime
// @returns: I = the resource id
//           U = the resource data ptr
// @thread_safety: Thread-safe
staticresourcemanager_generate_new_with_data :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
	resource: U,
) -> (
	I,
	^U,
) {
	resource_id := idgenerator_generate(&resource_manager.id_generator)
	resource_ptr := new(U, staticresourcemanager_arena_allocator(resource_manager))

	resource_ptr^ = resource

	staticresourcemanager_set_ptr(resource_manager, resource_id, resource_ptr)

	return resource_id, resource_ptr
}

// Checks if an id is currently valid
// @note: An id is considered invalid if it is not associated with a resource
//        or if its associated resource has been removed
// @thread_safety: Thread-safe
staticresourcemanager_is_id_valid :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
	id: I,
) -> bool {
	if !idgenerator_is_id_valid(&resource_manager.id_generator, id) {
		return false
	}

	if sync.guard(&resource_manager.resources_mutex) {
		return resource_manager.resources[(uint)(id)] != nil
	}

	unreachable()
}

// Gets the data pointer associated to a determined id
// @retuns: nil if the provided id is not valid
// @thread_safety: Thread-safe
staticresourcemanager_get :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
	id: I,
) -> ^U {
	if !idgenerator_is_id_valid(&resource_manager.id_generator, id) {
		return nil
	}

	if sync.guard(&resource_manager.resources_mutex) {
		return resource_manager.resources[(uint)(id)]
	}

	unreachable()
}

// Removes a resource from the manager. Its id will thus be considered invalid
// @note: This procedure does not free the allocated data. It will be freed
//        on manager destruction
// @thread_safety: Thread-safe
staticresourcemanager_remove :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
	id: I,
) -> bool {
	return staticresourcemanager_set_invalid(resource_manager, id)
}

staticresourcemanager_generate_new :: proc {
	staticresourcemanager_generate_new_empty,
	staticresourcemanager_generate_new_with_data,
}

// @thread_safety: Not thread-safe
@(private = "file")
staticresourcemanager_ensure_size :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
	desired_size: uint,
) -> (
	did_resize: bool,
) {
	if len(resource_manager.resources) >= (int)(desired_size) {
		return false
	}

	resize(&resource_manager.resources, (int)(desired_size))
	return true
}

// @thread_safety: Thread-safe
@(private = "file")
staticresourcemanager_set_ptr :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
	id: I,
	resource_ptr: ^U,
) {
	sync.guard(&resource_manager.resources_mutex)

	staticresourcemanager_ensure_size(resource_manager, (uint)(id + 1))

	resource_manager.resources[(uint)(id)] = resource_ptr
}

// @thread_safety: Thread-safe
@(private = "file")
staticresourcemanager_set_invalid :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
	id: I,
) -> (
	is_id_valid: bool,
) {
	if !idgenerator_is_id_valid(&resource_manager.id_generator, id) {
		return false
	}

	if sync.guard(&resource_manager.resources_mutex) {
		resource_manager.resources[(uint)(id)] = nil
	}

	return true
}

// @thread_safety: Thread-safe
@(private = "file")
staticresourcemanager_arena_allocator :: proc(
	resource_manager: $T/^Static_Resource_Manager($U, $I),
) -> mem.Allocator {
	return virtual.arena_allocator(&resource_manager.arena)
}

_ :: mem
_ :: virtual
_ :: sync

