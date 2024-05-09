package tests_utils

import "core:testing"
import "core:thread"
import "shared:amber_engine/utils"

@(test)
asyncvec_datarace :: proc(test: ^testing.T) {
	LOOP_COUNT :: 100000

	SCOPED_TIMING_REPORT()
	context.allocator, _ = SCOPED_MEM_CHECK(test)

	lockless1_threadproc :: proc(vec: ^utils.Async_Vec(int)) {
		for _ in 0 ..< LOOP_COUNT {
			utils.asyncvec_get(vec^, 0)
		}
	}

	lockless2_threadproc :: proc(vec: ^utils.Async_Vec(int)) {
		for i in 0 ..< LOOP_COUNT {
			utils.asyncvec_reserve(vec, i)
		}
	}

	locking_threadproc :: proc(vec: ^utils.Async_Vec(int)) {
		for i in 0 ..< LOOP_COUNT {
			utils.asyncvec_append(vec, i)
		}
	}

	mixed_threadproc :: proc(vec: ^utils.Async_Vec(int)) {
		for i in 0 ..< LOOP_COUNT {
			utils.asyncvec_append(vec, i)
			utils.asyncvec_get(vec^, 0)
			utils.asyncvec_set(vec^, 0, 0)
		}
	}

	vec: utils.Async_Vec(int)
	defer utils.asyncvec_delete(&vec)
	utils.asyncvec_init_empty(&vec, 32)
	utils.asyncvec_append(&vec, 0)

	threads: [TEST_THREAD_COUNT]^thread.Thread
	thread_procs := [TEST_THREAD_COUNT]rawptr {
		0 = auto_cast lockless1_threadproc,
		1 = auto_cast lockless2_threadproc,
		2 = auto_cast locking_threadproc,
		3..<TEST_THREAD_COUNT = auto_cast mixed_threadproc,
	}

	for &t, i in threads {
		t = thread.create_and_start_with_data(
			&vec,
			auto_cast thread_procs[i],
			context,
			.Normal,
			true,
		)
	}
	thread.join_multiple(..threads[:])

	testing.expect_value(test, utils.asyncvec_len(vec), (TEST_THREAD_COUNT - 2) * LOOP_COUNT + 1)
}
