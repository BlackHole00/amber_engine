package ae_common

// The proc table is a table containing all of the procedures required for a mod
// to interface with the engine, which needs to implement correctly the 
// procedures.
// For more information about the mod's interfacing see 
// `ae_interface:AE_MOD_PROC_TABLE`
Proc_Table :: struct {
	get_version:                         Get_Version_Proc,
	get_config:                          Get_Config_Proc,
	get_userconfig:                      Get_UserConfig_Proc,
	storage_register_resource_type:      Storage_Register_Resource_Type_Proc,
	storage_add:                         Storage_Add_Proc,
	storage_get:                         Storage_Get_Proc,
	storage_remove:                      Storage_Remove_Proc,
	storage_get_resource_type_info:      Storage_Get_Resource_Type_Info_Proc,
	storage_get_resource_info:           Storage_Get_Resource_Info_Proc,
	modmanager_register_modloader:       Mod_Manager_Register_ModLoader_Proc,
	modmanager_remove_modloader:         Mod_Manager_Remove_ModLoader_Proc,
	modmanager_get_modloaderid:          Mod_Manager_Get_ModLoaderId_Proc,
	modmanager_get_modloaderid_for_file: Mod_Manager_Get_ModLoaderId_For_File_Proc,
	modmanager_is_modloaderid_valid:     Mod_Manager_Is_ModLoaderId_Valid,
	modmanager_can_load_file:            Mod_Manager_Can_Load_File_Proc,
	modmanager_queue_load_mod:           Mod_Manager_Queue_Load_Mod_Proc,
	modmanager_queue_load_folder:        Mod_Manager_Queue_Load_Folder_Proc,
	modmanager_queue_unload_mod:         Mod_Manager_Queue_Unload_Mod_Proc,
	modmanager_force_load_queued_mods:   Mod_Manager_Force_Load_Queued_Mods_Proc,
	modmanager_get_mod_proctable:        Mod_Manager_Get_Mod_ProcTable_Proc,
	modmanager_get_modinfo:              Mod_Manager_Get_ModInfo_Proc,
	modmanager_get_modid_from_name:      Mod_Manager_Get_ModId_From_Name_Proc,
	modmanager_get_modid_from_path:      Mod_Manager_Get_ModId_From_Path_Proc,
	modmanager_is_modid_valid:           Mod_Manager_Is_ModId_Valid_Proc,
	modmanager_get_mod_status:           Mod_Manager_Get_Mod_Status,
	modmanager_get_modinfo_list:         Mod_Manager_Get_ModInfo_List_Proc,
	// scheduler_add_task:                  Scheduler_Add_Task_Proc,
	// scheduler_remove_task:               Scheduler_Remove_Task_Proc,
	// scheduler_wait_for:                  Scheduler_Wait_For_Proc,
	// scheduler_sleep:                     Scheduler_Sleep_Proc,
	// scheduler_get_threadid:              Scheduler_Get_Thread_Id_Proc,
	// scheduler_get_taskinfo:              Scheduler_Get_Task_Info_Proc,
	// scheduler_get_taskinfo_list:         Scheduler_Get_Task_Info_Proc,
}

