package amber_engine_interface

import "engine:globals"
import ae "shared:amber_engine/common"

get_config: ae.Get_Config_Proc : proc() -> ae.Config {
	return globals.config
}

get_userconfig: ae.Get_UserConfig_Proc : proc() -> ae.User_Config {
	return globals.config.user_config
}

