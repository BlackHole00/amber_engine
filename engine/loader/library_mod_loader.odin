package amber_engine_loader

import "core:mem"
import "core:log"
import "core:strings"
import "core:dynlib"
import "engine:common"
import aec "shared:ae_common"

librarymodloader_init :: proc(mod_loader: ^Mod_Loader) {
	mod_loader.itable = &LIBRARYMODLOADER_ITABLE
	mod_loader.name = aec.DEFAULT_LIBRARY_MODLOADER_NAME
	mod_loader.description = "Loads .dll, .so and .dylib files as shared libraries"
}

librarymodloader_free :: proc(mod_loader: Mod_Loader) {}

@(private)
LIBRARYMODLOADER_ITABLE := aec.Mod_Loader_ITable {
	on_init           = librarymodloader_on_init,
	on_deinit         = librarymodloader_on_deinit,
	generate_mod_info = librarymodloader_generate_mod_info,
	free_mod_info     = librarymodloader_free_mod_info,
	can_load_file     = librarymodloader_can_load_file,
	get_last_message  = librarymodloader_get_last_message,
	free_message      = librarymodloader_free_message,
	load_mod          = librarymodloader_load_mod,
	unload_mod        = librarymodloader_unload_mod,
	get_mod_proctable = librarymodloader_get_mod_proctable,
}

@(private)
Library_Mod_Loader_Data :: struct {
	allocator:        mem.Allocator,
	temp_allocator:   mem.Allocator,
	engine_proctable: ^aec.Proc_Table,
	library_handles:  map[Mod_Id]dynlib.Library,
}

@(private)
Library_Mod_Info_Data :: struct {
	library_handle: dynlib.Library,
}

@(private)
librarymodloader_on_init: aec.Mod_Loader_On_Init_Proc : proc(
	loader: ^Mod_Loader,
	engine_proctable: ^aec.Proc_Table,
	allocator: mem.Allocator,
	temp_allocator: mem.Allocator,
) -> Mod_Loader_Result {
	data := new(Library_Mod_Loader_Data, allocator)
	data.allocator = allocator
	data.temp_allocator = temp_allocator
	data.engine_proctable = engine_proctable
	data.library_handles = make(map[Mod_Id]dynlib.Library)

	loader.user_data = data

	return .Success
}

@(private)
librarymodloader_on_deinit: aec.Mod_Loader_On_Deinit_Proc : proc(loader: ^Mod_Loader) {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator

	delete(data.library_handles)
	free(data)
}

@(private)
librarymodloader_generate_mod_info: aec.Mod_Loader_Generate_Mod_Info_Proc : proc(
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

	library, library_ok := dynlib.load_library(mod_path, true)
	if !library_ok {
		return {}, .Error
	}

	if mod_proctable_address, proctable_ok := dynlib.symbol_address(
		library,
		aec.MOD_ENGINE_PROC_TABLE_SYMBOL_NAME,
	); proctable_ok {
		(^^aec.Proc_Table)(mod_proctable_address)^ = data.engine_proctable
	} else {
		dynlib.unload_library(library)
		return {}, .Error
	}

	data.library_handles[mod_id] = library

	info = Mod_Info {
		identifier = mod_id,
		name       = common.remove_file_extension(mod_path),
		file_path  = strings.clone(mod_path),
	}

	return
}

@(private)
librarymodloader_free_mod_info: aec.Mod_Loader_Free_Mod_Info_Proc : proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	dynlib.unload_library(data.library_handles[mod_info.identifier])

	delete(mod_info.name)
	delete(mod_info.file_path)
}

@(private)
librarymodloader_can_load_file: aec.Mod_Loader_Can_Load_File_Proc : proc(
	loader: ^Mod_Loader,
	mod_path: string,
) -> bool {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	mod_extension := common.file_extension(mod_path)
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
librarymodloader_get_last_message: aec.Mod_Loader_Get_Last_Message_Proc : proc(
	loader: ^Mod_Loader,
) -> (
	string,
	bool,
) {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator

	return "", false
}

@(private)
librarymodloader_free_message: aec.Mod_Loader_Free_Message_Proc : proc(
	loader: ^Mod_Loader,
	message: string,
) {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
}

@(private)
librarymodloader_load_mod: aec.Mod_Loader_Load_Mod_Proc : proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> Mod_Load_Error {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	init_proc_address, init_proc_ok := dynlib.symbol_address(
		data.library_handles[mod_info.identifier],
		aec.MOD_INIT_PROC_SYMBOL_NAME,
	)
	if !init_proc_ok {
		log.error(
			"Library mod ",
			mod_info.identifier,
			" (",
			mod_info.name,
			") does not have a valid AE_INIT_PROC symbol exported. The mod might be broken",
		)
		return .Invalid_Mod
	}

	if init_proc_address == nil {
		log.error(
			"Library mod ",
			mod_info.identifier,
			" (",
			mod_info.name,
			") does not have set an init proc ",
		)

		return .Success
	}

	if !(aec.Mod_Init_Proc)(init_proc_address)() {
		log.error(
			"Library mod ",
			mod_info.identifier,
			" (",
			mod_info.name,
			") failed initializing ",
		)

		return .Internal_Mod_Error
	}

	return .Success
}

@(private)
librarymodloader_unload_mod: aec.Mod_Loader_Unload_Mod_Proc : proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> Mod_Load_Error {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	deinit_proc_address, deinit_proc_ok := dynlib.symbol_address(
		data.library_handles[mod_info.identifier],
		aec.MOD_DEINIT_PROC_SYMBOL_NAME,
	)
	if !deinit_proc_ok {
		log.error(
			"Library mod ",
			mod_info.identifier,
			" (",
			mod_info.name,
			") does not have a valid AE_DEINIT_PROC symbol exported. The mod might be broken",
		)
		return .Invalid_Mod
	}

	if deinit_proc_address == nil {
		log.error(
			"Library mod ",
			mod_info.identifier,
			" (",
			mod_info.name,
			") does not have set an deinit proc ",
		)

		return .Success
	}

	(aec.Mod_Deinit_Proc)(deinit_proc_address)()

	return .Success
}

@(private)
librarymodloader_get_mod_proctable: aec.Mod_Loader_Get_Mod_ProcTable_Proc : proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> rawptr {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator
	context.temp_allocator = data.temp_allocator

	proc_table_address, address_ok := dynlib.symbol_address(
		data.library_handles[mod_info.identifier],
		aec.MOD_PROC_TABLE_SYMBOL_NAME,
	)
	if !address_ok {
		log.error(
			"Library mod ",
			mod_info.identifier,
			" (",
			mod_info.name,
			") does not have a valid AE_PROC_TABLE symbol exported. The mod might be broken",
		)
		return nil
	}

	return (^rawptr)(proc_table_address)^
}

