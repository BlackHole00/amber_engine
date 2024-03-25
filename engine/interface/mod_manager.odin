package amber_engine_interface

import "core:mem"
import "engine:globals"
import "engine:loader"
import ae "shared:amber_engine/common"

@(private)
modmanager_register_modloader: ae.Mod_Manager_Register_ModLoader_Proc : proc(
	mod_loader: ae.Mod_Loader,
) -> ae.Mod_Loader_Id {
	return loader.modmanager_register_modloader(&globals.mod_manager, mod_loader)
}

@(private)
modmanager_remove_modloader: ae.Mod_Manager_Remove_ModLoader_Proc : proc(
	loader_id: ae.Mod_Loader_Id,
) -> bool {
	return loader.modmanager_remove_modloader(&globals.mod_manager, loader_id)
}

@(private)
modmanager_get_modloaderid: ae.Mod_Manager_Get_ModLoaderId_Proc : proc(
	loader_name: string,
) -> ae.Mod_Loader_Id {
	return loader.modmanager_get_modloaderid(globals.mod_manager, loader_name)
}

@(private)
modmanager_get_modloaderid_for_file: ae.Mod_Manager_Get_ModLoaderId_For_File_Proc : proc(
	file_path: string,
) -> ae.Mod_Loader_Id {
	return loader.modmanager_get_modloaderid_for_file(&globals.mod_manager, file_path)
}

@(private)
modmanager_is_modloaderid_valid: ae.Mod_Manager_Is_ModLoaderId_Valid : proc(
	loader_id: ae.Mod_Loader_Id,
) -> bool {
	return loader.modmanager_is_modloaderid_valid(globals.mod_manager, loader_id)
}

@(private)
modmanager_can_load_file: ae.Mod_Manager_Can_Load_File_Proc : proc(file_path: string) -> bool {
	return loader.modmanager_can_load_file(&globals.mod_manager, file_path)
}

@(private)
modmanager_queue_load_mod: ae.Mod_Manager_Queue_Load_Mod_Proc : proc(
	mod_path: string,
) -> (
	ae.Mod_Load_Error,
	ae.Mod_Id,
) {
	return loader.modmanager_queue_load_mod(&globals.mod_manager, mod_path)
}

@(private)
modmanager_queue_load_folder: ae.Mod_Manager_Queue_Load_Folder_Proc : proc(
	folder_path: string,
) -> bool {
	return loader.modmanager_queue_load_folder(&globals.mod_manager, folder_path)
}

@(private)
modmanager_queue_unload_mod: ae.Mod_Manager_Queue_Unload_Mod_Proc : proc(
	mod_id: ae.Mod_Id,
) -> bool {
	return loader.modmanager_queue_unload_mod(&globals.mod_manager, mod_id)
}

@(private)
modmanager_force_load_queued_mods: ae.Mod_Manager_Force_Load_Queued_Mods_Proc : proc() -> bool {
	return loader.modmanager_force_load_queued_mods(&globals.mod_manager)
}

@(private)
modmanager_get_mod_proctable: ae.Mod_Manager_Get_Mod_ProcTable_Proc : proc(
	mod_id: ae.Mod_Id,
) -> rawptr {
	return loader.modmanager_get_mod_proctable(&globals.mod_manager, mod_id)
}

@(private)
modmanager_get_modinfo: ae.Mod_Manager_Get_ModInfo_Proc : proc(
	mod_id: ae.Mod_Id,
) -> (
	ae.Mod_Info,
	bool,
) {
	return loader.modmanager_get_modinfo(&globals.mod_manager, mod_id)
}

@(private)
modmanager_get_modid_from_name: ae.Mod_Manager_Get_ModId_From_Name_Proc : proc(
	mod_name: string,
) -> ae.Mod_Id {
	return loader.modmanager_get_modid_from_name(globals.mod_manager, mod_name)
}

@(private)
modmanager_get_modid_from_path: ae.Mod_Manager_Get_ModId_From_Path_Proc : proc(
	mod_path: string,
) -> ae.Mod_Id {
	return loader.modmanager_get_modid_from_path(globals.mod_manager, mod_path)
}

@(private)
modmanager_is_modid_valid: ae.Mod_Manager_Is_ModId_Valid_Proc : proc(mod_id: ae.Mod_Id) -> bool {
	return loader.modmanager_is_modid_valid(globals.mod_manager, mod_id)
}

@(private)
modmanager_get_mod_status: ae.Mod_Manager_Get_Mod_Status : proc(
	mod_id: ae.Mod_Id,
) -> ae.Mod_Status {
	return loader.modmanager_get_mod_status(globals.mod_manager, mod_id)
}

@(private)
modmanager_get_modinfo_list: ae.Mod_Manager_Get_ModInfo_List_Proc : proc(
	allocator: mem.Allocator,
) -> []ae.Mod_Info {
	return loader.modmanager_get_modinfo_list(&globals.mod_manager, allocator)
}

