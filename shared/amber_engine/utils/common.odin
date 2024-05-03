package amber_engine_utils

DEBUG :: ODIN_DEBUG || #config(AE_DEBUG, false)
RELEASE :: !DEBUG && #config(AE_RELEASE, false)

