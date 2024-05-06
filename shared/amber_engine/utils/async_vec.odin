package amber_engine_utils

import "base:intrinsics"
import "base:runtime"

// This should allow for 2^(3+16-1) = 2^18 = 262144 locations
ASYNCVEC_BUCKETS_DEFAULT_MAX_COUNT :: 16

// @thread_safety: Thread safe. The allocator is expected to be thread safe.
// @warning: DOES NOT CURRENTLY WORK
Async_Vec :: struct($T: typeid) {
	// @atomic
	descriptor: ^Async_Vec_Desciptor(T),
	// @final
	// @values: @atomic
	// @note: needs to be a multi-pointer because it needs to be atomic
	buckets: [][^]T,
	allocator: runtime.Allocator,
	temp_allocator: runtime.Allocator,
}

asyncvec_init_empty :: proc(
	vec: ^Async_Vec($T), 
	max_buckets_count := ASYNCVEC_BUCKETS_DEFAULT_MAX_COUNT, 
	allocator := context.allocator,
	temp_allocator := context.temp_allocator,
) {
	context.allocator = allocator
	vec.allocator = allocator
	vec.temp_allocator = temp_allocator

	vec.buckets = make([][^]T, max_buckets_count)
	asyncvec_set_bucket(vec, make([^]T, ASYNCVEC_FIRST_BUCKET_SIZE), 0)

	vec.descriptor = new(Async_Vec_Desciptor(T), temp_allocator)
}

asyncvec_init_with_size :: proc(
	vec: ^Async_Vec($T), 
	size: int, 
	max_bucket_count := ASYNCVEC_BUCKETS_DEFAULT_MAX_COUNT, 
	allocator := context.allocator,
) {
	unimplemented()
}

asyncvec_delete :: proc(vec: ^Async_Vec($T)) {
	for bucket in vec.buckets {
		asyncvecbucket_delete(bucket, vec.allocator)
	}
	delete(vec.buckets, vec.allocator)
}

asyncvec_get :: proc(vec: Async_Vec($T), index: int) -> ^T {
	bucket_index, element_index := item_index_to_bucket_index(index)
	return &vec.buckets[bucket_index][element_index]
}

asyncvec_set :: proc(vec: Async_Vec($T), index: int, value: T) {
	asyncvec_get(vec, index)^ = value
}

asyncvec_len :: proc(vec: ^Async_Vec($T)) -> int {
	descriptor := intrinsics.atomic_load(&vec.descriptor)^

	descriptor.size = vec.descriptor.size
	if descriptor.write_operation.pending {
		descriptor.size -= 1
	}

	return descriptor.size
}

asyncvec_append :: proc(vec: ^Async_Vec($T), element: T) {
	next_descriptor: ^Async_Vec_Desciptor(T)

	for {
		descriptor := intrinsics.atomic_load(&vec.descriptor)
		asyncvec_complete_write_operation(vec, &descriptor.write_operation)

		bucket := highest_bit(descriptor.size + ASYNCVEC_FIRST_BUCKET_SIZE) - ASYNCVEC_FIRST_BUCKET_SIZE_LOG2
		if !asyncvec_is_bucket_usable(vec^, (int)(bucket)) {
			asyncvec_alloc_bucket(vec, (int)(bucket))
		}

		next_descriptor = new(Async_Vec_Desciptor(T), vec.temp_allocator)
		next_descriptor.size = descriptor.size + 1
		asyncvecwritedescriptor_init(
			&next_descriptor.write_operation,
			asyncvec_get(vec^, descriptor.size)^,
			element,
			descriptor.size,
		)

		if _, ok := intrinsics.atomic_compare_exchange_strong(
			&vec.descriptor,
			descriptor,
			next_descriptor,
		); !ok {
			continue
		} else {
			break
		}
	}

	asyncvec_complete_write_operation(vec, &next_descriptor.write_operation)
}

asyncvec_pop :: proc(vec: ^Async_Vec($T)) -> (popped_elem: T) {
	for {
		descriptor := intrinsics.atomic_load(&vec.descriptor)
		asyncvec_complete_write_operation(vec, &descriptor.write_operation)

		popped_elem = asyncvec_get(vec^, descriptor.size - 1)^

		next_descriptor := new(Async_Vec_Desciptor(T), vec.temp_allocator)
		next_descriptor.size = descriptor.size - 1

		if _, ok := intrinsics.atomic_compare_exchange_strong(
			&vec.descriptor,
			descriptor,
			next_descriptor,
		); !ok {
			continue
		} else {
			break
		}
	}

	return
}

