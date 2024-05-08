package amber_engine_utils

import "base:intrinsics"
import "base:runtime"

// This should allow for 2^(3+16-1) = 2^18 = 262144 locations
ASYNCVEC_BUCKETS_DEFAULT_MAX_COUNT :: 16

// The Async_Vec is a thread safe lockless data structure that can be used as a
// dynamic vector (`[dynamic]T`) replacement (with a few caveats). If the vector
// is not shared between threads consider using `[dynamic]T` instead.
// @parameters: T = The type stored by the vector
// @note: Once a location is allocated it will be the same for the lifetime of 
//        the object, since the vector does not do reallocations. It is thus 
//        safe to share pointers to the vector locations.
//        The vector has a fixed maximum size. This can be changed in the 
//        constructor. By default the vector allows for 262144 locations.
//        The vector can be resized, but its capacity can only grow, this is 
//        done to garantee thread safety. It is suggested to be very carefull
//        when reserving storage.
// @performace: While in multithreaded scenarios this vector is way faster than
//              the default dynamic one, keep in mind that getting and setting
//              a location requires a decode (still O(1), but slower than a real
//              vector one), so in singlethreaded scenarios prefer `[dynamic]T`.
// @thread_safety: Thread safe. The allocator is expected to be thread safe.
Async_Vec :: struct($T: typeid) {
	// @atomic: only on write
	size: int,
	// Contains the data of the vector. Every bucket is sized as 2 * the size of
	// the previous, while the first is sized ASYNCVEC_FIRST_BUCKET_SIZE.
	// This method removes the reallocations of the data (which happen in
	// `[dynamic]T`).
	// @final
	// @values: @atomic
	// @note: needs to be a multi-pointer because it needs to be atomic.
	buckets: [][^]T,
	// @final
	allocator: runtime.Allocator,
}

// Initializes an empty Async_Vec.
// @params: vec = the destination vector
//          max_buckets_cout = specifies the amount of buckets the vector
//                             can use. Defineds how many locations the
//                             vector can access.
//          allocator = the vector allocator
asyncvec_init_empty :: proc(
	vec: ^Async_Vec($T), 
	max_buckets_count := ASYNCVEC_BUCKETS_DEFAULT_MAX_COUNT, 
	allocator := context.allocator,
) {
	context.allocator = allocator
	vec.allocator = allocator

	vec.buckets = make([][^]T, max_buckets_count)
	asyncvec_set_bucket(vec, make([^]T, ASYNCVEC_FIRST_BUCKET_SIZE), 0)
}

// Initializes an Async_Vec with a specified capacity
// @params: vec = the destination vector
//          cap = the reserved vector capacity
//          max_buckets_cout = specifies the amount of buckets the vector
//                             can use. Defineds how many locations the
//                             vector can access.
//          allocator = the vector allocator
asyncvec_init_with_size :: proc(
	vec: ^Async_Vec($T), 
	cap: int, 
	max_bucket_count := ASYNCVEC_BUCKETS_DEFAULT_MAX_COUNT, 
	allocator := context.allocator,
) {
	asyncvec_init_empty(vec, max_bucket_count, allocator)
	asyncvec_reserve(vec, cap)
}

asyncvec_init :: proc {
	asyncvec_init_empty,
	asyncvec_init_with_size,
}

// Frees an Async_Vec
asyncvec_delete :: proc(vec: ^Async_Vec($T)) #no_bounds_check {
	for bucket in vec.buckets {
		asyncvecbucket_delete(bucket, vec.allocator)
	}
	delete(vec.buckets, vec.allocator)
}

// Gets the address of an element of the vector specified by its index
// @returns: The address of the specified element. This address is guaranteed to
//           be valid for the entire lifetime of the object
// @thread_safety: Thread-safe
asyncvec_get :: proc(vec: Async_Vec($T), index: int) -> ^T #no_bounds_check {
	when ASYNCVEC_DO_BOUNDS_CHECK {
		assert(index < vec.size, "Out of bounds read")
	}

	bucket_index, element_index := item_index_to_bucket_index(index)
	return &vec.buckets[bucket_index][element_index]
}

// Gets the value of an element of the vector specified by its index
// @thread_safety: Thread-safe
asyncvec_get_value :: proc(vec: Async_Vec($T), index: int) -> T  #no_bounds_check {
	when ASYNCVEC_DO_BOUNDS_CHECK {
		assert(index < vec.size, "Out of bounds read")
	}

	bucket_index, element_index := item_index_to_bucket_index(index)
	return vec.buckets[bucket_index][element_index]
	
}

// Sets the value of an element of the vector specified by its index
// @thread_safety: Thread-safe
asyncvec_set :: #force_inline proc(vec: Async_Vec($T), index: int, value: T) {
	asyncvec_get(vec, index)^ = value
}

