package amber_engine_loader

import "core:mem"
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
	can_load_file     = librarymodloader_can_load_file,
}

@(private)
Library_Mod_Loader_Data :: struct {
	allocator:        mem.Allocator,
	temp_allocator:   mem.Allocator,
	engine_proctable: ^aec.Proc_Table,
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
	
	loader.user_data = data

	return .Success
}

@(private)
librarymodloader_on_deinit: aec.Mod_Loader_On_Deinit_Proc : proc(loader: ^Mod_Loader) {
	data := (^Library_Mod_Loader_Data)(loader.user_data)
	context.allocator = data.allocator

	free(data)
}

@(private)
librarymodloader_generate_mod_info: aec.Mod_Loader_Generate_Mod_Info_Proc : proc(
	loader: ^Mod_Loader,
	mod_path: string,
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
		aec.MOD_PROCTABLE_SYMBOL_NAME,
	); proctable_ok {
		(^^aec.Proc_Table)(mod_proctable_address)^ = data.engine_proctable
	} else {
		result = .Warning
	}

	extra_data := new(Library_Mod_Info_Data)

	info = Mod_Info {
		name       = common.remove_file_extension(mod_path),
		file_path  = strings.clone(mod_path),
		extra_data = extra_data,
	}

	return
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

