package amber_engine_loader

import ts "core:container/topological_sort"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import ae "shared:amber_engine/common"

Mod_Id :: ae.Mod_Id
Mod_Info :: ae.Mod_Info
Mod_Loader_Id :: ae.Mod_Loader_Id
Mod_Loader :: ae.Mod_Loader
Mod_Loader_Result :: ae.Mod_Loader_Result
Mod_Load_Error :: ae.Mod_Load_Error
Mod_Relation :: ae.Mod_Relation
Mod_Status :: ae.Mod_Status

// In reference to `ae_interface:Mod_Manager` and `ae_common/mod_manager.odin`
Mod_Manager :: struct {
	allocator:                 mem.Allocator,
	loader_allocator:          mem.Allocator,
	loader_temp_allocator:     mem.Allocator,
	mod_context:               runtime.Context,
	engine_proctable:          ^ae.Proc_Table,
	// used to generate mod_loader ids
	incremental_mod_loader_id: Mod_Loader_Id,
	incremental_mod_id:        Mod_Id,
	mod_loaders:               map[Mod_Loader_Id]Mod_Loader,
	mod_infos:                 map[Mod_Id]Mod_Info,
	mod_order:                 [dynamic]Mod_Id,
}


modmanager_init :: proc(
	mod_manager: ^Mod_Manager,
	engine_proctable: ^ae.Proc_Table,
	loader_allocator: mem.Allocator,
	loader_temp_allocator: mem.Allocator,
	mod_context: runtime.Context,
	allocator := context.allocator,
) {
	context.allocator = allocator
	mod_manager.allocator = allocator
	mod_manager.loader_allocator = loader_allocator
	mod_manager.loader_temp_allocator = loader_temp_allocator
	mod_manager.engine_proctable = engine_proctable
	mod_manager.mod_context = mod_context

	log.debug("Initializing Mod_Manager")

	mod_manager.mod_loaders = make(map[Mod_Loader_Id]Mod_Loader)
	mod_manager.mod_infos = make(map[Mod_Id]Mod_Info)
	mod_manager.mod_order = make([dynamic]Mod_Id)
}

modmanager_free :: proc(mod_manager: ^Mod_Manager) {
	context.allocator = mod_manager.allocator
	log.debug("Freeing Mod_Manager")

	for loader_id, _ in mod_manager.mod_loaders {
		modmanager_remove_modloader(mod_manager, loader_id)
	}

	delete(mod_manager.mod_loaders)
	delete(mod_manager.mod_infos)
	delete(mod_manager.mod_order)
}

modmanager_register_modloader :: proc(
	mod_manager: ^Mod_Manager,
	mod_loader: Mod_Loader,
) -> Mod_Loader_Id {
	context.allocator = mod_manager.allocator
	mod_loader := mod_loader

	log.infof("Registering Mod_Loader %s (%s)...", mod_loader.name, mod_loader.description)

	if modmanager_get_modloaderid(mod_manager^, mod_loader.name) != ae.INVALID_MODLOADERID {
		log.warnf(
			"Could not register Mod_Loader %s (%s) There is another Mod_Loader with the same name",
			mod_loader.name,
			mod_loader.description,
		)
		return ae.INVALID_MODLOADERID
	}

	mod_loader_id := modmanager_generate_modloaderid(mod_manager)

	log.debugf("Initializing Mod_Loader %s (%s)...", mod_loader.name, mod_loader.description)
	init_result := ae.modloader_init(
		&mod_loader,
		mod_loader_id,
		mod_manager.engine_proctable,
		mod_manager.loader_allocator,
		mod_manager.loader_temp_allocator,
		mod_manager.mod_context,
	)

	if init_result != .Error && mod_loader.identifier != mod_loader_id {
		log.warnf(
			"The Mod_Loader %s (%s) initialized with a different Mod_Loader_Id from the provided one. It will be fixed by the Mod_Manager",
			mod_loader.name,
			mod_loader.description,
		)
		mod_loader.identifier = mod_loader_id
	}

	switch init_result {
	case .Success:
		log.debugf(
			"Successfully initialized Mod_Loader %d (%s - %s)",
			mod_loader.identifier,
			mod_loader.name,
			mod_loader.description,
		)
		mod_manager.mod_loaders[mod_loader.identifier] = mod_loader

	case .Warning:
		log.warnf(
			"Initialized Mod_Loader %d (%s - %s) with warning(s)",
			mod_loader.identifier,
			mod_loader.name,
			mod_loader.description,
		)
		mod_manager.mod_loaders[mod_loader.identifier] = mod_loader

	case .Error:
		log.errorf(
			"Mod_Loader %s (%s) failed initializing with error(s)",
			mod_loader.name,
			mod_loader.description,
		)

		log.debugf("Deinitializing Mod_Loader %s (%s)", mod_loader.name, mod_loader.description)
		ae.modloader_deinit(&mod_loader)

		return ae.INVALID_MODLOADERID
	}

	log.infof(
		"Successfully registered Mod_Loader %d (%s - %s)",
		mod_loader.identifier,
		mod_loader.name,
		mod_loader.description,
	)

	return mod_loader.identifier
}

