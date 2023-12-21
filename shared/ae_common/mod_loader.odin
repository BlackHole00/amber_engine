package ae_common

import "core:mem"
import "core:runtime"

DEFAULT_ARCHIVE_EXTENSIONS :: [?]string{"zip", "aemod"}
DEFAULT_LIBRARY_EXTENSIONS :: [?]string{"dll", "so", "dylib"}
DEFAULT_ARCHIVE_MODLOADER_NAME :: "archive_mod_loader"
DEFAULT_LIBRARY_MODLOADER_NAME :: "library_mod_loader"

Mod_Loader_Result :: Common_Result

// See `ae_interface:Mod_Loader_Id`
Mod_Loader_Id :: distinct u64

INVALID_MODLOADERID :: (Mod_Loader_Id)(max(u64))

// Called on the Mod_Loader initialization (i.e. on the registration in the mod 
// manager). The allocators provided by the function should be the one used by
// the mod loader
// TODO(Vicix): The mod_context should be obtained using a Context_Manager or something
Mod_Loader_Init_Proc :: #type proc(
	loader: ^Mod_Loader,
	mod_loader_id: Mod_Loader_Id,
	engine_proctable: ^Proc_Table,
	allocator: mem.Allocator,
	temp_allocator: mem.Allocator,
	mod_context: runtime.Context,
) -> Mod_Loader_Result

// Called on the Mod_Loader deinitialization (i.e on the removal from the mod
// manager or at the application shutdown)
Mod_Loader_Deinit_Proc :: #type proc(loader: ^Mod_Loader)

// Generates the `Mod_Info` of a mod (identified by its path). The identifier of
// the returned Mod_Info must be equal to the provided Mod_Id
Mod_Loader_Generate_Mod_Info_Proc :: #type proc(
	loader: ^Mod_Loader,
	mod_path: string,
	mod_id: Mod_Id,
) -> (
	Mod_Info,
	Mod_Loader_Result,
)

// Frees the `Mod_Info` previously generated 
Mod_Loader_Free_Mod_Info_Proc :: #type proc(loader: ^Mod_Loader, mod_info: Mod_Info)

// Checks if the mod loader is able to load a mod (identified by its path)
Mod_Loader_Can_Load_File_Proc :: #type proc(loader: ^Mod_Loader, mod_path: string) -> bool

// Loads a mod (usually by applying its config config files and loading its
// shared library)
Mod_Loader_Load_Mod_Proc :: #type proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> Mod_Loader_Result

// Unloads a mod
Mod_Loader_Unload_Mod_Proc :: #type proc(
	loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> Mod_Loader_Result

// Gets the proc table of a mod. If the mod does not have a proc table, it 
// can return null. For further documentation see 
// `ae_interface:Mod_Proc_Table`
Mod_Loader_Get_Mod_ProcTable_Proc :: #type proc(loader: ^Mod_Loader, mod_info: Mod_Info) -> rawptr

// Mod_Loader_Proc_Table is a table that every Mod Loader must implement.
// Its procedures will be called by the mod manager when opportune
Mod_Loader_Proc_Table :: struct {
	init:              Mod_Loader_Init_Proc,
	deinit:            Mod_Loader_Deinit_Proc,
	generate_mod_info: Mod_Loader_Generate_Mod_Info_Proc,
	free_mod_info:     Mod_Loader_Free_Mod_Info_Proc,
	can_load_file:     Mod_Loader_Can_Load_File_Proc,
	load_mod:          Mod_Loader_Load_Mod_Proc,
	unload_mod:        Mod_Loader_Unload_Mod_Proc,
	get_mod_proctable: Mod_Loader_Get_Mod_ProcTable_Proc,
}

// For a general description see `ae_interface/mod_manager.odin`
// @memory: a mod loader should always use the allocators provided in its
//          on_init callback
Mod_Loader :: struct {
	using itable: ^Mod_Loader_Proc_Table,
	// Must be unique between mod loaders
	name:         string,
	// A general description of the mod loader
	description:  string,
	user_data:    rawptr,
	// Will be used internally by the mod loader. Can be ignored by the user
	identifier:   Mod_Loader_Id,
}

// See `Mod_Loader_On_Init_Proc`
modloader_init :: #force_inline proc(
	mod_loader: ^Mod_Loader,
	mod_loader_id: Mod_Loader_Id,
	engine_proctable: ^Proc_Table,
	allocator: mem.Allocator,
	temp_allocator: mem.Allocator,
	mod_context: runtime.Context,
) -> Mod_Loader_Result {
	return(
		mod_loader->init(mod_loader_id, engine_proctable, allocator, temp_allocator, mod_context) \
	)
}

// See `Mod_Loader_On_Deinit_Proc`
modloader_deinit :: #force_inline proc(mod_loader: ^Mod_Loader) {
	mod_loader->deinit()
}

// See `Mod_Loader_Generate_Mod_Info_Proc`
modloader_generate_mod_info :: #force_inline proc(
	mod_loader: ^Mod_Loader,
	mod_path: string,
	mod_id: Mod_Id,
) -> (
	Mod_Info,
	Mod_Loader_Result,
) {
	return mod_loader->generate_mod_info(mod_path, mod_id)
}

// See `Mod_Loader_Free_Mod_Info_Proc`
modloader_free_mod_info :: #force_inline proc(mod_loader: ^Mod_Loader, mod_info: Mod_Info) {
	mod_loader->free_mod_info(mod_info)
}

// See `Mod_Loader_Can_Load_File_Proc`
modloader_can_load_file :: #force_inline proc(mod_loader: ^Mod_Loader, mod_path: string) -> bool {
	return mod_loader->can_load_file(mod_path)
}

// See `Mod_Loader_Load_Mod_Proc`
modloader_load_mod :: #force_inline proc(
	mod_loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> Mod_Loader_Result {
	return mod_loader->load_mod(mod_info)
}

// See `Mod_Loader_Unload_Mod_Proc`
modloader_unload_mod :: #force_inline proc(
	mod_loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> Mod_Loader_Result {
	return mod_loader->unload_mod(mod_info)
}

// See `Mod_Loader_Get_Mod_ProcTable_Proc`
modloader_get_mod_proctable :: #force_inline proc(
	mod_loader: ^Mod_Loader,
	mod_info: Mod_Info,
) -> rawptr {
	return mod_loader->get_mod_proctable(mod_info)
}

