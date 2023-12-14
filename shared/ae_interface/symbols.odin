package ae_interface

import aec "shared:ae_common"

Mod_Init_Proc :: aec.Mod_Init_Proc
Mod_Deinit_Proc :: aec.Mod_Deinit_Proc

// This global variable must be present in all mods. It will be set by a mod
// loader before any engine-interfacing-code is runned. Please note that in the
// mod entrypoint this global is not garanteed to be valid.
// All the interface procedures call procedures inside this table
@(private)
@(require)
@(export)
@(link_name = aec.MOD_ENGINE_PROC_TABLE_SYMBOL_NAME)
AE_ENGINE_PROC_TABLE: ^aec.Proc_Table = nil

@(private)
@(require)
@(export)
@(link_name = aec.MOD_PROC_TABLE_SYMBOL_NAME)
AE_MOD_PROC_TABLE: rawptr = nil

@(private)
@(require)
@(export)
@(link_name = aec.MOD_INIT_PROC_SYMBOL_NAME)
AE_MOD_INIT_PROC: aec.Mod_Init_Proc = nil

@(private)
@(require)
@(export)
@(link_name = aec.MOD_DEINIT_PROC_SYMBOL_NAME)
AE_MOD_DEINIT_PROC: aec.Mod_Deinit_Proc = nil

set_mod_export_symbols :: proc(
	init_proc: aec.Mod_Init_Proc,
	deinit_proc: aec.Mod_Deinit_Proc,
	mod_proctable: rawptr = nil,
) {
	AE_MOD_INIT_PROC = init_proc
	AE_MOD_DEINIT_PROC = deinit_proc
	AE_MOD_PROC_TABLE = mod_proctable
}

