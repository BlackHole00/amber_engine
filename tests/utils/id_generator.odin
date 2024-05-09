package tests_utils

import "core:testing"
import "core:thread"
import "shared:amber_engine/utils"

@(test)
idgenerator_generate :: proc(test: ^testing.T) {
	LOOP_COUNT :: 100000

	SCOPED_TIMING_REPORT()
	context.allocator, _ = SCOPED_MEM_CHECK(test)

	generator: utils.Id_Generator(int)
	testing.expect_value(
		test,
		utils.idgenerator_peek_next(&generator),
		0,
	)

	for _ in 0..<LOOP_COUNT {
		utils.idgenerator_generate(&generator)
	}

	testing.expect_value(
		test,
		utils.idgenerator_peek_next(&generator),
		LOOP_COUNT,
	)
}

@(test)
idgenerator_overflow :: proc(test: ^testing.T) {
	SCOPED_TIMING_REPORT()
	context.allocator, _ = SCOPED_MEM_CHECK(test)
	context.assertion_failure_proc = TEST_SHOULD_ASSERT(test)

	generator: utils.Id_Generator(int)
	generator.counter = max(int)

	utils.idgenerator_generate(&generator)
}

@(test)
idgenerator_datarace :: proc(test: ^testing.T) {
	LOOP_COUNT :: 100000

	SCOPED_TIMING_REPORT()
	context.allocator, _ = SCOPED_MEM_CHECK(test)

	thread_proc :: proc(generator: ^utils.Id_Generator(int)) {
		for _ in 0..<LOOP_COUNT {
			utils.idgenerator_generate(generator)
			assert(!utils.idgenerator_is_id_valid(generator, max(int)))
		}
	}

	generator: utils.Id_Generator(int)

	threads: [TEST_THREAD_COUNT]^thread.Thread
	for &t in threads {
		t = thread.create_and_start_with_data(
			&generator,
			auto_cast thread_proc,
			context,
			.Normal,
			true,
		)
	}
	thread.join_multiple(..threads[:])

	testing.expect(
		test,
		utils.idgenerator_peek_next(&generator) == LOOP_COUNT * TEST_THREAD_COUNT,
		"Invalid final id",
	)
}

