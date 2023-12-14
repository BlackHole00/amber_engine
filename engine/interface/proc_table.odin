package amber_engine_interface

import "engine:config"
import aec "shared:ae_common"

proctable_init :: proc(table: ^aec.Proc_Table) {
	table.get_version = config.get_version
	table.get_config = get_config
	table.get_userconfig = get_userconfig

	table.modmanager_register_modloader = modmanager_register_modloader
	table.modmanager_remove_modloader = modmanager_remove_modloader
	table.modmanager_get_modloaderid = modmanager_get_modloaderid
	table.modmanager_get_modloaderid_for_file = modmanager_get_modloaderid_for_file
	table.modmanager_is_modloaderid_valid = modmanager_is_modloaderid_valid
	table.modmanager_can_load_file = modmanager_can_load_file
	table.modmanager_queue_load_mod = modmanager_queue_load_mod
	table.modmanager_queue_load_folder = modmanager_queue_load_folder
	table.modmanager_queue_unload_mod = modmanager_queue_unload_mod
	table.modmanager_force_load_queued_mods = modmanager_force_load_queued_mods
	table.modmanager_get_mod_proctable = modmanager_get_mod_proctable
	table.modmanager_get_modinfo = modmanager_get_modinfo
	table.modmanager_get_modid_from_name = modmanager_get_modid_from_name
	table.modmanager_get_modid_from_path = modmanager_get_modid_from_path
	table.modmanager_is_modid_valid = modmanager_is_modid_valid
	table.modmanager_is_modid_loaded = modmanager_is_modid_loaded
	table.modmanager_get_modinfo_list = modmanager_get_modinfo_list
}

