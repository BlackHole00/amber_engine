//TODO(Vicix): Implement a more consistent naming for the private functions
package amber_engine_storage

import ba "core:container/bit_array"
import "core:log"
import "core:math"
import "core:mem"
import "core:sync"
import ae "shared:amber_engine/common"

@(private)
BYTES_PER_LOCATION :: size_of(u32) // 4

// Should be used as bool
@(private)
Location_Status :: enum u32 {
	Free     = 0,
	Occupied = 1,
}

Resource_Type_Id :: ae.Resource_Type_Id
Resource_Id :: ae.Resource_Id

Resource_Type_Info :: struct {
	using info:   ae.Resource_Type_Info,
	// size in 4 bytes location. For example:
	//     - 32 bits = 4 bytes => 1 location
	//     - 48 bits = 6 bytes => 2 locations
	aligned_size: uint,
}

Resource_Info :: struct {
	using info: ae.Resource_Info,
	// @index_of: Storage.resource_buffer
	location:   uint,
	size:       uint,
}

Storage :: struct {
	resource_identifier_incremental_count: uint,
	allocator:                             mem.Allocator,
	// @index_by: Resource_Type_Id
	resource_types:                        [dynamic]Resource_Type_Info,
	resource_types_mutex:                  sync.Mutex,
	resource_infos:                        map[Resource_Id]Resource_Info,
	resource_infos_mutex:                  sync.Mutex,
	resource_buffer:                       [dynamic]u32,
	resource_buffer_mutex:                 sync.Mutex,
	// Contains if a 32bit/4bytes segment of memory in the resource_buffer is
	// used or not
	free_resource_locations:               ^ba.Bit_Array,
	first_free_location:                   uint,
	// Locks also free_resource_count
	free_resource_locations_mutex:         sync.Mutex,
}

storage_init :: proc(storage: ^Storage, allocator := context.allocator) {
	context.allocator = allocator
	storage.allocator = allocator

	storage.resource_types = make([dynamic]Resource_Type_Info)
	storage.resource_infos = make(map[Resource_Id]Resource_Info)
	storage.resource_buffer = make([dynamic]u32)
	storage.free_resource_locations = ba.create(256)
}

storage_free :: proc(storage: Storage) {
	context.allocator = storage.allocator

	delete(storage.resource_types)
	delete(storage.resource_infos)
	delete(storage.resource_buffer)
	ba.destroy(storage.free_resource_locations)
}

storage_register_resource_type :: proc(
	storage: ^Storage,
	type_name: string,
	type_size: uint,
	location := #caller_location,
) -> (
	resource_type_id: Resource_Type_Id,
) {
	context.allocator = storage.allocator

	type_info := Resource_Type_Info {
		name         = type_name,
		size         = type_size,
		aligned_size = size_to_aligned_size(type_size),
	}

	if sync.guard(&storage.resource_types_mutex) {
		if !storage_is_typename_unique(storage^, type_name) {
			log.errorf(
				"Could not register type with name %s: Duplicated name",
				type_name,
				location = location,
			)
			return ae.INVALID_RESOURCE_TYPE_ID
		}

		resource_type_id = storage_get_current_resource_type_id(storage^)
		append(&storage.resource_types, type_info)
	}

	return
}

