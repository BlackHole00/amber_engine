package amber_engine_utils

import "core:mem"
import "core:sync"

// Rc is a smart pointer with reference counting. If you are using this type 
// please consider also other solutions. Reference counted pointer can (and 
// will) make your code base more complicated
// @note: T cannot be a primitive type
// @thread_safety: Not thread-safe
Rc :: struct($T: typeid) {
	using _rc_internal_data:      T,
	_rc_internal_reference_count: uint,
	_rc_internal_allocator:       mem.Allocator,
}

// Arc is a smart pointer with atomic reference counting. Like Rc if you are
// using this type please consider other solutions.
// @note: T cannot be a primitive type
// @thread_safety: Thread-safe
Arc :: struct($T: typeid) {
	using _arc_internal_data:      T,
	_arc_internal_reference_count: uint,
	_arc_internal_allocator:       mem.Allocator,
}

// Allocates a new zero-initialized Rc
// @thread_safety: Not thread-safe
rc_new_empty :: proc($T: typeid, allocator := context.allocator) -> ^Rc(T) {
	rc := new(T, allocator)

	rc._rc_internal_reference_count = 1
	rc._rc_internal_allocator = allocator

	return rc
}

// Allocates a new initalized with data Rc
// @thread_safety: Not thread-safe
rc_new_with_data :: proc(data: $T, allocator := context.allocator) -> ^Rc(T) {
	rc := rc_new_empty(Rc(T), allocator)

	rc._rc_internal_data^ = data

	return rc
}

// Increases the internal reference count of a Rc
// @thread_safety: Not thread-safe
nrc_add_ref :: proc(rc: ^Rc($T)) {
	rc._rc_internal_reference_count += 1
}

// Increases the internal reference count of a Rc and returns its copy, it is
// usefull if the Rc needs to be passed as parameter
// @thread_safety: Not thread-safe
nrc_clone :: proc(rc: ^Rc($T)) -> ^Rc(T) {
	nrc_add_ref(rc)
	return rc
}

// Decreases the internal reference counter of a Rc and eventually frees its
// data
// @memory_safety: After a drop a Rc cannot be used
// @thread_safety: Not thread-safe
nrc_drop :: proc(rc: ^Rc($T)) {
	rc._rc_internal_reference_count -= 1

	if rc._rc_internal_reference_count == 0 {
		free(rc, rc._rc_internal_allocator)
	}
}

// Forces a Rc to free its data 
// @memory_safety: unsafe, make sure nobody is using the pointer
// @thread_safety: Not thread-safe
nrc_force_free :: proc(rc: ^Rc($T)) {
	free(rc, rc._rc_internal_allocator)
}

// Returns the associated pointer of a Rc
// @memory_safety: safe, until rc_drop() or rc_force_free() is called
// @thread_safety: Not thread-safe
nrc_as_ptr :: proc(rc: ^Rc($T)) -> ^T {
	return rc._rc_internal_data
}

// Allocates a new zero-initialized Arc
arc_new_empty :: proc($T: typeid, allocator := context.allocator) -> ^Arc(T) {
	arc := new(Arc(T), allocator)

	arc._arc_internal_reference_count = 1
	arc._arc_internal_allocator = allocator

	return arc
}

// Allocates a new initalized with data Arc
// @thread_safety: Thread-safe
arc_new_with_data :: proc(data: $T, allocator := context.allocator) -> ^Arc(T) {
	arc := arc_new_empty(T, allocator)

	arc._arc_internal_data^ = data

	return arc
}

// Increases the internal reference count of an Arc
// @thread_safety: Thread-safe
arc_add_ref :: proc(arc: ^Arc($T)) {
	sync.atomic_add(&arc._arc_internal_reference_count, 1)
}

// Increases the internal reference count of an Arc and returns its copy, it is
// usefull if the Arc needs to be passed as parameter
// @thread_safety: Thread-safe
arc_clone :: proc(arc: ^Arc($T)) -> ^Arc(T) {
	arc_add_ref(arc)
	return arc
}

// Decreases the internal reference counter of an Arc and eventually frees its
// data
// @memory_safety: After a drop an Arc cannot be used
// @thread_safety: Thread-safe
arc_drop :: proc(arc: ^Arc($T)) {
	if sync.atomic_sub_explicit(&arc._arc_internal_reference_count, 1, .Release) == 1 {
		sync.atomic_thread_fence(.Acquire)
		free(arc, arc._arc_internal_allocator)
	}
}

// Forces an Arc to free its data 
// @memory_safety: unsafe, make sure nobody is using the pointer
// @thread_safety: Thread-safe
arc_force_free :: proc(arc: ^Arc($T)) {
	free(arc, arc._arc_internal_allocator)
}

// Returns the associated pointer of an Arc
// @memory_safety: safe, until rc_drop() or rc_force_free() is called
// @thread_safety: Thread-safe
arc_as_ptr :: proc(arc: ^Arc($T)) -> ^T {
	return &arc._arc_internal_data
}

rc_new :: proc {
	rc_new_empty,
	rc_new_with_data,
}

arc_new :: proc {
	arc_new_empty,
	arc_new_with_data,
}

rc_add_ref :: proc {
	nrc_add_ref,
	arc_add_ref,
}

rc_clone :: proc {
	nrc_clone,
	arc_clone,
}

rc_drop :: proc {
	nrc_drop,
	arc_drop,
}

rc_force_free :: proc {
	nrc_force_free,
	arc_force_free,
}

rc_as_ptr :: proc {
	nrc_as_ptr,
	arc_as_ptr,
}

_ :: mem
_ :: sync

