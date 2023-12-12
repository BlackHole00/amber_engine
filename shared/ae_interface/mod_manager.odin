package ae_interface

import "core:mem"
import aec "shared:ae_common"

// @Singleton:

Mod_Loader :: aec.Mod_Loader
Mod_Loader_Id :: aec.Mod_Loader_Id
Mod_Info :: aec.Mod_Info
Mod_Id :: aec.Mod_Id
Mod_Load_Error :: aec.Mod_Load_Error

INVALID_MODID :: aec.INVALID_MODID
INVALID_MODLOADERID :: aec.INVALID_MODLOADERID

modmanager_register_modloader :: #force_inline proc(mod_loader: Mod_Loader) -> Mod_Loader_Id {
	return AE_MOD_PROC_TABLE.modmanager_register_modloader(mod_loader)
}

modmanager_remove_modloader :: #force_inline proc(modloader_identifier: Mod_Loader_Id) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_remove_modloader(modloader_identifier)
}

modmanager_get_modloaderid :: #force_inline proc(loader_name: string) -> aec.Mod_Loader_Id {
	return AE_MOD_PROC_TABLE.modmanager_get_modloaderid(loader_name)
}

modmanager_get_modloaderid_for_file :: #force_inline proc(file_path: string) -> aec.Mod_Loader_Id {
	return AE_MOD_PROC_TABLE.modmanager_get_modloaderid_for_file(file_path)
}

modmanager_is_modloaderid_valid :: #force_inline proc(loader_id: aec.Mod_Loader_Id) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_is_modloaderid_valid(loader_id)
}

modmanager_can_load_file :: #force_inline proc(file_path: string) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_can_load_file(file_path)
}

modmanager_queue_load_mod :: #force_inline proc(
	mod_path: string,
) -> (
	aec.Mod_Load_Error,
	aec.Mod_Id,
) {
	return AE_MOD_PROC_TABLE.modmanager_queue_load_mod(mod_path)
}

modmanager_queue_load_folder :: #force_inline proc(folder_path: string) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_queue_load_folder(folder_path)
}

modmanager_queue_unload_mod :: #force_inline proc(mod_id: aec.Mod_Id) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_queue_unload_mod(mod_id)
}

modmanager_force_load_queued_mods :: #force_inline proc() -> bool {
	return AE_MOD_PROC_TABLE.modmanager_force_load_queued_mods()
}

modmanager_get_mod_proctable :: #force_inline proc(mod_id: aec.Mod_Id) -> rawptr {
	return AE_MOD_PROC_TABLE.modmanager_get_mod_proctable(mod_id)
}

modmanager_get_modinfo :: #force_inline proc(mod_id: aec.Mod_Id) -> (aec.Mod_Info, bool) {
	return AE_MOD_PROC_TABLE.modmanager_get_modinfo(mod_id)
}

modmanager_get_modid_from_name :: #force_inline proc(mod_name: string) -> aec.Mod_Id {
	return AE_MOD_PROC_TABLE.modmanager_get_modid_from_name(mod_name)
}

modmanager_get_modid_from_path :: #force_inline proc(mod_path: string) -> aec.Mod_Id {
	return AE_MOD_PROC_TABLE.modmanager_get_modid_from_path(mod_path)
}

modmanager_is_modid_valid :: #force_inline proc(mod_id: aec.Mod_Id) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_is_modid_valid(mod_id)
}

modmanager_is_modid_loaded :: #force_inline proc(mod_id: aec.Mod_Id) -> bool {
	return AE_MOD_PROC_TABLE.modmanager_is_modid_loaded(mod_id)
}

modmanager_get_modinfo_list :: #force_inline proc(allocator: mem.Allocator) -> []Mod_Info {
	return AE_MOD_PROC_TABLE.modmanager_get_modinfo_list(allocator)
}

