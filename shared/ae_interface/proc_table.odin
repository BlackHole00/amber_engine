package ae_interface

import aec "shared:ae_common"

// This global variable must be present in all mods. It will be set by a mod
// loader before any engine-interfacing-code is runned. Please note that in the
// mod entrypoint this global is not garanteed to be valid.
// All the interface procedures call procedures inside this table
@(export)
AE_MOD_PROC_TABLE: ^aec.Proc_Table

