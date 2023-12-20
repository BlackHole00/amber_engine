package amber_engine_loader

import "core:dynlib"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"
import "core:runtime"
import aec "shared:ae_common"

Library_Module :: struct {
	allocator:       mem.Allocator,
	library_path:    string,
	library_handle:  dynlib.Library,
	mod_export_data: ^aec.Mod_Export_Data,
	mod_import_data: ^aec.Mod_Import_Data,
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
	library_path: string,
	allocator := context.allocator,
) {
	context.allocator = allocator
	module.allocator = allocator

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
	mod_context: runtime.Context,
) -> (
	result: Library_Module_Result,
) {
	log.debugf("Loading Library_Module %s...", module.library_path)

	if !os.exists(module.library_path) || os.is_dir(module.library_path) {
		log.errorf(
			"Could not load Library_Module %s: The provided path is not valid",
			module.library_path,
		)
		return .Path_Error
	}

	library, did_load := dynlib.load_library(module.library_path, true)
	if !did_load {
		log.errorf(
			"Could not load Library_Module %s: Could not load the dynamic library",
			module.library_path,
		)
		return .Loading_Error
	}
	module.library_handle = library
	defer if result != .Success {
		dynlib.unload_library(library)
	}

	if !librarymodule_search_default_symbols(module) {
		log.errorf(
			"Could not load Library_Module %s: The mod does not export the required symbols",
			module.library_path,
		)
		return .Missing_Symbol_Error
	}

	if librarymodule_check_default_symbols(module^) == .Error {
		return .Internal_Mod_Error
	}

	librarymodule_set_mod_imported_data(module^, engine_proctable, mod_context)

	if !librarymodule_call_init(module^) {
		return .Internal_Mod_Error
	}

	return .Success
}

librarymodule_unload_library :: proc(module: ^Library_Module) -> bool {
	librarymodule_call_deinit(module^)

	if !dynlib.unload_library(module.library_handle) {
		log.errorf("Could not unload library handle %s", module.library_path)
		return false
	}
	module.library_handle = nil

	return true
}

librarymodule_get_mod_proctable :: proc(module: Library_Module) -> rawptr {
	return module.mod_export_data.mod_proctable
}

@(private)
librarymodule_check_default_symbols :: proc(module: Library_Module) -> (res: Mod_Loader_Result) {
	if (rawptr)(module.mod_export_data) == (rawptr)(module.mod_import_data) && module.mod_export_data != nil {
		log.errorf(
			"The Library_Module %s has the symbols %s and %s pointed to the same address",
			module.library_path,
			aec.MOD_IMPORT_DATA_SYMBOL_NAME,
			aec.MOD_EXPORT_DATA_SYMBOL_NAME,
		)
		return .Error
	}

	if module.mod_export_data.init == nil {
		log.warnf(
			"The Library_Module %s did not provide a valid Mod_Init_Proc procedure",
			module.library_path,
		)
		return .Warning
	}

	if module.mod_export_data.deinit == nil {
		log.warnf(
			"The Library_Module %s did not provide a valid Mod_Deinit_Proc procedure",
			module.library_path,
		)
		return .Warning
	}

	return .Success
}

@(private)
librarymodule_set_mod_imported_data :: proc(
	module: Library_Module,
	engine_proctable: ^aec.Proc_Table,
	mod_context: runtime.Context,
) {
	module.mod_import_data.engine_proctable = engine_proctable
	module.mod_import_data.default_context = mod_context
}

@(private)
librarymodule_call_init :: proc(module: Library_Module) -> bool {
	if module.mod_export_data.init == nil {
		log.infof("Skipping Mod_Init_Proc of Library_Module %s...", module.library_path)

		return true
	}

	log.debugf("Calling Mod_Init_Proc of Library_Module %s...", module.library_path)

	if module.mod_export_data.init() {
		log.debugf("Successfully called Mod_Init_Proc of Library_Module %s", module.library_path)
	} else {
		log.errorf("Could not load Library_Module %s: Mod_Init_Proc failed", module.library_path)
		return false
	}

	return true
}

@(private)
librarymodule_call_deinit :: proc(module: Library_Module) {
	if module.mod_export_data.deinit == nil {
		log.infof("Skipping Mod_Deinit_Proc of Library_Module %s...", module.library_path)

		return
	}

	log.debugf("Calling Mod_Deinit_Proc of Library_Module %s...", module.library_path)

	module.mod_export_data.deinit()

	log.debugf("Successfully called Mod_Deinit_Proc of Library_Module %s", module.library_path)
}

@(private)
librarymodule_search_default_symbols :: proc(module: ^Library_Module) -> (ok: bool) {
	ok = true

	if import_symbol_address := librarymodule_search_symbol(
		module^,
		aec.MOD_IMPORT_DATA_SYMBOL_NAME,
	); import_symbol_address != nil {
		module.mod_import_data = (^aec.Mod_Import_Data)(import_symbol_address)
	} else {
		ok = false
	}

	if export_symbol_address := librarymodule_search_symbol(
		module^,
		aec.MOD_EXPORT_DATA_SYMBOL_NAME,
	); export_symbol_address != nil {
		module.mod_export_data = (^aec.Mod_Export_Data)(export_symbol_address)
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
			"Could not find exported symbol %s in Library_Module %s",
			symbol,
			module.library_path,
		)
	}

	return nil
}

