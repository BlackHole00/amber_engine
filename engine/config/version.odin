package amber_engine_config

import aec "shared:ae_common"

VERSION :: aec.Version {
	major    = 0,
	minor    = 1,
	revision = 0,
}

get_version: aec.Get_Version_Proc : proc() -> aec.Version {
	return VERSION
}

