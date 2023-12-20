package amber_engine_loader

import "core:dynlib"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"
import aec "shared:ae_common"

Library_Module :: struct {
	allocator:                       mem.Allocator,
	mod_info:                        Mod_Info,
	library_path:                    string,
	library_handle:                  dynlib.Library,
	engine_proctable_symbol_address: ^^aec.Proc_Table,
	mod_proctable_symbol_address:    ^rawptr,
	init_symbol_address:             ^aec.Mod_Init_Proc,
	deinit_symbol_address:           ^aec.Mod_Deinit_Proc,
}

Library_Module_Result :: enum {
	Success,
	Internal_Mod_Error,
	Missing_Symbol_Error,
	Loading_Error,
	Path_Error,
}

librarymodule_init :: proc(
	module: ^Library_Module,
	mod_info: Mod_Info,
	library_path: string,
	allocator := context.allocator,
) {
	context.allocator = allocator
	module.allocator = allocator

	module.mod_info = mod_info
	module.library_path = strings.clone(library_path)
}

librarymodule_free :: proc(module: ^Library_Module) -> bool {
	context.allocator = module.allocator

	delete(module.library_path)

	return true
}

librarymodule_load_library :: proc(
	module: ^Library_Module,
	engine_proctable: ^aec.Proc_Table,
) -> (
	result: Library_Module_Result,
) {
	log.debugf(
		"Loading Library_Module %s of mod %d (%s)...",
		module.library_path,
		module.mod_info.identifier,
		module.mod_info.name,
	)

	if !os.exists(module.mod_info.file_path) || os.is_dir(module.mod_info.file_path) {
		log.errorf(
			"Could not load Library_Module %s of mod %d (%s): The provided path is not valid",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
		return .Path_Error
	}

	library, did_load := dynlib.load_library(module.library_path, true)
	if !did_load {
		log.errorf(
			"Could not load Library_Module %s of mod %d (%s): Could not load the dynamic library",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
		return .Loading_Error
	}
	module.library_handle = library
	defer if result != .Success {
		dynlib.unload_library(library)
	}

	if !librarymodule_search_default_symbols(module) {
		log.errorf(
			"Could not load Library_Module %s of mod %d (%s): The mod does not export the required symbols",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
		return .Missing_Symbol_Error
	}

	librarymodule_check_default_symbols(module^)

	module.engine_proctable_symbol_address^ = engine_proctable

	if !librarymodule_call_init(module^) {
		return .Internal_Mod_Error
	}

	return .Success
}

librarymodule_unload_library :: proc(module: ^Library_Module) -> bool {
	librarymodule_call_deinit(module^)

	if !dynlib.unload_library(module.library_handle) {
		log.errorf(
			"Could not unload library handle %s of mod %d (%s)",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
		return false
	}
	module.library_handle = nil

	return true
}

librarymodule_get_mod_proctable :: proc(module: Library_Module) -> rawptr {
	return module.mod_proctable_symbol_address^
}

@(private)
librarymodule_check_default_symbols :: proc(module: Library_Module) -> (ok: bool) {
	ok = true

	if module.init_symbol_address^ == nil {
		log.warnf(
			"The Library_Module %s of mod %d (%s) did not provide a valid Mod_Init_Proc procedure",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
		ok = false
	}

	if module.deinit_symbol_address^ == nil {
		log.warnf(
			"The Library_Module %s of mod %d (%s) did not provide a valid Mod_Deinit_Proc procedure",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
		ok = false
	}

	return
}

@(private)
librarymodule_call_deinit :: proc(module: Library_Module) {
	if module.deinit_symbol_address^ == nil {
		log.infof(
			"Skipping Mod_Deinit_Proc of Library_Module %s of mod %d (%s)...",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)

		return
	}

	log.debugf(
		"Calling Mod_Deinit_Proc of Library_Module %s of mod %d (%s)...",
		module.library_path,
		module.mod_info.identifier,
		module.mod_info.name,
	)

	(module.deinit_symbol_address^)()

	log.debugf(
		"Successfully called Mod_Deinit_Proc of Library_Module %s of mod %d (%s)",
		module.library_path,
		module.mod_info.identifier,
		module.mod_info.name,
	)
}

@(private)
librarymodule_call_init :: proc(module: Library_Module) -> bool {
	if module.init_symbol_address^ == nil {
		log.infof(
			"Skipping Mod_Init_Proc of Library_Module %s of mod %d (%s)...",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)

		return true
	}

	log.debugf(
		"Calling Mod_Init_Proc of Library_Module %s of mod %d (%s)...",
		module.library_path,
		module.mod_info.identifier,
		module.mod_info.name,
	)

	if (module.init_symbol_address^)() {
		log.debugf(
			"Successfully called Mod_Init_Proc of Library_Module %s of mod %d (%s)",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
	} else {
		log.errorf(
			"Could not load Library_Module %s of mod %d (%s): Mod_Init_Proc failed",
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
		return false
	}

	return true
}

@(private)
librarymodule_search_default_symbols :: proc(module: ^Library_Module) -> (ok: bool) {
	ok = true

	if symbol_address := librarymodule_search_symbol(
		module^,
		aec.MOD_ENGINE_PROC_TABLE_SYMBOL_NAME,
	); symbol_address != nil {
		module.engine_proctable_symbol_address = (^^aec.Proc_Table)(symbol_address)
	} else {
		ok = false
	}

	if symbol_address := librarymodule_search_symbol(module^, aec.MOD_INIT_PROC_SYMBOL_NAME);
	   symbol_address != nil {
		module.init_symbol_address = (^aec.Mod_Init_Proc)(symbol_address)
	} else {
		ok = false
	}

	if symbol_address := librarymodule_search_symbol(module^, aec.MOD_DEINIT_PROC_SYMBOL_NAME);
	   symbol_address != nil {
		module.deinit_symbol_address = (^aec.Mod_Deinit_Proc)(symbol_address)
	} else {
		ok = false
	}

	if symbol_address := librarymodule_search_symbol(module^, aec.MOD_PROC_TABLE_SYMBOL_NAME);
	   symbol_address != nil {
		module.mod_proctable_symbol_address = (^rawptr)(symbol_address)
	} else {
		ok = false
	}

	return
}

@(private)
librarymodule_search_symbol :: proc(module: Library_Module, symbol: string) -> rawptr {
	if symbol_address, symbol_address_ok := dynlib.symbol_address(module.library_handle, symbol);
	   symbol_address_ok {
		return symbol_address
	} else {
		log.errorf(
			"Could not find exported symbol %s in Library_Module %s of mod %d (%s). The mod could be corrupted",
			symbol,
			module.library_path,
			module.mod_info.identifier,
			module.mod_info.name,
		)
	}

	return nil
}