asyncvec_reserve :: proc(vec: ^Async_Vec($T), size: int) {
	i := highest_bit(vec.descriptor.size + ASYNCVEC_FIRST_BUCKET_SIZE - 1)
	if i >= ASYNCVEC_FIRST_BUCKET_SIZE_LOG2 {
		i -= ASYNCVEC_FIRST_BUCKET_SIZE_LOG2
	} else {
		i = 0
	}

	for i < (highest_bit(size + ASYNCVEC_FIRST_BUCKET_SIZE - 1) - ASYNCVEC_FIRST_BUCKET_SIZE_LOG2) {
		i += 1
		asyncvec_alloc_bucket(vec, (int)(i))
	}
}

@(private="file")
asyncvec_complete_write_operation :: proc(
	vec: ^Async_Vec($T), 
	write_operation: ^Async_Vec_Write_Descriptor(T),
) {
	if !write_operation.pending {
		return
	}

	intrinsics.atomic_compare_exchange_strong(
		asyncvec_get(vec^, write_operation.index),
		write_operation.old_value,
		write_operation.new_value,
	)
	write_operation.pending = false
}

@(private="file")
asyncvec_alloc_bucket :: proc(vec: ^Async_Vec($T), index: int) {
	bucket := asyncvecbucket_make(T, (uint)(index), vec.allocator)
	if !asyncvec_set_bucket(vec, bucket, index) {
		asyncvecbucket_delete(bucket, vec.allocator)
	}
}

@(private="file")
asyncvec_set_bucket :: proc(vec: ^Async_Vec($T), bucket: [^]T, index: int) -> (did_exchange: bool) {
	_, did_exchange = intrinsics.atomic_compare_exchange_strong(&vec.buckets[index], nil, bucket)

	return
}

@(private="file")
asyncvec_is_bucket_usable :: proc(vec: Async_Vec($T), index: int) -> bool {
	return vec.buckets[index] != nil
}

@(private="file")
asyncvecbucket_make :: proc($T: typeid, designed_index: uint, allocator: runtime.Allocator) -> [^]T {
	bucket_len := 1 << (ASYNCVEC_FIRST_BUCKET_SIZE_LOG2 + designed_index) 
	return make([^]T, bucket_len, allocator)
}

@(private="file")
asyncvecbucket_delete :: proc(bucket: [^]$T, allocator: runtime.Allocator) {
	free(bucket, allocator)
}

@(private="file")
ASYNCVEC_FIRST_BUCKET_SIZE :: 8
@(private="file")
ASYNCVEC_FIRST_BUCKET_SIZE_LOG2 :: 3

@(private="file")
Async_Vec_Desciptor :: struct($T:typeid) {
	size: int,
	write_operation: Async_Vec_Write_Descriptor(T),
}

@(private="file")
Async_Vec_Write_Descriptor :: struct($T: typeid) {
	new_value: T,
	old_value: T,
	index: int,
	pending: bool,
}

@(private="file")
asyncvecwritedescriptor_init :: proc(descriptor: ^Async_Vec_Write_Descriptor($T), new_value: T, old_value: T, index: int) {
	descriptor^ = Async_Vec_Write_Descriptor(T) {
		new_value = new_value,
		old_value = old_value,
		index = index,
		pending = true,
	}
}

@(private="file")
highest_bit :: proc(x: $T) -> uint where intrinsics.type_is_numeric(T) {
	return (uint)((size_of(T) * 8) - intrinsics.count_leading_zeros(x)) - 1
}

@(private="file")
item_index_to_bucket_index :: proc(#any_int index: uint) -> (
	bucket_index: uint, 
	element_index_in_bucket: uint,
) {
	position := index + ASYNCVEC_FIRST_BUCKET_SIZE
	high_bit := highest_bit(position)

	bucket_index = high_bit - (ASYNCVEC_FIRST_BUCKET_SIZE_LOG2)
	element_index_in_bucket = position ~ (1 << high_bit)
	return
}

