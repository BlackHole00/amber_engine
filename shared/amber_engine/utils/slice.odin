package amber_engine_utils

slice_remove_index :: proc(slice: []$T, index: int, allocator := context.allocator) -> []T {
	assert(index < len(slice))

	if len(slice) - 1 == 0 {
		return nil
	}

	new_slice := make([]T, len(slice) - 1, allocator)

	mem.copy(&new_slice[0], slice[0], index * size_of(T))
	mem.copy(&new_slice[index], slice[index + 1], (len(slice) - index - 1) * size_of(T))

	return new_slice
}

slice_remove_value :: proc(slice: []$T, value: T, allocator := context.allocator) -> []T {
	new_slice := make([dynamic]T, allocator)

	for item in slice {
		if item != value {
			append(&new_slice, item)
		}
	}

	if len(new_slice) == 0 {
		delete(new_slice)
		return nil
	}

	return new_slice[:]
}

