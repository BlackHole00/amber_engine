package amber_engine_loader

import aec "shared:ae_common"
import "core:os"
import "core:log"
import "core:mem"
import "core:slice"

Mod_Id :: aec.Mod_Id
Mod_Info :: aec.Mod_Info
Mod_Loader_Id :: aec.Mod_Loader_Id
Mod_Loader :: aec.Mod_Loader
Mod_Load_Error :: aec.Mod_Load_Error

Mod_Manager :: struct {
	allocator:                 mem.Allocator,
	loader_allocator:          mem.Allocator,
	// used to generate mod_loader ids
	incremental_mod_loader_id: Mod_Loader_Id,
	incremental_mod_id:        Mod_Id,
	mod_loaders:               map[Mod_Loader_Id]Mod_Loader,
	mod_infos:                 map[Mod_Id]Mod_Info,
	// @index_of mod_infos
	mod_dependency_graph:      [dynamic]uint,
	loaded_mods:               [dynamic]Mod_Id,
	queued_mods_to_load:       [dynamic]Mod_Id,
	queued_mods_to_unload:     [dynamic]Mod_Id,
}


modmanager_init :: proc(
	mod_manager: ^Mod_Manager,
	loader_allocator: mem.Allocator,
	allocator := context.allocator,
) {
	context.allocator = allocator
	mod_manager.allocator = allocator
	mod_manager.loader_allocator = loader_allocator

	mod_manager.mod_loaders = make(map[Mod_Loader_Id]Mod_Loader)
	mod_manager.mod_infos = make(map[Mod_Id]Mod_Info)
	mod_manager.mod_dependency_graph = make([dynamic]uint)
	mod_manager.loaded_mods = make([dynamic]Mod_Id)
	mod_manager.queued_mods_to_load = make([dynamic]Mod_Id)
	mod_manager.queued_mods_to_unload = make([dynamic]Mod_Id)
}

modmanager_free :: proc(mod_manager: Mod_Manager) {
	context.allocator = mod_manager.allocator

	for mod_id in mod_manager.loaded_mods {
		modmanager_call_mod_deinit(mod_manager, mod_id)
	}
	for _, loader in mod_manager.mod_loaders {
		loader->on_deinit(mod_manager.loader_allocator)
	}

	delete(mod_manager.mod_loaders)
	delete(mod_manager.mod_infos)
	delete(mod_manager.mod_dependency_graph)
	delete(mod_manager.loaded_mods)
	delete(mod_manager.queued_mods_to_load)
	delete(mod_manager.queued_mods_to_unload)
}

modmanager_register_modloader :: proc(
	mod_manager: ^Mod_Manager,
	mod_loader: Mod_Loader,
) -> Mod_Loader_Id {
	context.allocator = mod_manager.allocator
	mod_loader := mod_loader

	mod_loader.identifier = modmanager_generate_modloaderid(mod_manager)

	log.debug(
		"Loading Mod_Loader ",
		mod_loader.identifier,
		" (",
		mod_loader.description,
		")...",
		sep = "",
	)
	switch mod_loader.on_init(mod_loader, mod_manager.loader_allocator) {
	case .Success:
		{
			log.info(
				"Successfully loaded Mod_Loader ",
				mod_loader.identifier,
				" (",
				mod_loader.description,
				")",
				sep = "",
			)
			mod_manager.mod_loaders[mod_loader.identifier] = mod_loader
		}
	case .Warning:
		{
			log.warn(
				"Loaded Mod_Loader ",
				mod_loader.identifier,
				" (",
				mod_loader.description,
				") with warning(s):",
				sep = "",
			)
			for message in mod_loader.get_last_message(mod_loader, mod_manager.loader_allocator) {
				log.warn("\t", message)
			}

			mod_manager.mod_loaders[mod_loader.identifier] = mod_loader
		}
	case .Error:
		{
			log.error(
				"Mod_Loader ",
				mod_loader.identifier,
				" (",
				mod_loader.description,
				"') failed initializing with error(s):",
				sep = "",
			)
			for message in mod_loader.get_last_message(mod_loader, mod_manager.loader_allocator) {
				log.error("\t", message)
			}

			log.debug("Deinitializing Mod_Loader", mod_loader.identifier)
			mod_loader.on_deinit(mod_loader, mod_manager.loader_allocator)
		}
	}

	return mod_loader.identifier
}

modmanager_remove_modloader :: proc(mod_manager: ^Mod_Manager, loader_id: Mod_Loader_Id) -> bool {
	context.allocator = mod_manager.allocator

	if loader_id not_in mod_manager.mod_loaders {
		log.warn("Could not delete Mod_Loader ", loader_id, ": Mod_Loader_Id not found", sep = "")

		return false
	}

	_, loader := delete_key(&mod_manager.mod_loaders, loader_id)
	log.debug("Deinitializing Mod_Loader", loader_id)
	loader.on_deinit(loader, mod_manager.loader_allocator)

	log.info("Removed Mod_Loader", loader_id)

	return true
}

