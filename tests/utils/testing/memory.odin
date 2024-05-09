package tests_utils_testing

import "core:testing"

@(test)
no_memory_leaks :: proc(test: ^testing.T) {
	context.allocator, _ = SCOPED_MEM_CHECK(test)

	ptr := new(int)
	free(ptr)
}

@(test)
detect_memory_leak :: proc(test: ^testing.T) {
	context.assertion_failure_proc = TEST_SHOULD_ASSERT(test)
	context.allocator, _ = SCOPED_MEM_CHECK(test, true)

	_ = new(int)
}

@(test)
detect_bad_free :: proc(test: ^testing.T) {
	context.assertion_failure_proc = TEST_SHOULD_ASSERT(test)
	context.allocator, _ = SCOPED_MEM_CHECK(test, true)

	ptr := new(int)
	free(ptr)
	free(ptr)
}

@(test)
detect_memory_leak_and_bad_free :: proc(test: ^testing.T) {
	context.assertion_failure_proc = TEST_SHOULD_ASSERT(test, 2)
	context.allocator, _ = SCOPED_MEM_CHECK(test, true)

	ptr := new(int)
	free(ptr)
	free(ptr)

	_ = new(int)
}
