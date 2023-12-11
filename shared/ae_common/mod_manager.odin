package ae_common

import "core:mem"

Mod_Load_Error :: enum {
	Success = 0,
	Invalid_Path,
	Read_Error,
	Duplicate_Mod,
	Invalid_Mod,
}

Mod_Manager_Register_ModLoader_Proc :: #type proc(mod_loader: Mod_Loader) -> (bool, Mod_Loader_Id)
Mod_Manager_Remove_ModLoader_Proc :: #type proc(loader_id: Mod_Loader_Id) -> bool

Mod_Manager_Get_ModLoaderId :: #type proc(loader_name: string) -> Mod_Loader_Id
Mod_Manager_Get_ModLoaderId_For_File :: #type proc(file_path: string) -> Mod_Loader_Id
Mod_Manager_Is_ModLoaderId_Valid :: #type proc(loader_id: Mod_Loader_Id) -> bool

Mod_Manager_Can_Load_File :: #type proc(file_path: string) -> bool

Mod_Manager_Queue_Load_Mod_Proc :: #type proc(mod_path: string) -> (Mod_Load_Error, Mod_Id)
Mod_Manager_Queue_Load_Folder_Proc :: #type proc(folder_path: string) -> bool
Mod_Manager_Queue_Unload_Mod_Proc :: #type proc(mod_id: Mod_Id) -> bool
Mod_Manager_Force_Load_Queued_Mods_Proc :: #type proc(mod_path: string) -> Mod_Load_Error

Mod_Manager_Get_Mod_ProcTable_Proc :: #type proc(mod_id: Mod_Id) -> rawptr
Mod_Manager_Get_ModInfo_Proc :: #type proc(mod_id: Mod_Id) -> (Mod_Info, bool)

Mod_Manager_Get_ModId_From_Name :: #type proc(mod_name: string) -> Mod_Id
Mod_Manager_Get_ModId_From_Path :: #type proc(mod_path: string) -> Mod_Id

Mod_Manager_Is_ModId_Valid :: #type proc(mod_id: Mod_Id) -> bool
Mod_Manager_Is_Mod_Loaded :: #type proc(mod_name: string) -> bool

Mod_Manager_Get_ModInfo_List_Proc :: #type proc(allocator: mem.Allocator) -> []Mod_Info

