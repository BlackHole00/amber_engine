package amber_engine_common

import "core:mem"

SMALLDYNARRAY_DEFAULT_LEN :: 8

Small_Dyn_Array :: struct($T: typeid) {
	data: []T,
}

smalldynarray_init :: proc(
	array: $T/^Small_Dyn_Array($U),
	size := SMALLDYNARRAY_DEFAULT_LEN,
	allocator := context.allocator,
) {
	array.data = make([]U, size, allocator)
}

smalldynarray_free :: proc(array: $T/Small_Dyn_Array($U), allocator := context.allocator) {
	delete(array.data, allocator)
}

smalldynarray_len :: proc(array: $T/Small_Dyn_Array($U)) -> int {
	return len(array.data)
}

smalldynarray_append :: proc(
	array: $T/^Small_Dyn_Array($U),
	elem: U,
	allocator := context.allocator,
) {
	new_data := make([]U, smalldynarray_len(array^) + 1, allocator)
	mem.copy(&new_data[0], &array.data[0], smalldynarray_len(array^) * size_of(U))

	delete(array.data, allocator)
	array.data = new_data
}

smalldynarray_remove_index :: proc(
	array: $T/^Small_Dyn_Array($U),
	index: int,
	allocator := context.allocator,
) {
	new_data := slice_remove_index(array.data, index, allocator)

	delete(array.data, allocator)
	array.data = new_data
}

smalldynarray_as_slice :: proc(array: $T/Small_Dyn_Array($U)) -> []U {
	return array.data
}

_ :: mem

