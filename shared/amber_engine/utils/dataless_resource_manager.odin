package amber_engine_common

import "core:sync"

// Dataless_Resource_Manager is a manager for resources of which data is handled
// by the user
// @params: I = The resource type id
// @thread_safety: Thread-safe
Dataless_Resource_Manager :: struct($I: typeid) {
	id_generator:      Id_Generator(I),
	removed_ids:       map[I]struct {},
	removed_ids_mutex: sync.RW_Mutex,
}

// Initializes a Dataless_Resource_Manager
datalessresourcemanager_init :: proc(
	resource_manager: $T/^Dataless_Resource_Manager($I),
	allocator := context.allocator,
) {
	resource_manager.removed_ids = make(map[I]struct {})
}

// Frees a Dataless_Resource_Manager
// @thread_safety: Not thread-safe
datalessresourcemanager_free :: proc(resource_manager: $T/Dataless_Resource_Manager($I)) {
	delete(resource_manager.removed_ids)
}

// Generates a new id. It will be valid for the entire manager lifetime
// @thread_safety: Thread-safe
datalessresourcemanager_generate_new :: proc(
	resource_manager: $T/^Dataless_Resource_Manager($I),
) -> I {
	return idgenerator_generate(&resource_manager.id_generator)
}

// Checks if an id is currently valid
// @note: An id is considered invalid if it is not associated with a resource
//        or if its associated resource has been removed
// @thread_safety: Thread-safe
datalessresourcemanager_is_id_valid :: proc(
	resource_manager: $T/^Dataless_Resource_Manager($I),
	id: I,
) -> bool {
	if !idgenerator_is_id_valid(&resource_manager.id_generator, id) {
		return false
	}

	if sync.shared_guard(&resource_manager.removed_ids_mutex) {
		return id not_in resource_manager.removed_ids
	}

	unreachable()
}

// Removes a resource from the manager. Its id will thus be considered invalid
// @thread_safety: Thread-safe
datalessresourcemanager_remove :: proc(
	resource_manager: $T/^Dataless_Resource_Manager($I),
	id: I,
) -> bool {
	if !idgenerator_is_id_valid(&resource_manager.id_generator, id) {
		return false
	}

	if sync.guard(&resource_manager.removed_ids_mutex) {
		resource_manager.removed_ids[id] = struct {}{}
	}

	return true
}

_ :: sync

