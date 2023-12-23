package ae_interface

import "core:mem"
import "core:runtime"
import aec "shared:ae_common"

Mod_Init_Proc :: aec.Mod_Init_Proc
Mod_Deinit_Proc :: aec.Mod_Deinit_Proc
Mod_Descriptor :: aec.Mod_Export_Data

@(private)
@(require)
@(export)
@(linkage = "strong")
@(link_name = aec.MOD_EXPORT_DATA_SYMBOL_NAME)
AE_MOD_EXPORT_DATA: aec.Mod_Export_Data = {}

@(private)
@(require)
@(export)
@(linkage = "strong")
@(link_name = aec.MOD_IMPORT_DATA_SYMBOL_NAME)
AE_MOD_IMPORT_DATA: aec.Mod_Import_Data = {}

set_mod_descriptor :: #force_inline proc(data: Mod_Descriptor) {
	AE_MOD_EXPORT_DATA = data
}

get_engine_proctable :: #force_inline proc() -> ^aec.Proc_Table {
	return AE_MOD_IMPORT_DATA.engine_proctable
}

default_context :: #force_inline proc() -> runtime.Context {
	return AE_MOD_IMPORT_DATA.default_context
}

default_allocator :: #force_inline proc() -> mem.Allocator {
	return default_context().allocator
}

default_temp_allocator :: #force_inline proc() -> mem.Allocator {
	return default_context().temp_allocator
}

