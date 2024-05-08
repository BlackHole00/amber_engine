package tests_utils

import "core:testing"
import "core:thread"
import "shared:amber_engine/utils"
import ae_test "shared:amber_engine/utils/testing"

@(test)
idgenerator_datarace :: proc(test: ^testing.T) {
	ae_test.SCOPED_TIMING_REPORT()
	LOOP_COUNT :: 100000

	thread_proc :: proc(generator: ^utils.Id_Generator(int)) {
		for _ in 0..<LOOP_COUNT {
			utils.idgenerator_generate(generator)
			assert(!utils.idgenerator_is_id_valid(generator^, max(int)))
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
		utils.idgenerator_peek_next(generator) == LOOP_COUNT * TEST_THREAD_COUNT,
		"Invalid final id",
	)
}
