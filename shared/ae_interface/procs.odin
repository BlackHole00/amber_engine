package ae_interface

import "core:os"
import aec "shared:ae_common"

get_version :: #force_inline proc() -> aec.Version {
	return AE_MOD_PROC_TABLE.get_version()
}

get_config :: #force_inline proc() -> aec.Config {
	return AE_MOD_PROC_TABLE.get_config()
}

get_userconfig :: #force_inline proc() -> aec.Config {
	return AE_MOD_PROC_TABLE.get_userconfig()
}

modmanager_register_modloader :: #force_inline proc(mod_loader: aec.Mod_Loader) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_register_modloader(mod_loader)
}

modmanager_remove_modloader :: #force_inline proc(modloader_identifier: string) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_remove_modloader(modloader_identifier)
}

modmanager_replace_mod_loader :: proc(mod_loader: aec.Mod_Loader) -> bool {
	if !modmanager_remove_modloader(mod_loader.identifier) {
		return false
	}

	return modmanager_register_modloader(mod_loader)
}

modmanager_queue_load_mod :: #force_inline proc(mod_path: string) -> aec.Mod_Load_Error {
	return AE_MOD_PROC_TABLE.modmanager_queue_load_mod(mod_path)
}

modmanager_queue_load_mods_folder :: proc(mod_folder_path: string) -> (res: aec.Mod_Load_Error) {
	if !os.is_dir(mod_folder_path) {
		return .Invalid_Path
	}

	folder_handle, handle_ok := os.open(mod_folder_path)
	if handle_ok != os.ERROR_NONE {
		return .Read_Error
	}

	files_infos, infos_ok := os.read_dir(folder_handle)
	if infos_ok != os.ERROR_NONE {
		return .Read_Error
	}

	for info in files_infos {
		mod_load_res := modmanager_queue_load_mod(info.fullpath)
		if mod_load_res != .Success {
			res = mod_load_res
		}
	}

	return
}

