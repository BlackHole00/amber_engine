package amber_engine_config

import "core:os"
import "core:strings"
import "core:encoding/json"
import aec "shared:ae_common"

Config :: aec.Config
User_Config :: aec.User_Config
User_Config_Autogenerated :: aec.User_Config_Autogenerated
User_Config_Source :: aec.User_Config_Source
User_Config_Source_File :: aec.User_Config_Source_File

DEFAULT_CONFIG_NAME :: "amber_engine.json"
DEFAULT_CONFIG := Config {
	user_config = User_Config{mods_location = "mods"},
	user_config_source = User_Config_Autogenerated{},
	version = VERSION,
}

UserConfig_Parse_Error :: enum {
	Success = 0,
	File_Not_Found,
	Read_Error,
	Parse_Error,
}

config_from_file :: proc(
	config: ^Config,
	config_path: string,
	allocator := context.allocator,
) -> UserConfig_Parse_Error {
	context.allocator = allocator

	real_config_path, path_ok := get_real_userconfigpath(config_path, allocator)
	if !path_ok {
		return .File_Not_Found
	}

	config_content, file_open_ok := os.read_entire_file(real_config_path, allocator)
	defer delete(config_content, allocator)
	if !file_open_ok {
		return .Read_Error
	}

	user_config: User_Config
	parse_error := json.unmarshal(config_content, &user_config)
	if parse_error != nil {
		return .Parse_Error
	}

	config_from_userconfig(config, user_config, real_config_path)

	return .Success
}

config_from_userconfig :: proc(
	config: ^Config,
	user_config: User_Config,
	user_config_source: User_Config_Source,
) {
	config.user_config = user_config
	config.user_config_source = user_config_source
	config.version = DEFAULT_CONFIG.version
}

config_from_file_or_default :: proc(
	config: ^Config,
	config_path: string,
	allocator := context.allocator,
) -> (
	from_file: bool,
) {
	if config_from_file(config, config_path, allocator) == .Success {
		return true
	}

	config^ = DEFAULT_CONFIG
	return false
}

config_free :: proc(config: Config, allocator := context.allocator) {
	if path, ok := config.user_config_source.(User_Config_Source_File); ok {
		delete(path, allocator)
		delete(config.mods_location, allocator)
	}
}

// user_config_path could be either a path to the config or a path to the folder containing it.
// Return: new string containing a path to the config file, must be freed.
@(private)
get_real_userconfigpath :: proc(
	user_config_path: string,
	allocator := context.allocator,
) -> (
	string,
	bool,
) {
	// D3ssy says: "h"
	if os.is_file(user_config_path) {
		return strings.clone(user_config_path, allocator), true
	}

	if !os.is_dir(user_config_path) {
		return "", false
	}

	new_real_path := strings.concatenate(
		[]string{user_config_path, "/", DEFAULT_CONFIG_NAME},
		allocator,
	)

	if !os.is_file(new_real_path) {
		delete(new_real_path, allocator)
		return "", false
	}

	return new_real_path, true
}

