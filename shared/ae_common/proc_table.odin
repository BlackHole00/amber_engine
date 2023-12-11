package ae_common

Proc_Table :: struct {
	get_version:                       Get_Version_Proc,
	get_config:                        Get_Config_Proc,
	get_userconfig:                    Get_UserConfig_Proc,
	modmanager_register_modloader:     Mod_Manager_Register_ModLoader_Proc,
	modmanager_remove_modloader:       Mod_Manager_Remove_ModLoader_Proc,
	modmanager_get_modloader_id:       Mod_Manager_Get_ModLoaderId,
	modmanager_queue_load_mod:         Mod_Manager_Queue_Load_Mod_Proc,
	modmanager_queue_load_folder:      Mod_Manager_Queue_Load_Folder_Proc,
	modmanager_queue_unload_mod:       Mod_Manager_Queue_Unload_Mod_Proc,
	modmanager_force_load_queued_mods: Mod_Manager_Force_Load_Queued_Mods_Proc,
	modmanager_get_mod_proctable:      Mod_Manager_Get_Mod_ProcTable_Proc,
	modmanager_get_modinfo:            Mod_Manager_Get_ModInfo_Proc,
	modmanager_get_modid_from_name:    Mod_Manager_Get_ModId_From_Name,
	modmanager_get_modid_from_path:    Mod_Manager_Get_ModId_From_Path,
	modmanager_get_modinfo_list:       Mod_Manager_Get_ModInfo_List_Proc,
}

