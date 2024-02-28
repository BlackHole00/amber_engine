package amber_engine_common

import "core:mem"
import "core:sync"

Rc :: struct($T: typeid) {
	using _rc_internal_data:      T,
	_rc_internal_reference_count: uint,
	_rc_internal_allocator:       mem.Allocator,
}

// Mom, can we have rust at home? We already have rust at home. Rust at home:
Arc :: struct($T: typeid) {
	using _arc_internal_data:      T,
	_arc_internal_reference_count: uint,
	_arc_internal_allocator:       mem.Allocator,
}

rc_new :: proc {
	nrc_new_empty,
	nrc_new_with_data,
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

nrc_new_empty :: proc($T: typeid, allocator: mem.Allocator) -> ^Rc(T) {
	rc := new(T, allocator)

	rc._rc_internal_reference_count = 1
	rc._rc_internal_allocator = allocator

	return rc
}

nrc_new_with_data :: proc(data: $T, allocator: mem.Allocator) -> ^Rc(T) {
	rc := nrc_new_empty(Rc(T), allocator)

	rc._rc_internal_data^ = data

	return rc
}

nrc_add_ref :: proc(rc: ^Rc($T)) {
	rc._rc_internal_reference_count += 1
}

nrc_clone :: proc(rc: ^Rc($T)) -> ^Rc(T) {
	nrc_add_ref(rc)
	return rc
}

nrc_drop :: proc(rc: ^Rc($T)) {
	rc._rc_internal_reference_count -= 1

	if rc._rc_internal_reference_count == 0 {
		free(rc, rc._rc_internal_allocator)
	}
}

nrc_force_free :: proc(rc: ^Rc($T)) {
	free(rc, rc._rc_internal_allocator)
}

nrc_as_ptr :: proc(rc: ^Rc($T)) -> ^T {
	return rc._rc_internal_data
}

arc_new_empty :: proc($T: typeid, allocator: mem.Allocator) -> ^Arc(T) {
	arc := new(Arc(T), allocator)

	arc._arc_internal_reference_count = 1
	arc._arc_internal_allocator = allocator

	return arc
}

arc_new_with_data :: proc(data: $T, allocator: mem.Allocator) -> ^Arc(T) {
	arc := arc_new_empty(T, allocator)

	arc._arc_internal_data^ = data

	return arc
}

arc_add_ref :: proc(arc: ^Arc($T)) {
	sync.atomic_add(&arc._arc_internal_reference_count, 1)
}

arc_clone :: proc(arc: ^Arc($T)) -> ^Arc(T) {
	arc_add_ref(arc)
	return arc
}

arc_drop :: proc(arc: ^Arc($T)) {
	if sync.atomic_sub_explicit(&arc._arc_internal_reference_count, 1, .Release) == 1 {
		sync.atomic_thread_fence(.Acquire)
		free(arc, arc._arc_internal_allocator)
	}
}

arc_force_free :: proc(arc: ^Arc($T)) {
	free(arc, arc._arc_internal_allocator)
}

arc_as_ptr :: proc(arc: ^Arc($T)) -> ^T {
	return &arc._arc_internal_data
}

_ :: mem
_ :: sync

