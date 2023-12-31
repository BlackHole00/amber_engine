package ae_interface

import aec "shared:ae_common"

Version :: aec.Version
Config :: aec.Config
User_Config :: aec.User_Config

get_version :: #force_inline proc() -> Version {
	return get_engine_proctable().get_version()
}

get_config :: #force_inline proc() -> Config {
	return get_engine_proctable().get_config()
}

get_userconfig :: #force_inline proc() -> User_Config {
	return get_engine_proctable().get_userconfig()
}

