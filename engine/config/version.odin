package amber_engine_config

import ae "shared:amber_engine/common"

VERSION :: ae.Version {
	major    = 0,
	minor    = 1,
	revision = 0,
}

get_version: ae.Get_Version_Proc : proc() -> ae.Version {
	return VERSION
}

