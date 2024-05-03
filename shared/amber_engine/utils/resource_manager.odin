package amber_engine_utils

// import "base:intrinsics"
// import "base:runtime"
// import "core:mem"
// import "core:sync"

// // A Resource_Manager is a general purpose manager for resources that have a low
// // lifespan, and are frequently allocated and freed. If resources are rarely, if
// // ever freed consider using Static_Resource_Manager
// // @parameters: T = The resource type
// //              I = The resource id type (must be unsigned)
// // @note: This implementation uses generational ids to ensure performace, so the
// //        generated id will not be linear. This system is inspired by the memory
// //        management in the Vale language.
// //        Here follows an id example:
// //            Example id type (I): uint
// //                uint ->  | gen | internal id  |
// //                         16 bits    48 bits 
// //        In every id type the first size_of(I)/4 bits are used for the 
// //        generation. And the remaining bits will be used as the index on the
// //        resources field.
// //        Every time a resource is generated it will be associated with a 
// //        generation and a location of the resources field. When that resource
// //        will be removed its associated location will "age" and change its
// //        generation, so the location can be reused for another resource (which
// //        will use a different generation). If someone tries to gen the removed
// //        resource it is possible to tell that the location does not contain the
// //        required data, even if something else is occupying the resource.
// //        Once a location reaches its max generation (it is no longer 
// //        representable in the Id) it is considered unusable. If the first 
// //        location becames unusable, the resources array field will shift its
// //        elements until the first becames usable or is currently in use
// //        This allows to skip an hash map lookup.
// //        Inspiration: https://verdagon.dev/blog/generational-references
// // @thread_safety: Thread-safe
// // TODO(Vicix): Fix the code structure... It is a bit of a mess
// //odinfmt: disable
// Resource_Manager :: struct(
// 	$T: typeid, 
// 	$I: typeid,
// ) where intrinsics.type_is_ordered_numeric(I) && intrinsics.type_is_unsigned(I) && size_of(I) == 8 {
// 	allocator:           runtime.Allocator,
// 	starting_number:     uint,
// 	first_free_location: uint,
// 	resources:           #soa[dynamic]Resource_Manager_Cell(T),
// 	resources_mutex:     sync.Mutex,
// }

// // Initializes a Resource_Manager
// //odinfmt: enable
// resourcemanager_init :: proc(
// 	resource_manager: $T/^Resource_Manager($U, $I),
// 	allocator := context.allocator,
// ) {
// 	context.allocator = allocator
// 	resource_manager.allocator = allocator
// }

// // Frees a Resource_Manager and all its associated resources
// // @thread_safe: Not thread-safe
// resourcemanager_free :: proc(resource_manager: $T/Resource_Manager($U, $I)) {
// }

// // @(private)
// // Resource_Manager_Cell_Validity_Data :: bit_field u32 {
// // 	generation: u32 | 31,
// // 	complete: bool | 1,
// // }

// @(private)
// Resource_Manager_Cell :: struct($T: typeid) {
// 	resource_pointer:    ^Arc(T),
// 	using validity_data: Resource_Manager_Cell_Validity_Data,
// }

// @(private)
// resourcemanagercell_init :: proc(
// 	cell: ^Resource_Manager_Cell($T),
// 	allocator: runtime.Allocator,
// ) {
// 	cell.resource_pointer = arc_new(allocator)
// 	cell.complete = false
// }

// @(private)
// resourcemanagercell_clear_and_init :: proc(
// 	cell: ^Resource_Manager_Cell($T), 
// 	allocator: runtime.Allocator,
// ) -> (did_overflow: bool) {
// 	if resourcemanagercell_clear(cell) {
// 		return true
// 	}

// 	resourcemanagercell_init(cell, allocator)
// 	return false
// }

// @(private)
// resourcemanagercell_clear :: proc(cell: ^Resource_Manager_Cell($T)) -> (did_overflow: bool) {
// 	if cell.resource_pointer == nil {
// 		rc_drop(cell.resource_pointer)
// 		cell.resource_pointer = nil
// 	}

// 	cell.generation += 1
// 	cell.complete = false

// 	return cell.generation == 0
// }

// @(private)
// resourcemanagercell_get_pointer :: proc(
// 	cell: ^Resource_Manager_Cell($T), 
// 	generation: u32,
// ) -> (pointer: ^Arc(T), is_generation_valid: bool) #optional_ok {
// 	is_generation_valid = resourcemanagercell_is_generation_valid(cell^, generation)

// 	if cell.resource_pointer == nil {
// 		return nil, is_generation_valid
// 	}
// 	return rc_clone(cell.resource_pointer), is_generation_valid
// }

// @(private)
// resourcemanagercell_complete :: proc(cell: ^Resource_Manager_Cell($T)) {
// 	cell.complete = true
// }

// @(private)
// resourcemanagercell_is_complete :: proc(cell: Resource_Manager_Cell($T)) -> bool {
// 	return cell.complete
// }

// @(private)
// resourcemanagercell_get_generation :: proc(cell: Resource_Manager_Cell($T)) -> u32 {
// 	return cell.generation
// }

// @(private)
// resourcemanagercell_is_generation_valid :: proc(
// 	cell: Resource_Manager_Cell($T),
// 	generation: u32,
// ) -> bool {
// 	return cell.generation == generation
// }

// // @(private)
// // Resource_Manager_Id :: bit_field u64 {
// // 	location: u32 | 32,
// // 	generation: u32 | 32,
// // }

// @(private = "file")
// I_as_id :: proc(
// 	resourcemanager_user_id: $I,
// ) where intrinsics.is_type_ordered_numeric(I) &&
// 	size_of(I) == 8->Resource_Manager_Id {
// 	return transmute(Resource_Manager_Id)(resourcemanager_user_id)
// }

// @(private)
// resourcemanager_id_as_index :: proc(resource_manager: Resource_Manager($I, $T), id: I) -> int {
// 	return I_as_id(id) - resource_manager.starting_number
// }

// _ :: mem
// _ :: sync

