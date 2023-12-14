package amber_engine_interface

import "engine:globals"
import aec "shared:ae_common"

get_config: aec.Get_Config_Proc : proc() -> aec.Config {
	return globals.config
}

get_userconfig: aec.Get_UserConfig_Proc : proc() -> aec.User_Config {
	return globals.config.user_config
}