// Returns the length of an Async_Vec
// @note: Do not use this to iterate over every position of the vector, since it
//        might change asynchronously
// @thread_safety: Thread-safe
asyncvec_len :: #force_inline proc(vec: Async_Vec($T)) -> int {
	return vec.size
}

// Returns the capacity of an Async_Vec
// @thread_safety: Thread-safe
asyncvec_cap :: #force_inline proc(vec: Async_Vec($T)) -> int {
	return (int)((uint)(1) << (len(vec.buckets) + ASYNCVEC_FIRST_BUCKET_SIZE_LOG2))
}

// Appends a value to the back of an Async_Vec
// @thread_safety: Thread-safe
asyncvec_append :: proc(vec: ^Async_Vec($T), element: T) {
	for {
		current_size := vec.size
		new_size := vec.size + 1

		bucket := highest_bit(current_size + ASYNCVEC_FIRST_BUCKET_SIZE) - ASYNCVEC_FIRST_BUCKET_SIZE_LOG2
		if !asyncvec_is_bucket_usable(vec^, (int)(bucket)) {
			asyncvec_alloc_bucket(vec, (int)(bucket))
		}

		if _, ok := intrinsics.atomic_compare_exchange_strong(
			&vec.size,
			current_size, 
			new_size,
		); ok {
			asyncvec_set(vec^, current_size, element)
			return
		}
	}
}

// Resizes an Async_Vec
// @thread_safety: Thread-safe
asyncvec_resize :: proc(vec: ^Async_Vec($T), size: int) {
	for {
		current_size := vec.size
		new_size := size
		
		asyncvec_reserve(vec, size)

		if _, ok := intrinsics.atomic_compare_exchange_strong(
			&vec.size,
			current_size, 
			new_size,
		); ok {
			return
		}
	}
}

// Specifies the capacity of an Async_Vec
// @note: this procedure does not shrink the vector
// @thread_safety: Thread-safe
asyncvec_reserve :: proc(vec: ^Async_Vec($T), cap: int) {
	if (cap <= asyncvec_cap(vec^)) {
		return
	}

	i := highest_bit(vec.size + ASYNCVEC_FIRST_BUCKET_SIZE - 1)
	if i >= ASYNCVEC_FIRST_BUCKET_SIZE_LOG2 {
		i -= ASYNCVEC_FIRST_BUCKET_SIZE_LOG2
	} else {
		i = 0
	}

	for i < (highest_bit(cap + ASYNCVEC_FIRST_BUCKET_SIZE - 1) - ASYNCVEC_FIRST_BUCKET_SIZE_LOG2) {
		i += 1
		asyncvec_alloc_bucket(vec, (int)(i))
	}
}

@(private="file")
ASYNCVEC_FIRST_BUCKET_SIZE :: 8
@(private="file")
ASYNCVEC_FIRST_BUCKET_SIZE_LOG2 :: 3
@(private="file")
ASYNCVEC_DO_BOUNDS_CHECK :: DEBUG || #config(AE_DO_BOUNDS_CHECK, false)

@(private="file")
asyncvec_alloc_bucket :: proc(vec: ^Async_Vec($T), index: int) {
	when ASYNCVEC_DO_BOUNDS_CHECK {
		assert(index < len(vec.buckets), "The Async_Vec is full. Could not allocate a new bucket.")
	}

	bucket := asyncvecbucket_make(T, (uint)(index), vec.allocator)
	if !asyncvec_set_bucket(vec, bucket, index) {
		asyncvecbucket_delete(bucket, vec.allocator)
	}
}

@(private="file")
asyncvec_set_bucket :: #force_inline proc(vec: ^Async_Vec($T), bucket: [^]T, index: int) -> (did_exchange: bool) #no_bounds_check {
	_, did_exchange = intrinsics.atomic_compare_exchange_strong(&vec.buckets[index], nil, bucket)

	return
}

@(private="file")
asyncvec_is_bucket_usable :: #force_inline proc(vec: Async_Vec($T), index: int) -> bool {
	return vec.buckets[index] != nil
}

@(private="file")
asyncvecbucket_make :: #force_inline proc($T: typeid, designed_index: uint, allocator: runtime.Allocator) -> [^]T {
	bucket_len := 1 << (ASYNCVEC_FIRST_BUCKET_SIZE_LOG2 + designed_index) 
	return make([^]T, bucket_len, allocator)
}

@(private="file")
asyncvecbucket_delete :: #force_inline proc(bucket: [^]$T, allocator: runtime.Allocator) {
	free(bucket, allocator)
}

@(private="file")
highest_bit :: #force_inline proc(x: $T) -> uint where intrinsics.type_is_numeric(T) {
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