modmanager_get_modloaderid :: proc(
	mod_manager: Mod_Manager,
	loader_name: string,
) -> Mod_Loader_Id {
	for id, mod_loader in mod_manager.mod_loaders {
		if mod_loader.name == loader_name {
			return id
		}
	}

	return aec.INVALID_MODLOADERID
}

modmanager_get_modloaderid_for_file :: proc(
	mod_manager: Mod_Manager,
	file_name: string,
) -> Mod_Loader_Id {
	for id, mod_loader in mod_manager.mod_loaders {
		if mod_loader.can_load_file(mod_loader, file_name, mod_manager.loader_allocator) {
			return id
		}
	}

	return aec.INVALID_MODLOADERID
}

modmanager_is_modloaderid_valid :: proc(
	mod_manager: Mod_Manager,
	loader_id: Mod_Loader_Id,
) -> bool {
	return loader_id in mod_manager.mod_loaders
}

modmanager_can_load_file :: proc(mod_manager: Mod_Manager, file_path: string) -> bool {
	for _, mod_loader in mod_manager.mod_loaders {
		if mod_loader.can_load_file(mod_loader, file_path, mod_manager.loader_allocator) {
			return true
		}
	}

	return false
}

modmanager_queue_load_mod :: proc(
	mod_manager: ^Mod_Manager,
	file_path: string,
) -> (
	Mod_Load_Error,
	Mod_Id,
) {
	context.allocator = mod_manager.allocator

	if !os.exists(file_path) {
		return .Invalid_Path, aec.INVALID_MODID
	}

	loader_id := modmanager_get_modloaderid_for_file(mod_manager^, file_path)
	if loader_id == aec.INVALID_MODLOADERID {
		return .Invalid_Mod, aec.INVALID_MODID
	}

	loader := mod_manager.mod_loaders[loader_id]
	info, error := loader->generate_mod_info(file_path, mod_manager.loader_allocator)
	info.identifier = modmanager_generate_modid(mod_manager)
	#partial switch error {
	case .Warning:
		{
			log.warn(
				"Obtained Mod_Info of mod ",
				info.identifier,
				" (",
				info.name,
				") with warning(s):",
				sep = "",
			)
			for message in loader->get_last_message(mod_manager.loader_allocator) {
				log.warn("\t", message)
			}
		}
	case .Error:
		{
			log.error(
				"Could not load Mod_Info of mod ",
				info.identifier,
				" (from file: ",
				file_path,
				") with error(s):",
				sep = "",
			)
			for message in loader->get_last_message(mod_manager.loader_allocator) {
				log.error("\t", message)
			}

			return .Invalid_Mod, aec.INVALID_MODID
		}
	}

	mod_manager.mod_infos[info.identifier] = info
	append(&mod_manager.queued_mods_to_load, info.identifier)

	return .Success, info.identifier
}

modmanager_queue_load_folder :: proc(
	mod_manager: ^Mod_Manager,
	folder_path: string,
) -> (
	success: bool,
) {
	context.allocator = mod_manager.allocator

	if !os.exists(folder_path) {
		return false
	}

	folder_handle, handle_ok := os.open(folder_path)
	if handle_ok != os.ERROR_NONE {
		return false
	}
	defer os.close(folder_handle)

	file_infos, infos_ok := os.read_dir(folder_handle, 0)
	if infos_ok != os.ERROR_NONE {
		return false
	}
	defer os.file_info_slice_delete(file_infos)

	success = true
	for file_info in file_infos {
		if mod_error, _ := modmanager_queue_load_mod(mod_manager, file_info.fullpath);
		   mod_error != .Success {
			success = false
		}
	}

	return
}

modmanager_queue_unload_mod :: proc(mod_manager: ^Mod_Manager, mod_id: Mod_Id) -> bool {
	context.allocator = mod_manager.allocator

	if _, found := slice.linear_search(mod_manager.queued_mods_to_unload[:], mod_id); found {
		return true
	}

	if idx, found := slice.linear_search(mod_manager.queued_mods_to_load[:], mod_id); found {
		unordered_remove(&mod_manager.queued_mods_to_load, idx)
		append(&mod_manager.queued_mods_to_unload, mod_id)
		return true
	}

	if _, found := slice.linear_search(mod_manager.loaded_mods[:], mod_id); found {
		append(&mod_manager.queued_mods_to_unload)
		return true
	}

	return false
}

modmanager_force_load_queued_mods :: proc(mod_manager: ^Mod_Manager) -> bool {
	modmanager_remove_queued_mods_to_unload(mod_manager)
	modmanager_add_queued_mods_to_load(mod_manager)

	return true
}

