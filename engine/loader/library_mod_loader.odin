package amber_engine_loader

import "core:dynlib"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"
import ae "shared:amber_engine/common"
import "shared:amber_engine/utils"

librarymodloader_init :: proc(mod_loader: ^Mod_Loader) {
	mod_loader.itable = &LIBRARYMODLOADER_ITABLE
	mod_loader.name = ae.DEFAULT_LIBRARY_MODLOADER_NAME
	mod_loader.description = "Loads .dll, .so and .dylib files as shared libraries"
	mod_loader.version = ae.Version{0, 0, 1}
}

librarymodloader_free :: proc(mod_loader: Mod_Loader) {}

@(private)
LIBRARYMODLOADER_ITABLE := ae.Mod_Loader_Proc_Table {
	init              = librarymodloader_on_init,
	deinit            = librarymodloader_on_deinit,
	generate_mod_info = librarymodloader_generate_mod_info,
	free_mod_info     = librarymodloader_free_mod_info,
	can_load_file     = librarymodloader_can_load_file,
	load_mod          = librarymodloader_load_mod,
	unload_mod        = librarymodloader_unload_mod,
	get_mod_proctable = librarymodloader_get_mod_proctable,
}

@(private)
Library_Mod_Loader_Data :: struct {
	allocator:        mem.Allocator,
	temp_allocator:   mem.Allocator,
	engine_proctable: ^ae.Proc_Table,
	library_modules:  map[Mod_Id]Library_Module,
	mod_context:      runtime.Context,
}

@(private)
Library_Mod_Info_Data :: struct {
	library_handle: dynlib.Library,
}

@(private)
librarymodloader_on_init: ae.Mod_Loader_Init_Proc : proc(
	loader: ^Mod_Loader,
	mod_loader_id: Mod_Loader_Id,
	engine_proctable: ^ae.Proc_Table,
	allocator: mem.Allocator,
	temp_allocator: mem.Allocator,
	mod_context: runtime.Context,
) -> Mod_Loader_Result {
	data := new(Library_Mod_Loader_Data, allocator)
	data.allocator = allocator
	data.temp_allocator = temp_allocator
	data.engine_proctable = engine_proctable
	data.mod_context = mod_context
	data.library_modules = make(map[Mod_Id]Library_Module)

	loader.identifier = mod_loader_id
	loader.user_data = data

	return .Success
}

@(private)
librarymodloader_on_deinit: ae.Mod_Loader_Deinit_Proc : proc(loader: ^Mod_Loader) {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator

	delete(data.library_modules)
	free(data)
}

@(private)
librarymodloader_generate_mod_info: ae.Mod_Loader_Generate_Mod_Info_Proc : proc(
	loader: ^Mod_Loader,
	mod_path: string,
	mod_id: Mod_Id,
) -> (
	info: Mod_Info,
	result: Mod_Loader_Result,
) {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	log.debug("Generating mod info of mod ", mod_id, " (", mod_path, ")...", sep = "")

	if !librarymodloader_can_load_file(loader, mod_path) {
		log.errorf(
			"Could not generate Mod_Info of mod %d (%s): The provided path is not valid or loadable by this mod loader",
			mod_id,
			mod_path,
		)
		return {}, .Error
	}

	library_module: Library_Module = ---
	librarymodule_init(&library_module, mod_path)
	defer if result != .Success {
		librarymodule_free(&library_module)
	}

	if librarymodule_load_library(&library_module, data.engine_proctable, data.mod_context) !=
	   .Success {
		log.errorf(
			"Could not generate Mod_Info of mod %d (%s): Could not create load the related Library_Module. The mod might be broken",
			mod_id,
			mod_path,
		)

		result = .Error
		return
	}
	data.library_modules[mod_id] = library_module

	name := strings.clone(librarymodule_get_mod_name(library_module))
	dependencies := slice.clone(librarymodule_get_mod_dependencies(library_module))
	for &dependency in dependencies {
		dependency.name = strings.clone(dependency.name)
		if version, version_ok := dependency.version.(ae.Mod_Relation_Version_Requirement_Exactly);
		   version_ok {
			dependency.version = slice.clone(version)
		}
	}
	dependants := slice.clone(librarymodule_get_mod_dependants(library_module))
	for &dependant in dependants {
		dependant.name = strings.clone(dependant.name)
		if version, version_ok := dependant.version.(ae.Mod_Relation_Version_Requirement_Exactly);
		   version_ok {
			dependant.version = slice.clone(version)
		}
	}

	info = Mod_Info {
		identifier   = mod_id,
		name         = name,
		version      = librarymodule_get_version(library_module),
		dependencies = dependencies,
		dependants   = dependants,
		file_path    = strings.clone(mod_path),
	}

	return
}

@(private)
librarymodloader_free_mod_info: ae.Mod_Loader_Free_Mod_Info_Proc : proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	log.debugf("Unloading library %s", mod_info.file_path)
	librarymodule_unload_library(&data.library_modules[mod_info.identifier])
	librarymodule_free(&data.library_modules[mod_info.identifier])

	delete(mod_info.name)
	delete(mod_info.file_path)
	for dependency in mod_info.dependencies {
		delete(dependency.name)
		if version, version_ok := dependency.version.(ae.Mod_Relation_Version_Requirement_Exactly);
		   version_ok {
			delete(version)
		}
	}
	delete(mod_info.dependencies)
	for dependant in mod_info.dependants {
		delete(dependant.name)
		if version, version_ok := dependant.version.(ae.Mod_Relation_Version_Requirement_Exactly);
		   version_ok {
			delete(version)
		}
	}
	delete(mod_info.dependants)
}

@(private)
librarymodloader_can_load_file: ae.Mod_Loader_Can_Load_File_Proc : proc(
	loader: ^Mod_Loader,
	mod_path: string,
) -> bool {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	if !os.exists(mod_path) || os.is_dir(mod_path) {
		return false
	}

	mod_extension := utils.file_extension(mod_path)
	defer delete(mod_extension)

	when ODIN_OS == .Windows {
		return mod_extension == "dll"
	} else when ODIN_OS == .Darwin {
		return mod_extension == "dylib"
	} else {
		return mod_extension == "so"
	}
}

@(private)
librarymodloader_load_mod: ae.Mod_Loader_Load_Mod_Proc : proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> Mod_Loader_Result {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	if !librarymodule_call_init(data.library_modules[mod_info.identifier]) {
		return .Error
	}

	return .Success
}

@(private)
librarymodloader_unload_mod: ae.Mod_Loader_Unload_Mod_Proc : proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> Mod_Loader_Result {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	librarymodule_call_deinit(data.library_modules[mod_info.identifier])

	return .Success
}

@(private)
librarymodloader_get_mod_proctable: ae.Mod_Loader_Get_Mod_ProcTable_Proc : proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> rawptr {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	return librarymodule_get_mod_proctable(data.library_modules[mod_info.identifier])
}

