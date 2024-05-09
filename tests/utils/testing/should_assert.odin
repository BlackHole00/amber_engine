package tests_utils_testing

import "core:testing"

@(test)
assertion_detection :: proc(test: ^testing.T) {
	context.assertion_failure_proc = TEST_SHOULD_ASSERT(test)

	assert(false, "This is an assertion")
}

@(test)
multiple_assertions_detection :: proc(test: ^testing.T) {
	context.assertion_failure_proc = TEST_SHOULD_ASSERT(test, 5)

	assert(false, "First assertion")
	assert(false, "Second assertion")
	assert(false, "Third assertion")
	assert(false, "Fourth assertion")
	assert(false, "Fifth assertion")
}

@(test)
assertion_in_procedure :: proc(test: ^testing.T) {
	will_assert :: proc(i: int) -> int {
		i := i
		i += 42

		assert(false, "Assertion inside of function")

		return i * 2
	}

	context.assertion_failure_proc = TEST_SHOULD_ASSERT(test)

	i := will_assert(24)
	testing.expect_value(test, i, 132)
}

