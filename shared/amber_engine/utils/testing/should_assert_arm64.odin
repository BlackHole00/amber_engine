package amber_engine_utils_testing

foreign import should_fail "should_assert_arm64.s"

foreign should_fail {
	@(link_name = "asm_escape_assertion")
	_escape_assertion :: proc "c" () -> ! ---
}

