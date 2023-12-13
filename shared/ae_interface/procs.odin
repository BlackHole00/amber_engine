package ae_interface

import aec "shared:ae_common"

Version :: aec.Version
Config :: aec.Config
User_Config :: aec.User_Config

get_version :: #force_inline proc() -> Version {
	return AE_MOD_PROC_TABLE.get_version()
}

get_config :: #force_inline proc() -> Config {
	return AE_MOD_PROC_TABLE.get_config()
}

get_userconfig :: #force_inline proc() -> User_Config {
	return AE_MOD_PROC_TABLE.get_userconfig()
}

