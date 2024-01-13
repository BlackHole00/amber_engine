package ae_common

import "core:log"

Version :: struct {
	major:    u32,
	minor:    u32,
	revision: u32,
}

User_Config :: struct {
	mods_location:     string,
	scheduler_threads: int,
	logging_level:     log.Level,
}

User_Config_Source_File :: string
User_Config_Autogenerated :: struct {}

User_Config_Source :: union #no_nil {
	User_Config_Source_File,
	User_Config_Autogenerated,
}

Config :: struct {
	using user_config:  User_Config,
	user_config_source: User_Config_Source,
	version:            Version,
}

Get_Config_Proc :: #type proc() -> Config
Get_UserConfig_Proc :: #type proc() -> User_Config

