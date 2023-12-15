package amber_engine_loader

import aec "shared:ae_common"
import "core:os"
import "core:log"
import "core:mem"
import "core:slice"
import ts "core:container/topological_sort"

Mod_Id :: aec.Mod_Id
Mod_Info :: aec.Mod_Info
Mod_Loader_Id :: aec.Mod_Loader_Id
Mod_Loader :: aec.Mod_Loader
Mod_Loader_Result :: aec.Mod_Loader_Result
Mod_Load_Error :: aec.Mod_Load_Error

// In reference to `ae_interface:Mod_Manager` and `ae_common/mod_manager.odin`
Mod_Manager :: struct {
	allocator:                 mem.Allocator,
	loader_allocator:          mem.Allocator,
	loader_temp_allocator:     mem.Allocator,
	engine_proctable:          ^aec.Proc_Table,
	// used to generate mod_loader ids
	incremental_mod_loader_id: Mod_Loader_Id,
	incremental_mod_id:        Mod_Id,
	mod_loaders:               map[Mod_Loader_Id]Mod_Loader,
	mod_infos:                 map[Mod_Id]Mod_Info,
	mod_dependency_graph:      [dynamic]Mod_Id,
	queued_mods_to_load:       [dynamic]Mod_Id,
	queued_mods_to_unload:     [dynamic]Mod_Id,
}


modmanager_init :: proc(
	mod_manager: ^Mod_Manager,
	engine_proctable: ^aec.Proc_Table,
	loader_allocator: mem.Allocator,
	loader_temp_allocator: mem.Allocator,
	allocator := context.allocator,
) {
	context.allocator = allocator
	mod_manager.allocator = allocator
	mod_manager.loader_allocator = loader_allocator
	mod_manager.loader_temp_allocator = loader_temp_allocator
	mod_manager.engine_proctable = engine_proctable

	log.debug("Initializing Mod_Manager")

	mod_manager.mod_loaders = make(map[Mod_Loader_Id]Mod_Loader)
	mod_manager.mod_infos = make(map[Mod_Id]Mod_Info)
	mod_manager.mod_dependency_graph = make([dynamic]Mod_Id)
	mod_manager.queued_mods_to_load = make([dynamic]Mod_Id)
	mod_manager.queued_mods_to_unload = make([dynamic]Mod_Id)
}

modmanager_free :: proc(mod_manager: Mod_Manager) {
	context.allocator = mod_manager.allocator
	log.debug("Freeing Mod_Manager")

	for mod_id, mod_info in mod_manager.mod_infos {
		if mod_info.fully_loaded {
			modmanager_call_mod_deinit(mod_manager, mod_id)
		}
		(&mod_manager.mod_loaders[mod_info.loader])->free_mod_info(mod_info)
	}
	for _, &loader in mod_manager.mod_loaders {
		log.debug("Unloading Mod_Loader ", loader.identifier, " (", loader.description, ")...")
		loader->on_deinit()
	}

	delete(mod_manager.mod_loaders)
	delete(mod_manager.mod_infos)
	delete(mod_manager.mod_dependency_graph)
	delete(mod_manager.queued_mods_to_load)
	delete(mod_manager.queued_mods_to_unload)
}

modmanager_register_modloader :: proc(
	mod_manager: ^Mod_Manager,
	mod_loader: Mod_Loader,
) -> Mod_Loader_Id {
	context.allocator = mod_manager.allocator
	mod_loader := mod_loader

	log.info(
		"Registering Mod_Loader ",
		mod_loader.name,
		" (",
		mod_loader.description,
		")...",
		sep = "",
	)

	if modmanager_get_modloaderid(mod_manager^, mod_loader.name) != aec.INVALID_MODLOADERID {
		log.warn(
			"Could not register Mod_Loader ",
			mod_loader.name,
			" (",
			mod_loader.description,
			") could not be loaded: There is another Mod_Loader with the same name",
			sep = "",
		)
		return aec.INVALID_MODLOADERID
	}

	mod_loader.identifier = modmanager_generate_modloaderid(mod_manager)


	log.debug(
		"Initializing Mod_Loader ",
		mod_loader.identifier,
		" (",
		mod_loader.name,
		" - ",
		mod_loader.description,
		")...",
		sep = "",
	)
	switch mod_loader.on_init(
		&mod_loader,
		mod_manager.engine_proctable,
		mod_manager.loader_allocator,
		mod_manager.loader_temp_allocator,
	) {
	case .Success:
		log.debug(
			"Successfully initialized Mod_Loader ",
			mod_loader.identifier,
			" (",
			mod_loader.name,
			" - ",
			mod_loader.description,
			")",
			sep = "",
		)
		mod_manager.mod_loaders[mod_loader.identifier] = mod_loader

	case .Warning:
		log.warn(
			"Initialized Mod_Loader ",
			mod_loader.identifier,
			" (",
			mod_loader.name,
			" - ",
			mod_loader.description,
			") with warning(s)",
			sep = "",
		)
		mod_manager.mod_loaders[mod_loader.identifier] = mod_loader

	case .Error:
		log.error(
			"Mod_Loader ",
			mod_loader.identifier,
			" (",
			mod_loader.name,
			" - ",
			mod_loader.description,
			"') failed initializing with error(s)",
			sep = "",
		)

		log.debug("Deinitializing Mod_Loader", mod_loader.identifier)
		mod_loader.on_deinit(&mod_loader)

		return aec.INVALID_MODLOADERID
	}

	log.info(
		"Successfully registered Mod_Loader ",
		mod_loader.identifier,
		" (",
		mod_loader.name,
		" - ",
		mod_loader.description,
		")",
		sep = "",
	)

	return mod_loader.identifier
}