storage_add_resource :: proc(
	storage: ^Storage,
	resource_type: Resource_Type_Id,
	data: []byte,
	location := #caller_location,
) -> (
	resource_id: Resource_Id,
) {
	context.allocator = storage.allocator

	aligned_size: uint = ---
	if sync.guard(&storage.resource_types_mutex) {
		if !storage_is_resource_type_valid_unsync(storage^, resource_type) {
			log.errorf(
				"Could not add a resource to the storage: Could not find resource type %d",
				resource_type,
				location = location,
			)
			return ae.INVALID_REOSURCE_ID
		}

		aligned_size = storage_get_resource_type_info_unsafe(storage^, resource_type).aligned_size
	}

	resource_info := Resource_Info {
		identifier = storage_generate_resource_id(storage),
		type       = resource_type,
		size       = aligned_size,
	}
	storage_needs_resizing := false

	if sync.guard(&storage.free_resource_locations_mutex) {
		idx, outside_of_buffer := storage_find_first_n_contiguous_locations_free(
			storage^,
			aligned_size,
		)

		resource_info.location = idx
		storage_needs_resizing = outside_of_buffer

		storage_set_locations_statuses(storage^, idx, idx + aligned_size - 1, .Occupied)

		if idx == storage.first_free_location {
			free_location, _ := storage_find_first_free_location(storage^, idx + aligned_size)
			storage.first_free_location = free_location
		}
	}

	if sync.guard(&storage.resource_buffer_mutex) {
		if storage_needs_resizing {
			storage_resize_resource_buffer(storage, resource_info.location + aligned_size)
		}

		storage_copy_buffer_data_to_location(storage^, resource_info.location, aligned_size, data)
	}

	if sync.guard(&storage.resource_infos_mutex) {
		storage_register_resource_info(storage, resource_info)
	}

	return resource_info.identifier
}

storage_get_resource :: proc(
	storage: ^Storage,
	resource_id: Resource_Id,
	destination: []byte,
	location := #caller_location,
) -> bool {
	context.allocator = storage.allocator

	data_location: uint = ---
	data_size: uint = ---
	if sync.guard(&storage.resource_infos_mutex) {
		type_info, ok := storage_get_resource_info_unsync(storage^, resource_id)
		if !ok {
			log.warnf("Could not find requested resource %d", resource_id, location = location)
			return false
		}

		data_location = type_info.location
		data_size = type_info.size
	}

	if sync.guard(&storage.resource_buffer_mutex) {
		storage_copy_location_data_to_buffer(storage^, data_location, data_size, destination)
	}

	return true
}

storage_remove_resource :: proc(
	storage: ^Storage,
	resource_id: Resource_Id,
	location := #caller_location,
) -> bool {
	context.allocator = storage.allocator

	resource_info: Resource_Info = ---
	if sync.guard(&storage.resource_infos_mutex) {
		if !storage_is_resource_valid_unsync(storage^, resource_id) {
			log.warnf(
				"Could not remove resource %d: Could not find the requested resource",
				resource_id,
				location = location,
			)
			return false
		}

		resource_info = storage_remove_resource_info(storage, resource_id)
	}

	if sync.guard(&storage.free_resource_locations_mutex) {
		storage_set_locations_statuses(
			storage^,
			resource_info.location,
			resource_info.location + resource_info.size - 1,
			.Free,
		)

		if resource_info.location < storage.first_free_location {
			storage.first_free_location = resource_info.location
		}
	}

	return true
}

storage_set_resource :: proc(
	storage: ^Storage,
	resource_id: Resource_Id,
	data: []byte,
	location := #caller_location,
) -> bool {
	context.allocator = storage.allocator

	resource_info: Resource_Info = ---
	if sync.guard(&storage.resource_infos_mutex) {
		info, ok := storage_get_resource_info_unsync(storage^, resource_id)
		if !ok {
			log.warnf(
				"Could not set resource %d: Could not find the requested resource",
				resource_id,
				location = location,
			)
			return false
		}

		resource_info = info
	}

	if sync.guard(&storage.resource_buffer_mutex) {
		storage_copy_buffer_data_to_location(
			storage^,
			resource_info.location,
			resource_info.location,
			data,
		)
	}

	return true
}

storage_is_resource_type_valid :: proc(
	storage: ^Storage,
	resource_type_id: Resource_Type_Id,
) -> bool {
	if sync.guard(&storage.resource_types_mutex) {
		return storage_is_resource_type_valid_unsync(storage^, resource_type_id)
	}

	unreachable()
}