modmanager_get_mod_proctable :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> rawptr {
	mod_info, info_ok := mod_manager.mod_infos[mod_id]
	if !info_ok {
		return nil
	}

	return(
		mod_manager.mod_loaders[mod_info.loader]->get_mod_proctable(
			mod_info,
			mod_manager.loader_allocator,
		) \
	)
}

modmanager_get_modinfo :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> (Mod_Info, bool) {
	return mod_manager.mod_infos[mod_id]
}

modmanager_get_modid_from_name :: proc(mod_manager: Mod_Manager, name: string) -> Mod_Id {
	for _, info in mod_manager.mod_infos {
		if info.name == name {
			return info.identifier
		}
	}

	return aec.INVALID_MODID
}

modmanager_get_modid_from_path :: proc(mod_manager: Mod_Manager, path: string) -> Mod_Id {
	unimplemented()
}

modmanager_is_modid_valid :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> bool {
	return mod_id in mod_manager.mod_infos
}

modmanager_is_modid_loaded :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> bool {
	info, info_ok := mod_manager.mod_infos[mod_id]
	if !info_ok {
		return false
	}

	return info.fully_loaded
}

modmanager_get_modinfo_list :: proc(
	mod_manager: Mod_Manager,
	allocator: mem.Allocator,
) -> []Mod_Info {
	context.allocator = allocator

	infos := make([]Mod_Info, len(mod_manager.mod_infos))
	i := 0
	for _, info in mod_manager.mod_infos {
		infos[i] = info
		i += 1
	}

	return infos
}

@(private)
modmanager_generate_modloaderid :: proc(mod_manager: ^Mod_Manager) -> Mod_Loader_Id {
	defer mod_manager.incremental_mod_loader_id += 1

	return mod_manager.incremental_mod_loader_id
}

@(private)
modmanager_generate_modid :: proc(mod_manager: ^Mod_Manager) -> Mod_Id {
	defer mod_manager.incremental_mod_id += 1

	return mod_manager.incremental_mod_id
}

@(private)
modmanager_remove_queued_mods_to_unload :: proc(mod_manager: ^Mod_Manager) {
	context.allocator = mod_manager.allocator

	for mod_id in mod_manager.queued_mods_to_unload {
		#partial switch modmanager_call_mod_deinit(mod_manager^, mod_id) {
		case:
			{
				unimplemented("TODO: Do logging messages")
			}
		}
		delete_key(&mod_manager.mod_infos, mod_id)
	}

	resize(&mod_manager.queued_mods_to_unload, 0)
}

@(private)
modmanager_add_queued_mods_to_load :: proc(mod_manager: ^Mod_Manager) {
	context.allocator = mod_manager.allocator

	for mod_id in mod_manager.queued_mods_to_load {
		append(&mod_manager.loaded_mods, mod_id)
	}
	resize(&mod_manager.queued_mods_to_load, 0)

	modmanager_create_mod_dependency_graph(mod_manager)

	for mod_id_idx in mod_manager.mod_dependency_graph {
		mod_id := mod_manager.loaded_mods[mod_id_idx]
		mod_info := mod_manager.mod_infos[mod_id]

		if mod_info.fully_loaded {
			continue
		}

		#partial switch modmanager_call_mod_init(mod_manager^, mod_id) {
		case:
			{
				unimplemented("Handle mod init failure")
			}
		}
	}
}

@(private)
modmanager_create_mod_dependency_graph :: proc(mod_manager: ^Mod_Manager) {
	unimplemented()
}

@(private)
modmanager_get_modloader_ptr :: #force_inline proc(
	mod_manager: Mod_Manager,
	mod_loader_id: Mod_Loader_Id,
) -> ^Mod_Loader {
	return &mod_manager.mod_loaders[mod_loader_id]
}

@(private)
modmanager_get_modloader_from_mod_id :: #force_inline proc(
	mod_manager: Mod_Manager,
	mod_id: Mod_Id,
) -> ^Mod_Loader {
	return &mod_manager.mod_loaders[mod_manager.mod_infos[mod_id].loader]
}

@(private)
modmanager_call_mod_init :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> Mod_Load_Error {
	return(
		modmanager_get_modloader_from_mod_id(mod_manager, mod_id)->load_mod(
			mod_manager.mod_infos[mod_id],
			mod_manager.loader_allocator,
		) \
	)
}

@(private)
modmanager_call_mod_deinit :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> Mod_Load_Error {
	return(
		modmanager_get_modloader_from_mod_id(mod_manager, mod_id)->unload_mod(
			mod_manager.mod_infos[mod_id],
			mod_manager.loader_allocator,
		) \
	)
}