modmanager_remove_modloader :: proc(mod_manager: ^Mod_Manager, loader_id: Mod_Loader_Id) -> bool {
	context.allocator = mod_manager.allocator

	if loader_id not_in mod_manager.mod_loaders {
		log.warn("Could not delete Mod_Loader ", loader_id, ": Mod_Loader_Id not found", sep = "")

		return false
	}

	log.debug("Removing Mod_Loader", loader_id)

	log.debug("Unitializing mods related to Mod_Loader", loader_id)
	for _, info in mod_manager.mod_infos {
		if info.loader == loader_id {
			modmanager_queue_unload_mod(mod_manager, info.identifier)
		}
	}
	modmanager_force_load_queued_mods(mod_manager)

	_, loader := delete_key(&mod_manager.mod_loaders, loader_id)
	log.debug("Deinitializing Mod_Loader", loader_id)
	loader.on_deinit(&loader)

	log.info("Successfully removed Mod_Loader", loader_id)

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
	for id, &mod_loader in mod_manager.mod_loaders {
		if mod_loader.can_load_file(&mod_loader, file_name) {
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
	for _, &mod_loader in mod_manager.mod_loaders {
		if mod_loader.can_load_file(&mod_loader, file_path) {
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

	log.info("Queueing up loading of mod ", file_path, "...", sep = "")

	if modmanager_get_modid_from_path(mod_manager^, file_path) != aec.INVALID_MODID {
		log.warn(
			"Could not queue loading of mod ",
			file_path,
			": another mod with the same path has been already registered",
			sep = "",
		)

		return .Duplicate_Mod, aec.INVALID_MODID
	}
	if !os.exists(file_path) {
		log.warn(
			"Could not queue loading of mod ",
			file_path,
			": The provided file path does not exist",
			sep = "",
		)

		return .Invalid_Path, aec.INVALID_MODID
	}

	loader_id := modmanager_get_modloaderid_for_file(mod_manager^, file_path)
	if loader_id == aec.INVALID_MODLOADERID {
		log.warn(
			"Could not queue loading of mod ",
			file_path,
			": There is not a valid Mod_Loader for the provided mod file",
			sep = "",
		)

		return .Invalid_Mod, aec.INVALID_MODID
	}

	log.debug("Queuing loading of", file_path)

	log.debug("Obtaining Mod_Info for mod", file_path)
	loader := mod_manager.mod_loaders[loader_id]
	mod_id := modmanager_generate_modid(mod_manager)
	info, error := loader->generate_mod_info(file_path, mod_id)
	switch error {
	case .Success:
		{
			log.debug(
				"Successfully obtained Mod_Info of mod ",
				info.identifier,
				" (",
				info.name,
				")",
				sep = "",
			)
		}
	case .Warning:
		{
			log.warn(
				"Obtained Mod_Info of mod ",
				info.identifier,
				" (",
				info.name,
				") with warning(s)",
				sep = "",
			)
		}
	case .Error:
		{
			log.error(
				"Could not queue loading of mod ",
				info.identifier,
				" (from file: ",
				file_path,
				"): Could not obtain Mod_Info of mod with error(s)",
				sep = "",
			)

			return .Invalid_Mod, aec.INVALID_MODID
		}
	}

	if info.identifier != mod_id {
		log.error(
			"The Mod_Loader ",
			loader.identifier,
			" (",
			loader.name,
			" - ",
			loader.description,
			") returned a Mod_Info with an identifier different from the provided Mod_Id. It will be fixed by the Mod_Manager",
			sep = "",
		)
		info.identifier = mod_id
	}

	if modmanager_get_modid_from_name(mod_manager^, info.name) != aec.INVALID_MODID {
		log.warn(
			"Could not queue loading of mod ",
			info.identifier,
			" (",
			info.name,
			"): another mod with the same name has already been registered",
			sep = "",
		)

		return .Duplicate_Mod, aec.INVALID_MODID
	}

	mod_manager.mod_infos[info.identifier] = info
	append(&mod_manager.queued_mods_to_load, info.identifier)

	log.info(
		"Successfully queued loading of mod ",
		info.identifier,
		" (",
		info.name,
		")",
		sep = "",
	)

	return .Success, info.identifier
}

modmanager_queue_load_folder :: proc(
	mod_manager: ^Mod_Manager,
	folder_path: string,
) -> (
	success: bool,
) {
	context.allocator = mod_manager.allocator

	log.info("Queuing up loading of mod folder ", folder_path, "...", sep = "")

	if !os.exists(folder_path) {
		log.warn(
			"Could not queue loading of mod folder ",
			folder_path,
			": The provided path does not exist",
			sep = "",
		)
		return false
	}

	if !os.is_dir(folder_path) {
		log.warn(
			"Could not queue loading of mod folder ",
			folder_path,
			": The provided path is not a folder",
			sep = "",
		)
	}

	folder_handle, handle_ok := os.open(folder_path)
	if handle_ok != os.ERROR_NONE {
		log.warn(
			"Could not queue loading of mod folder ",
			folder_path,
			": Could not open the folder",
			sep = "",
		)
		return false
	}
	defer os.close(folder_handle)

	file_infos, infos_ok := os.read_dir(folder_handle, 0)
	if infos_ok != os.ERROR_NONE {
		log.warn(
			"Could not queue loading of mod folder ",
			folder_path,
			": Could not obtain file infos",
			sep = "",
		)
		return false
	}
	defer os.file_info_slice_delete(file_infos)

	success = true
	for file_info in file_infos {
		if !modmanager_can_load_file(mod_manager^, file_info.fullpath) {
			log.warn(
				"Skipping file",
				file_info.fullpath,
				": There is not a valid Mod_Loader for the provided mod file",
			)

			success = false
			continue
		}

		if mod_error, _ := modmanager_queue_load_mod(mod_manager, file_info.fullpath);
		   mod_error != .Success {
			success = false
		}
	}

	if success {
		log.info("Successfully queued loading of mod folder", folder_path)
	} else {
		log.warn("Queued loading of mod folder", folder_path, "with errors")
	}

	return
}

modmanager_queue_unload_mod :: proc(mod_manager: ^Mod_Manager, mod_id: Mod_Id) -> (ok: bool) {
	context.allocator = mod_manager.allocator
	defer if ok {
		log.info("Successfully queued unloading of mod", mod_id)
	}

	if _, found := slice.linear_search(mod_manager.queued_mods_to_unload[:], mod_id); found {
		log.warn("The mod", mod_id, "is already sheduled for unloading")

		return true
	}

	if idx, found := slice.linear_search(mod_manager.queued_mods_to_load[:], mod_id); found {
		unordered_remove(&mod_manager.queued_mods_to_load, idx)
		append(&mod_manager.queued_mods_to_unload, mod_id)
		return true
	}

	if _, found := slice.linear_search(mod_manager.mod_dependency_graph[:], mod_id); found {
		append(&mod_manager.queued_mods_to_unload)
		return true
	}

	log.warn(
		"Could not queue unloading of mod ",
		mod_id,
		": The provided Mod_Id does not seem to be valid",
		sep = "",
	)
	return false
}

modmanager_force_load_queued_mods :: proc(mod_manager: ^Mod_Manager) -> bool {
	log.info("Loading and unloading queued up mod changes...")

	modmanager_remove_queued_mods_to_unload(mod_manager)
	modmanager_add_queued_mods_to_load(mod_manager)

	return true
}

modmanager_get_mod_proctable :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> rawptr {
	mod_info, info_ok := mod_manager.mod_infos[mod_id]
	if !info_ok {
		log.warn(
			"Could not obtain proc table of mod ",
			mod_id,
			": The provided Mod_Id does not seem to be valid",
			sep = "",
		)

		return nil
	}

	return (&mod_manager.mod_loaders[mod_info.loader])->get_mod_proctable(mod_info)
}

modmanager_get_modinfo :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> (Mod_Info, bool) {
	mod_info, info_ok := mod_manager.mod_infos[mod_id]
	if !info_ok {
		log.warn(
			"Could not obtain Mod_Info of mod ",
			mod_id,
			": The provided Mod_Id does not seem to be valid",
			sep = "",
		)

		return {}, false
	}

	return mod_info, true
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
	for _, info in mod_manager.mod_infos {
		if info.file_path == path {
			return info.identifier
		}
	}

	return aec.INVALID_MODID
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
		modmanager_call_mod_deinit(mod_manager^, mod_id)
		modmanager_free_mod_info(mod_manager, mod_id)
	}

	resize(&mod_manager.queued_mods_to_unload, 0)
}

@(private)
modmanager_add_queued_mods_to_load :: proc(mod_manager: ^Mod_Manager) {
	context.allocator = mod_manager.allocator


	resize(&mod_manager.queued_mods_to_load, 0)

	modmanager_create_mod_dependency_graph(mod_manager)

	for mod_id in mod_manager.mod_dependency_graph {
		mod_info := mod_manager.mod_infos[mod_id]

		if mod_info.fully_loaded {
			continue
		}

		modmanager_call_mod_init(mod_manager, mod_id)
	}
}

@(private)
modmanager_create_mod_dependency_graph :: proc(mod_manager: ^Mod_Manager) {
	context.allocator = mod_manager.allocator
	log.debug("Creating dependency graph")

	delete(mod_manager.mod_dependency_graph)

	sorter: ts.Sorter(Mod_Id) = ---
	ts.init(&sorter)
	defer ts.destroy(&sorter)

	for _, mod_info in mod_manager.mod_infos {
		ts.add_key(&sorter, mod_info.identifier)
	}
	for _, mod_info in mod_manager.mod_infos {
		for dependency in mod_info.dependencies {
			dependency_id := modmanager_get_modid_from_name(mod_manager^, dependency)
			if dependency_id == aec.INVALID_MODID {
				continue
			}

			ts.add_dependency(&sorter, mod_info.identifier, dependency_id)
		}

		for dependant in mod_info.dependants {
			dependant_id := modmanager_get_modid_from_name(mod_manager^, dependant)
			if dependant_id == aec.INVALID_MODID {
				continue
			}

			ts.add_dependency(&sorter, dependant_id, mod_info.identifier)
		}
	}

	sorted, cycled := ts.sort(&sorter)
	delete(cycled)

	log.debug("Successfully created mod dependency graph:")
	for mod_id in sorted {
		mod_info := mod_manager.mod_infos[mod_id]

		log.debug(
			"\t",
			mod_id,
			" - ",
			mod_info.name,
			" (dependences: ",
			mod_info.dependencies,
			"), (dependats: ",
			mod_info.dependants,
			")",
			sep = "",
		)
	}

	mod_manager.mod_dependency_graph = sorted
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
modmanager_call_mod_init :: proc(
	mod_manager: ^Mod_Manager,
	mod_id: Mod_Id,
) -> (
	err: Mod_Load_Error,
) {
	info := mod_manager.mod_infos[mod_id]
	log.info("Loading mod ", info.identifier, " (", info.name, ")...", sep = "")

	err =
	modmanager_get_modloader_from_mod_id(mod_manager^, mod_id)->load_mod(
		mod_manager.mod_infos[mod_id],
	)

	if err == .Success {
		log.info("Mod ", info.identifier, " (", info.name, ") successfully loaded")
	} else {
		log.warn(
			"Mod ",
			info.identifier,
			" (",
			info.name,
			") failed loading with error ",
			err,
			sep = "",
		)
	}

	info.fully_loaded = true
	mod_manager.mod_infos[mod_id] = info

	return
}

@(private)
modmanager_call_mod_deinit :: proc(
	mod_manager: Mod_Manager,
	mod_id: Mod_Id,
) -> (
	err: Mod_Load_Error,
) {
	info := mod_manager.mod_infos[mod_id]
	log.info("Unloading mod ", info.identifier, " (", info.name, ")...", sep = "")

	err =
	modmanager_get_modloader_from_mod_id(mod_manager, mod_id)->unload_mod(
		mod_manager.mod_infos[mod_id],
	)

	if err == .Success {
		log.info("Mod ", info.identifier, " (", info.name, ") successfully unloaded", sep = "")
	} else {
		log.warn(
			"Mod ",
			info.identifier,
			" (",
			info.name,
			") failed unloading with error ",
			err,
			sep = "",
		)
	}

	return
}

@(private)
modmanager_free_mod_info :: proc(mod_manager: ^Mod_Manager, mod_id: Mod_Id) {
	if mod_info, ok := mod_manager.mod_infos[mod_id]; !ok {
		return
	} else {
		(&mod_manager.mod_loaders[mod_info.loader])->free_mod_info(mod_info)
		delete_key(&mod_manager.mod_infos, mod_id)
	}
}