modmanager_remove_modloader :: proc(mod_manager: ^Mod_Manager, loader_id: Mod_Loader_Id) -> bool {
	context.allocator = mod_manager.allocator

	if loader_id not_in mod_manager.mod_loaders {
		log.warnf("Could not delete Mod_Loader %d: Mod_Loader_Id not found", loader_id)

		return false
	}

	log.debugf("Removing Mod_Loader %d", loader_id)

	log.debugf("Unitializing mods related to Mod_Loader %d", loader_id)
	for _, info in mod_manager.mod_infos {
		if info.loader == loader_id {
			modmanager_queue_unload_mod(mod_manager, info.identifier)
		}
	}
	modmanager_force_load_queued_mods(mod_manager)

	_, loader := delete_key(&mod_manager.mod_loaders, loader_id)
	log.debugf("Deinitializing Mod_Loader %d", loader_id)
	ae.modloader_deinit(&loader)

	log.infof("Successfully removed Mod_Loader %d", loader_id)

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

	return ae.INVALID_MODLOADERID
}

modmanager_get_modloaderid_for_file :: proc(
	mod_manager: ^Mod_Manager,
	file_name: string,
) -> Mod_Loader_Id {
	for id, &mod_loader in mod_manager.mod_loaders {
		if ae.modloader_can_load_file(&mod_loader, file_name) {
			return id
		}
	}

	return ae.INVALID_MODLOADERID
}

modmanager_is_modloaderid_valid :: proc(
	mod_manager: Mod_Manager,
	loader_id: Mod_Loader_Id,
) -> bool {
	return loader_id in mod_manager.mod_loaders
}

