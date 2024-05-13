package amber_engine_utils_testing

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:testing"

@(deferred_in=end_should_assert)
TEST_SHOULD_ASSERT :: proc(
	test: ^testing.T,
	expected_assertions: uint = 0,
	location := #caller_location,
) -> runtime.Assertion_Failure_Proc {
	@(optimization_mode="none")
	assertion_proc :: #force_no_inline proc(
		prefix: string,
		message: string,
		loc: runtime.Source_Code_Location,
	) -> ! {
		fmt.printf("[Assertion: %s] %s\n", TEST_SHOULD_ASSERT_DATA.test_name, message)
		intrinsics.atomic_add(&TEST_SHOULD_ASSERT_DATA.assertion_count, 1)

		_escape_assertion()
	}

	TEST_SHOULD_ASSERT_DATA.test_name = location.procedure
	
	return assertion_proc
}

@(private="file")
TEST_SHOULD_ASSERT_DATA: struct {
	assertion_count: uint,
	test_name: string,
}

@(private="file")
end_should_assert :: proc(
	test: ^testing.T,
	expected_assertions: uint,
	location: runtime.Source_Code_Location,
) {
	testing.expectf(
		test,
		TEST_SHOULD_ASSERT_DATA.assertion_count != 0,
		"The test didn't assert",
	)

	testing.expectf(
		test,
		expected_assertions == 0 || TEST_SHOULD_ASSERT_DATA.assertion_count == expected_assertions,
		"The test asserted the wrong amount of times (found %d, expected %d)",
		TEST_SHOULD_ASSERT_DATA.assertion_count,
		expected_assertions,
		loc = location,
	)

	TEST_SHOULD_ASSERT_DATA = {}
}

