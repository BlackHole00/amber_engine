package amber_engine_utils_testing

@(private)
Escape_Offsets :: struct {
	assertion_proc_offset: int,
	internal_assertion_offset: int,
}

@(private="file", export)
ESCAPE_ASSERTION_OFFSETS: Escape_Offsets
// } = {
// 	0xd0,
// 	0x60,
// }

@(private="file", init)
escapeoffsets_init :: proc() {
	ALLOW_UNKNOWN_VERSIONS :: #config(AE_ALLOW_UNKNOWN_VERSIONS, false)
	OPTIMIZATION_LEVEL :: #config(AE_OPTIMIZATION_LEVEL, "none")

	when ODIN_VERSION == "dev-2024-05" {
		when OPTIMIZATION_LEVEL == "none" {
			ESCAPE_ASSERTION_OFFSETS = { 0xd0, 0x60 }
		} else {
			#panic("amber_engine/utils/testing only supports -o=none")
		}
	} else {
		when ALLOW_UNKNOWN_VERSIONS {
			#panic(
				"Unsupported Odin version. Skip this error by defining AE_ALLOW_UNKNOWN_VERSIONS",
			)
		} else {
			when OPTIMIZATION_LEVEL == "none" {
				ESCAPE_ASSERTION_OFFSETS = { 0xd0, 0x60 }
			} else {
				#panic("amber_engine/utils/testing only supports -o=none")
			}
		}
	}
}