modmanager_can_load_file :: proc(mod_manager: ^Mod_Manager, file_path: string) -> bool {
	for _, &mod_loader in mod_manager.mod_loaders {
		if ae.modloader_can_load_file(&mod_loader, file_path) {
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

	log.infof("Queueing up loading of mod %s...", file_path)

	if modmanager_get_modid_from_path(mod_manager^, file_path) != ae.INVALID_MODID {
		log.warnf(
			"Could not queue loading of mod %s: another mod with the same path has been already registered",
			file_path,
		)

		return .Duplicate_Mod, ae.INVALID_MODID
	}
	if !os.exists(file_path) {
		log.warnf(
			"Could not queue loading of mod %s: The provided file path does not exist",
			file_path,
		)

		return .Invalid_Path, ae.INVALID_MODID
	}

	loader_id := modmanager_get_modloaderid_for_file(mod_manager, file_path)
	if loader_id == ae.INVALID_MODLOADERID {
		log.warnf(
			"Could not queue loading of mod %s: There is not a valid Mod_Loader for the provided mod file",
			file_path,
		)

		return .Invalid_Mod, ae.INVALID_MODID
	}

	log.debugf("Queuing loading of %s", file_path)

	log.debugf("Obtaining Mod_Info for mod %s", file_path)
	loader := modmanager_get_modloader(mod_manager, loader_id)
	mod_id := modmanager_generate_modid(mod_manager)
	info, error := ae.modloader_generate_mod_info(loader, file_path, mod_id)
	switch error {
	case .Success:
		log.debugf("Successfully obtained Mod_Info of mod %d (%s)", info.identifier, info.name)

	case .Warning:
		log.warnf("Obtained Mod_Info of mod %d (%s) with warning(s)", info.identifier, info.name)

	case .Error:
		log.errorf(
			"Could not queue loading of mod %d (from file %s): Could not obtain Mod_Info of mod with error(s)",
			info.identifier,
			file_path,
		)

		return .Invalid_Mod, ae.INVALID_MODID
	}

	if info.identifier != mod_id {
		log.warnf(
			"The Mod_Loader %d (%s - %s) returned a Mod_Info with an identifier different from the provided Mod_Id. It will be fixed by the Mod_Manager",
			loader.identifier,
			loader.name,
			loader.description,
		)
		info.identifier = mod_id
	}

	if modmanager_get_modid_from_name(mod_manager^, info.name) != ae.INVALID_MODID {
		log.warnf(
			"Could not queue loading of mod %d (%s): another mod with the same name has already been registered",
			info.identifier,
			info.name,
		)

		info.status = .Errored
		modmanager_remove_mod(mod_manager, info)
		return .Duplicate_Mod, ae.INVALID_MODID
	}

	info.status = .Queued_For_Loading
	mod_manager.mod_infos[info.identifier] = info

	log.infof("Successfully queued loading of mod %d (%s)", info.identifier, info.name)

	return .Success, info.identifier
}

modmanager_queue_load_folder :: proc(
	mod_manager: ^Mod_Manager,
	folder_path: string,
) -> (
	success: bool,
) {
	context.allocator = mod_manager.allocator

	log.infof("Queuing up loading of mod folder %s...", folder_path)

	if !os.exists(folder_path) {
		log.warnf(
			"Could not queue loading of mod folder %s: The provided path does not exist",
			folder_path,
		)
		return false
	}

	if !os.is_dir(folder_path) {
		log.warnf(
			"Could not queue loading of mod folder %s: The provided path is not a folder",
			folder_path,
		)
	}

	folder_handle, handle_ok := os.open(folder_path)
	if handle_ok != os.ERROR_NONE {
		log.warnf(
			"Could not queue loading of mod folder %s: Could not open the folder",
			folder_path,
		)
		return false
	}
	defer os.close(folder_handle)

	file_infos, infos_ok := os.read_dir(folder_handle, 0)
	if infos_ok != os.ERROR_NONE {
		log.warnf(
			"Could not queue loading of mod folder %s: Could not obtain file infos",
			folder_path,
		)
		return false
	}
	defer os.file_info_slice_delete(file_infos)

	success = true
	for file_info in file_infos {
		if !modmanager_can_load_file(mod_manager, file_info.fullpath) {
			log.warnf(
				"Skipping file %s: There is not a valid Mod_Loader for the provided mod file",
				file_info.fullpath,
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
		log.infof("Successfully queued loading of mod folder %s", folder_path)
	} else {
		log.warnf("Queued loading of mod folder %s with errors", folder_path)
	}

	return
}

modmanager_queue_unload_mod :: proc(mod_manager: ^Mod_Manager, mod_id: Mod_Id) -> (ok: bool) {
	context.allocator = mod_manager.allocator
	defer if ok {
		log.infof("Successfully queued unloading of mod %d", mod_id)
	}

	mod_info, mod_info_ok := &mod_manager.mod_infos[mod_id]
	if !mod_info_ok {
		log.errorf(
			"Could not queue unloading of mod %d: The provided Mod_Id does not seem to be valid",
			mod_id,
		)
		return false
	}

	if mod_info.status == .Queued_For_Unloading || mod_info.status == .Unloading {
		log.warnf("The mod %d is already sheduled for unloading", mod_id)
		return true
	}

	mod_info.status = .Queued_For_Unloading
	return true
}

modmanager_force_load_queued_mods :: proc(mod_manager: ^Mod_Manager) -> bool {
	log.infof("Loading and unloading queued up mod changes...")

	modmanager_remove_queued_mods_to_unload(mod_manager)
	modmanager_add_queued_mods_to_load(mod_manager)

	return true
}

modmanager_get_mod_proctable :: proc(mod_manager: ^Mod_Manager, mod_id: Mod_Id) -> rawptr {
	mod_info, info_ok := mod_manager.mod_infos[mod_id]
	if !info_ok {
		log.warnf(
			"Could not obtain proc table of mod %d: The provided Mod_Id does not seem to be valid",
			mod_id,
		)

		return nil
	}

	if mod_info.status != .Loaded {
		log.warnf(
			"Could not obtain proc table of mod %d: The provided mod is not fully loaded",
			mod_id,
		)

		return nil
	}

	mod_loader := modmanager_get_modloader(mod_manager, mod_id)
	return ae.modloader_get_mod_proctable(mod_loader, mod_info)
}

modmanager_get_modinfo :: proc(mod_manager: ^Mod_Manager, mod_id: Mod_Id) -> (Mod_Info, bool) {
	mod_info, info_ok := mod_manager.mod_infos[mod_id]
	if !info_ok {
		log.warnf(
			"Could not obtain Mod_Info of mod %d: The provided Mod_Id does not seem to be valid",
			mod_id,
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

	return ae.INVALID_MODID
}

modmanager_get_modid_from_path :: proc(mod_manager: Mod_Manager, path: string) -> Mod_Id {
	for _, info in mod_manager.mod_infos {
		if info.file_path == path {
			return info.identifier
		}
	}

	return ae.INVALID_MODID
}

modmanager_is_modid_valid :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> bool {
	return mod_id in mod_manager.mod_infos
}

modmanager_get_mod_status :: proc(mod_manager: Mod_Manager, mod_id: Mod_Id) -> Mod_Status {
	info, info_ok := mod_manager.mod_infos[mod_id]
	if !info_ok {
		return .Unknown
	}

	return info.status
}

modmanager_get_modinfo_list :: proc(
	mod_manager: ^Mod_Manager,
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

	for _, mod_info in mod_manager.mod_infos {
		if mod_info.status == .Queued_For_Unloading {
			modmanager_remove_mod(mod_manager, mod_info)
		}
	}
}

@(private)
modmanager_add_queued_mods_to_load :: proc(mod_manager: ^Mod_Manager) {
	context.allocator = mod_manager.allocator

	reload_loaded_mods_order(mod_manager)

	for mod_id in mod_manager.mod_order {
		mod_info := mod_manager.mod_infos[mod_id]

		if mod_info.status == .Loaded {
			continue
		}

		modmanager_call_mod_init(mod_manager, mod_id)
	}
}

//TODO(Vicix): Check also for mod version dependecies
@(private)
reload_loaded_mods_order :: proc(mod_manager: ^Mod_Manager) {
	context.allocator = mod_manager.allocator
	log.debugf("Creating dependency graph")

	delete(mod_manager.mod_order)

	sorter: ts.Sorter(Mod_Id) = ---
	ts.init(&sorter)
	defer ts.destroy(&sorter)

	for _, mod_info in mod_manager.mod_infos {
		ts.add_key(&sorter, mod_info.identifier)
	}
	for _, mod_info in mod_manager.mod_infos {
		for dependency in mod_info.dependencies {
			dependency_id := modmanager_get_modid_from_name(mod_manager^, dependency.name)
			if dependency_id == ae.INVALID_MODID {
				continue
			}

			ts.add_dependency(&sorter, mod_info.identifier, dependency_id)
		}

		for dependant in mod_info.dependants {
			dependant_id := modmanager_get_modid_from_name(mod_manager^, dependant.name)
			if dependant_id == ae.INVALID_MODID {
				continue
			}

			ts.add_dependency(&sorter, dependant_id, mod_info.identifier)
		}
	}

	sorted, cycled := ts.sort(&sorter)
	delete(cycled)

	log.debugf("Successfully created mod dependency graph:")
	for mod_id in sorted {
		mod_info := mod_manager.mod_infos[mod_id]

		log.debugf(
			"\t%d - %s (%v) (dependences: %v), (dependants: %v)",
			mod_id,
			mod_info.name,
			mod_info.version,
			mod_info.dependencies,
			mod_info.dependants,
		)
	}

	mod_manager.mod_order = sorted
}

@(private)
modmanager_get_modloader_from_mod_loader_id :: #force_inline proc(
	mod_manager: ^Mod_Manager,
	mod_loader_id: Mod_Loader_Id,
) -> ^Mod_Loader {
	return &mod_manager.mod_loaders[mod_loader_id]
}

@(private)
modmanager_get_modloader_from_mod_id :: #force_inline proc(
	mod_manager: ^Mod_Manager,
	mod_id: Mod_Id,
) -> ^Mod_Loader {
	return &mod_manager.mod_loaders[mod_manager.mod_infos[mod_id].loader]
}

@(private)
modmanager_get_modloader_from_mod_info :: #force_inline proc(
	mod_manager: ^Mod_Manager,
	mod_info: Mod_Info,
) -> ^Mod_Loader {
	return modmanager_get_modloader_from_mod_loader_id(mod_manager, mod_info.loader)
}

@(private)
modmanager_get_modloader :: proc {
	modmanager_get_modloader_from_mod_loader_id,
	modmanager_get_modloader_from_mod_id,
	modmanager_get_modloader_from_mod_info,
}

@(private)
modmanager_call_mod_init :: proc(
	mod_manager: ^Mod_Manager,
	mod_id: Mod_Id,
) -> (
	err: Mod_Load_Error,
) {
	info := &mod_manager.mod_infos[mod_id]
	log.infof("Loading mod %d (%s)...", info.identifier, info.name)
	info.status = .Loading

	load_res := ae.modloader_load_mod(
		modmanager_get_modloader(mod_manager, mod_id),
		mod_manager.mod_infos[mod_id],
	)

	switch load_res {
	case .Success:
		log.infof("Mod %d (%s) successfully loaded", info.identifier, info.name)
		err = .Success
	case .Warning:
		log.warnf("Mod %d (%s) loaded with warning(s)", info.identifier, info.name)
		err = .Success
	case .Error:
		log.errorf("Mod %d (%s) failed loading", info.identifier, info.name)
		modmanager_queue_unload_mod(mod_manager, mod_id)
		err = .Internal_Mod_Error
	}

	if err == .Success {
		info.status = .Loaded
	} else {
		info.status = .Errored
	}

	return
}

@(private)
modmanager_call_mod_deinit :: proc(
	mod_manager: ^Mod_Manager,
	mod_id: Mod_Id,
) -> (
	err: Mod_Load_Error,
) {
	info := &mod_manager.mod_infos[mod_id]
	log.infof("Unloading mod %d (%s)...", info.identifier, info.name)
	info.status = .Unloading

	unload_res := ae.modloader_unload_mod(modmanager_get_modloader(mod_manager, mod_id), info^)

	switch unload_res {
	case .Success:
		log.infof("Mod %d (%s) successfully unloaded", info.identifier, info.name)
		err = .Success
	case .Warning:
		log.warnf("Mod %d (%s) failed unloading with warning(s)", info.identifier, info.name)
		err = .Success
	case .Error:
		log.errorf("Mod %d (%s) failed unloading", info.identifier, info.name)
		err = .Internal_Mod_Error
	}

	return
}

@(private)
modmanager_remove_mod_by_modinfo :: proc(mod_manager: ^Mod_Manager, mod_info: Mod_Info) {
	context.allocator = mod_manager.allocator

	if mod_info.status == .Loaded || mod_info.status == .Queued_For_Unloading {
		modmanager_call_mod_deinit(mod_manager, mod_info.identifier)
	}

	modmanager_free_mod_info(mod_manager, mod_info)
}

@(private)
modmanager_remove_mod_by_modid :: proc(
	mod_manager: ^Mod_Manager,
	mod_id: Mod_Id,
	free_from_queued_to_unload := false,
) {
	context.allocator = mod_manager.allocator

	status := mod_manager.mod_infos[mod_id].status
	if status == .Loaded || status == .Queued_For_Unloading {
		modmanager_call_mod_deinit(mod_manager, mod_id)
	}

	modmanager_free_mod_info(mod_manager, mod_id)
}

@(private)
modmanager_remove_mod :: proc {
	modmanager_remove_mod_by_modinfo,
	modmanager_remove_mod_by_modid,
}

@(private)
modmanager_free_mod_info_by_value :: proc(mod_manager: ^Mod_Manager, mod_info: Mod_Info) {
	context.allocator = mod_manager.allocator

	ae.modloader_free_mod_info(&mod_manager.mod_loaders[mod_info.loader], mod_info)
	delete_key(&mod_manager.mod_infos, mod_info.identifier)
}

@(private)
modmanager_free_mod_info_by_modid :: proc(mod_manager: ^Mod_Manager, mod_id: Mod_Id) {
	context.allocator = mod_manager.allocator

	_, mod_info := delete_key(&mod_manager.mod_infos, mod_id)
	ae.modloader_free_mod_info(&mod_manager.mod_loaders[mod_info.loader], mod_info)
}

@(private)
modmanager_free_mod_info :: proc {
	modmanager_free_mod_info_by_modid,
	modmanager_free_mod_info_by_value,
}