storage_is_resource_valid :: proc(storage: ^Storage, resource_id: Resource_Id) -> bool {
	if sync.guard(&storage.resource_infos_mutex) {
		return storage_is_resource_valid_unsync(storage^, resource_id)
	}

	unreachable()
}

storage_get_resource_type_info :: proc(
	storage: ^Storage,
	resource_type_id: Resource_Type_Id,
) -> (
	Resource_Type_Info,
	bool,
) {
	if sync.guard(&storage.resource_types_mutex) {
		return storage_get_resource_type_info_unsync(storage^, resource_type_id)
	}

	unreachable()
}

storage_get_resource_info :: proc(
	storage: ^Storage,
	resource_id: Resource_Id,
) -> (
	Resource_Info,
	bool,
) {
	if sync.guard(&storage.resource_infos_mutex) {
		return storage_get_resource_info_unsync(storage^, resource_id)
	}

	unreachable()
}

storage_get_registered_types_info_list :: proc(
	storage: ^Storage,
	allocator: mem.Allocator,
) -> []ae.Resource_Type_Info {
	if sync.guard(&storage.resource_types_mutex) {
		list := make([dynamic]ae.Resource_Type_Info)

		for type in storage.resource_types {
			append(&list, type.info)
		}

		return list[:]
	}

	unreachable()
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_infos_mutex
@(private)
storage_register_resource_info :: proc(storage: ^Storage, resource_info: Resource_Info) {
	storage.resource_infos[resource_info.identifier] = resource_info
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_infos_mutex
@(private)
storage_is_resource_valid_unsync :: proc(storage: Storage, resource_id: Resource_Id) -> bool {
	return resource_id in storage.resource_infos
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_infos_mutex
@(private)
storage_get_resource_info_unsync :: proc(
	storage: Storage,
	resource_id: Resource_Id,
) -> (
	Resource_Info,
	bool,
) {
	return storage.resource_infos[resource_id]
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_infos_mutex
@(private)
storage_remove_resource_info :: proc(
	storage: ^Storage,
	resource_id: Resource_Id,
) -> Resource_Info {
	_, value := delete_key(&storage.resource_infos, resource_id)
	return value
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_types_mutex
@(private)
storage_is_resource_type_valid_unsync :: proc(
	storage: Storage,
	resource_type_id: Resource_Type_Id,
) -> bool {
	return (uint)(len(storage.resource_types)) >= (uint)(resource_type_id)
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_types_mutex
@(private)
storage_get_resource_type_info_unsync :: proc(
	storage: Storage,
	resource_type_id: Resource_Type_Id,
) -> (
	Resource_Type_Info,
	bool,
) {
	if !storage_is_resource_type_valid_unsync(storage, resource_type_id) {
		return {}, false
	}

	return storage.resource_types[resource_type_id], true
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_types_mutex
@(private)
storage_get_resource_type_info_unsafe :: proc(
	storage: Storage,
	resource_type_id: Resource_Type_Id,
) -> Resource_Type_Info {
	return storage.resource_types[resource_type_id]
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_types_mutex
@(private)
storage_get_current_resource_type_id :: proc(storage: Storage) -> Resource_Type_Id {
	return (Resource_Type_Id)(len(storage.resource_types))
}

// @thread_safety: Not thread safe. Requires lock for Storage.resource_types_mutex
@(private)
storage_is_typename_unique :: proc(storage: Storage, type_name: string) -> bool {
	for type in storage.resource_types {
		if type.name == type_name {
			return false
		}
	}

	return true
}

// @thread_safety: Not thread safe. Requires lock on Storage.free_resource_locations_mutex
@(private)
storage_set_locations_statuses :: proc(
	storage: Storage,
	begin: uint,
	end: uint,
	status: Location_Status,
) {
	for i in begin ..= end {
		ba.set(storage.free_resource_locations, i, (bool)(status))
	}
}

// @thread_safety: Not thread safe. Requires lock on Storage.free_resource_locations_mutex
@(private)
storage_get_location_status :: proc(storage: Storage, location: uint) -> Location_Status {
	res, _ := ba.get(storage.free_resource_locations, location)
	return (Location_Status)(res)
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_buffer_mutex
@(private)
storage_copy_buffer_data_to_location :: proc(
	storage: Storage,
	location: uint,
	data_location_size: uint,
	buffer: []byte,
) {
	mem.copy_non_overlapping(
		&storage.resource_buffer[location],
		&buffer[0],
		min(len(buffer), (int)(data_location_size * BYTES_PER_LOCATION)),
	)
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_buffer_mutex
@(private)
storage_copy_location_data_to_buffer :: proc(
	storage: Storage,
	location: uint,
	data_location_size: uint,
	buffer: []byte,
) {
	mem.copy_non_overlapping(
		&buffer[0],
		&storage.resource_buffer[location],
		min(len(buffer), (int)(data_location_size * BYTES_PER_LOCATION)),
	)
}

// @thread_safety: Not thread safe. Requires lock on Storage.resource_buffer_mutex
@(private)
storage_resize_resource_buffer :: proc(storage: ^Storage, desired_size: uint) {
	desired_size := (int)(desired_size)

	if len(storage.resource_buffer) < desired_size {
		resize(&storage.resource_buffer, desired_size)
	}
}

// @thread_safety: Not thread safe. Requires lock on Storage.free_resource_locations_mutex
@(private)
storage_find_first_n_contiguous_locations_free :: proc(
	storage: Storage,
	n: uint,
) -> (
	idx: uint,
	outside_of_buffer: bool,
) {
	if len(storage.resource_buffer) < (int)(n) {
		return (uint)(len(storage.resource_buffer)), true
	}
	if storage.first_free_location > len(storage.resource_buffer) - n {
		return (uint)(len(storage.resource_buffer)), true
	}

	current_location := storage.first_free_location
	outer: for {
		for i in 0 ..< n {
			if storage_get_location_status(storage, current_location + i) == .Occupied {
				current_location = current_location + i + 1
				continue outer
			}
		}

		return current_location, false
	}

	return (uint)(len(storage.resource_buffer)), true
}

// @thread_safety: Not thread safe. Requires lock on Storage.free_resource_locations_mutex
//NOTE(Vicix): Gross hack, but it is faster. We find the first bit set that is 
//             not entirely filled and then we search bit by bit in the set that 
//             has al least 1 bit free
@(private)
storage_find_first_free_location :: proc(
	storage: Storage,
	search_start: uint = 0,
) -> (
	uint,
	bool,
) {
	BITS_IN_U64 :: 64

	i := 0
	current_bit_set: u64 = ---
	for i < len(storage.free_resource_locations.bits) {
		current_bit_set = storage.free_resource_locations.bits[i]
		if current_bit_set != 0xFFFFFFFF {
			break
		}

		i += 1
	}

	if i == len(storage.free_resource_locations.bits) {
		return (uint)(i * BITS_IN_U64), false
	}

	real_location := (uint)(i * BITS_IN_U64)
	for {
		if (current_bit_set & 1) == 0 {
			return real_location, true
		}

		current_bit_set >>= 1
		real_location += 1
	}

	return real_location, false
}

@(private)
storage_generate_resource_id :: proc(storage: ^Storage) -> Resource_Id {
	return (Resource_Id)(sync.atomic_add(&storage.resource_identifier_incremental_count, 1))
}

@(private)
align_size_to :: proc(size: uint, $align: uint) -> (aligned_size: uint) {
	bit_shift := transmute(uint)(math.ilogb((f32)(align)))

	if (size & 0b0011) == 0 {
		return (size >> bit_shift) << bit_shift
	}
	return ((size >> bit_shift) << bit_shift) + 0b100
}

@(private)
size_to_aligned_size :: proc(size: uint) -> uint {
	return align_size_to(size, BYTES_PER_LOCATION) >> 2
}

