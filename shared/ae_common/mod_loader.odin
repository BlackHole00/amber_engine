package ae_common

import "core:mem"

Mod_Loader_Result :: Common_Result

Mod_Loader_Id :: distinct u64
INVALID_MODLOADERID :: (Mod_Loader_Id)(max(u64))

// Called at the loader initialization
Mod_Loader_On_Init_Proc :: #type proc(
	loader: Mod_Loader,
	allocator: mem.Allocator,
) -> Mod_Loader_Result
// Called at the loader deinitialization
Mod_Loader_On_Deinit_Proc :: #type proc(loader: Mod_Loader, allocator: mem.Allocator)

Mod_Loader_Generate_Mod_Info_Proc :: #type proc(
	loader: Mod_Loader,
	mod_path: string,
	allocator: mem.Allocator,
) -> (
	Mod_Info,
	Mod_Loader_Result,
)
Mod_Loader_Free_Mod_Info_Proc :: #type proc(
	loader: Mod_Loader,
	mod_info: Mod_Info,
	allocator: mem.Allocator,
)

Mod_Loader_Can_Load_File_Proc :: #type proc(
	loader: Mod_Loader,
	mod_path: string,
	allocator: mem.Allocator,
) -> bool

// If any of the mod loader procedures fails, this procedure will be called.
// The string must be allocated with the allocator passed to the procedure and will be freed by the caller.
Mod_Loader_Get_Last_Message_Proc :: #type proc(
	loader: Mod_Loader,
	allocator: mem.Allocator,
) -> (
	string,
	bool,
)

Mod_Loader_Load_Mod_Proc :: #type proc(
	loader: Mod_Loader,
	mod_info: Mod_Info,
	allocator: mem.Allocator,
) -> Mod_Load_Error
Mod_Loader_Unload_Mod_Proc :: #type proc(
	loader: Mod_Loader,
	mod_info: Mod_Info,
	allocator: mem.Allocator,
) -> Mod_Load_Error

Mod_Loader_Get_Mod_ProcTable :: #type proc(
	loader: Mod_Loader,
	mod_info: Mod_Info,
	allocator: mem.Allocator,
) -> rawptr

Mod_Loader_ITable :: struct {
	on_init:           Mod_Loader_On_Init_Proc,
	on_deinit:         Mod_Loader_On_Deinit_Proc,
	generate_mod_info: Mod_Loader_Generate_Mod_Info_Proc,
	free_mod_info:     Mod_Loader_Free_Mod_Info_Proc,
	can_load_file:     Mod_Loader_Can_Load_File_Proc,
	get_last_message:  Mod_Loader_Get_Last_Message_Proc,
	load_mod:          Mod_Loader_Load_Mod_Proc,
	unload_mod:        Mod_Loader_Unload_Mod_Proc,
	get_mod_proctable: Mod_Loader_Get_Mod_ProcTable,
}

Mod_Loader :: struct {
	using itable: ^Mod_Loader_ITable,
	identifier:   Mod_Loader_Id, // will be filled when the mod_loader will be registered
	name:         string,
	description:  string,
	user_data:    rawptr,
}

