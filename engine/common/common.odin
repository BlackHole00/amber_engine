package amber_engine_common

DEBUG :: ODIN_DEBUG || #config(AE_DEBUG, false)
RELEASE :: !DEBUG && #config(AE_RELEASE, false)

