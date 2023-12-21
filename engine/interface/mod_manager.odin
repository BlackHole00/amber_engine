package amber_engine_interface

import "core:mem"
import "engine:globals"
import "engine:loader"
import aec "shared:ae_common"

@(private)
modmanager_register_modloader: aec.Mod_Manager_Register_ModLoader_Proc : proc(
	mod_loader: aec.Mod_Loader,
) -> aec.Mod_Loader_Id {
	return loader.modmanager_register_modloader(&globals.mod_manager, mod_loader)
}

@(private)
modmanager_remove_modloader: aec.Mod_Manager_Remove_ModLoader_Proc : proc(
	loader_id: aec.Mod_Loader_Id,
) -> bool {
	return loader.modmanager_remove_modloader(&globals.mod_manager, loader_id)
}

@(private)
modmanager_get_modloaderid: aec.Mod_Manager_Get_ModLoaderId_Proc : proc(
	loader_name: string,
) -> aec.Mod_Loader_Id {
	return loader.modmanager_get_modloaderid(globals.mod_manager, loader_name)
}

@(private)
modmanager_get_modloaderid_for_file: aec.Mod_Manager_Get_ModLoaderId_For_File_Proc : proc(
	file_path: string,
) -> aec.Mod_Loader_Id {
	return loader.modmanager_get_modloaderid_for_file(&globals.mod_manager, file_path)
}

@(private)
modmanager_is_modloaderid_valid: aec.Mod_Manager_Is_ModLoaderId_Valid : proc(
	loader_id: aec.Mod_Loader_Id,
) -> bool {
	return loader.modmanager_is_modloaderid_valid(globals.mod_manager, loader_id)
}

@(private)
modmanager_can_load_file: aec.Mod_Manager_Can_Load_File_Proc : proc(file_path: string) -> bool {
	return loader.modmanager_can_load_file(&globals.mod_manager, file_path)
}

@(private)
modmanager_queue_load_mod: aec.Mod_Manager_Queue_Load_Mod_Proc : proc(
	mod_path: string,
) -> (
	aec.Mod_Load_Error,
	aec.Mod_Id,
) {
	return loader.modmanager_queue_load_mod(&globals.mod_manager, mod_path)
}

@(private)
modmanager_queue_load_folder: aec.Mod_Manager_Queue_Load_Folder_Proc : proc(
	folder_path: string,
) -> bool {
	return loader.modmanager_queue_load_folder(&globals.mod_manager, folder_path)
}

@(private)
modmanager_queue_unload_mod: aec.Mod_Manager_Queue_Unload_Mod_Proc : proc(
	mod_id: aec.Mod_Id,
) -> bool {
	return loader.modmanager_queue_unload_mod(&globals.mod_manager, mod_id)
}

@(private)
modmanager_force_load_queued_mods: aec.Mod_Manager_Force_Load_Queued_Mods_Proc : proc() -> bool {
	return loader.modmanager_force_load_queued_mods(&globals.mod_manager)
}

@(private)
modmanager_get_mod_proctable: aec.Mod_Manager_Get_Mod_ProcTable_Proc : proc(
	mod_id: aec.Mod_Id,
) -> rawptr {
	return loader.modmanager_get_mod_proctable(&globals.mod_manager, mod_id)
}

@(private)
modmanager_get_modinfo: aec.Mod_Manager_Get_ModInfo_Proc : proc(
	mod_id: aec.Mod_Id,
) -> (
	aec.Mod_Info,
	bool,
) {
	return loader.modmanager_get_modinfo(&globals.mod_manager, mod_id)
}

@(private)
modmanager_get_modid_from_name: aec.Mod_Manager_Get_ModId_From_Name_Proc : proc(
	mod_name: string,
) -> aec.Mod_Id {
	return loader.modmanager_get_modid_from_name(globals.mod_manager, mod_name)
}

@(private)
modmanager_get_modid_from_path: aec.Mod_Manager_Get_ModId_From_Path_Proc : proc(
	mod_path: string,
) -> aec.Mod_Id {
	return loader.modmanager_get_modid_from_path(globals.mod_manager, mod_path)
}

@(private)
modmanager_is_modid_valid: aec.Mod_Manager_Is_ModId_Valid_Proc : proc(mod_id: aec.Mod_Id) -> bool {
	return loader.modmanager_is_modid_valid(globals.mod_manager, mod_id)
}

@(private)
modmanager_get_mod_status: aec.Mod_Manager_Get_Mod_Status : proc(
	mod_id: aec.Mod_Id,
) -> aec.Mod_Status {
	return loader.modmanager_get_mod_status(globals.mod_manager, mod_id)
}

@(private)
modmanager_get_modinfo_list: aec.Mod_Manager_Get_ModInfo_List_Proc : proc(
	allocator: mem.Allocator,
) -> []aec.Mod_Info {
	return loader.modmanager_get_modinfo_list(&globals.mod_manager, allocator)
}

