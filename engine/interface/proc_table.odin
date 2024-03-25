package amber_engine_interface

import "core:log"
import "engine:config"
import "engine:namespace_manager"
import ae "shared:amber_engine/common"

proctable_init :: proc(table: ^ae.Proc_Table) {
	log.debugf("Initializing Proc_Table")

	table.get_version = config.get_version
	table.get_config = get_config
	table.get_userconfig = get_userconfig

	table.namespacemanager_register_namespace = namespace_manager.register_namespace
	table.namespacemanager_register_namespace_alias = namespace_manager.register_namespace_alias
	table.namespacemanager_is_namespace_valid = namespace_manager.is_namespace_valid
	table.namespacemanager_get_namespace_names = namespace_manager.get_namespace_names
	table.namespacemanager_get_first_namespace_name = namespace_manager.get_first_namespace_name
	table.namespacemanager_find_namespace = namespace_manager.find_namespace

	table.storage_register_resource_type = storage_register_resource_type
	table.storage_is_resource_type_valid = storage_is_resource_type_valid
	table.storage_add_resource = storage_add_resource
	table.storage_get_resource = storage_get_resource
	table.storage_set_resource = storage_set_resource
	table.storage_remove_resource = storage_remove_resource
	table.storage_is_resource_valid = storage_is_resource_valid
	table.storage_get_resource_type_info = storage_get_resource_type_info
	table.storage_get_resource_info = storage_get_resource_info
	table.storage_get_registered_types_info_list = storage_get_registered_types_info_list

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
	table.modmanager_get_mod_status = modmanager_get_mod_status
	table.modmanager_get_modinfo_list = modmanager_get_modinfo_list
}

