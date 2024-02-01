package ae_interface

import aec "shared:ae_common"
import doc "shared:ae_common/doc_utils"

// The Mod Manager is a singleton that handles both mod (see 
// `ae_common/mod.odin`) and mod loader (see `Mod_Loader`) initialization.
// Note that the user can directly register and remove mod loaders, but mod 
// loadings and unloadings will be queued up and will be applied by the engine
// in the most opportune moment.
// Please note that mod loader and mod removals are discouraged and should be
// avoided.
// @singleton
// @lifetime: Mod_Manager is valid for the entire application lifetime
// @thread_safety: Mod_Manager is thread safe
Mod_Manager :: doc.Singleton_Symbol

// A Mod Loader is a loader for a specific class of file types. In order to be
// valid, a Mod_Loader must implement the `Mod_Loader_Proc_Table`.
// By default, the engine contains mod loaders for the following types:
//   - directories + zip, aemod files: can define behavoiur by configuration
//                                     files and, optionally by code (via shared
//                                     libraries)
//   - dll, so, dylib: depending from the operating system, these mods define
//                     behavoiur by code
// For futher implementation dectails, see `ae_common\mod_loader.odin`
// TODO(Vicix): Expand The documentation of common mod loaders
// @lifetime: valid from registration until removal from the mod manager. Please
//            note that the user cannot directly interact with the mod loader.
// @thread_safety: Every mod loader must be designed to be thread safe. 
Mod_Loader :: aec.Mod_Loader

// Mod_Loader_Proc_Table is a table that every Mod Loader must implement.
// For implementation details, see `ae_common:Mod_Loader_Itable`, 
// `ae_common\mod_loader.odin` and related procedures
Mod_Loader_Proc_Table :: aec.Mod_Loader_Proc_Table

// The Mod_Loader_Id is a unique identifier for a mod loader. It will be 
// assigned upon mod loader registration and will remain the same even after the
// mod loader removal from the mod manager (even if it won't be still valid)
// @performance: Depending on the implementation, an id lookup can lead to an
//               hash-map lookup. Caching of the recurring id(s) is recommended.
Mod_Loader_Id :: aec.Mod_Loader_Id

// Mod_Info contains the general informations of a mod. It is generated by a
// mod loader.
// @lifetime: valid from the queued mod load, up to the queued mod unload
Mod_Info :: aec.Mod_Info

// The Mod_Id is a unique identifier for a mod. It will be assigned upon mod 
// queued loading and will remain the same even after the mod deinitialization
// (even if it won't be still valid)
// @performance: Depending on the implementation, an id lookup can lead to an
//               hash-map lookup. Caching of the recurring id(s) is recommended.
Mod_Id :: aec.Mod_Id

// See `ae_common:Mod_Load_Error`
Mod_Load_Error :: aec.Mod_Load_Error

// A Mod proc table is a way for mods to communicate between eachothers. 
// For example, if a mod defines an api, it can export his public procedures in 
// an internal table and handle the address of that table to the mod loader. 
// Another mod will then be able to request that pointer and (upon 
// interpretation) call the first mod's public procedures.
Mod_ProcTable :: doc.Documentation_Symbol

Mod_Status :: aec.Mod_Status

INVALID_MODID :: aec.INVALID_MODID
INVALID_MODLOADERID :: aec.INVALID_MODLOADERID

// Registers a mod loader into the mod manager. Mod loader initialization will
// follow. Returns INVALID_MODLOADERID upon error(s)
modmanager_register_modloader :: #force_inline proc(mod_loader: Mod_Loader) -> Mod_Loader_Id {
	return get_engine_proctable().modmanager_register_modloader(mod_loader)
}

// Removes a mod loader from the mod manager. Returns whether or not the removal
// has been successfull
modmanager_remove_modloader :: #force_inline proc(modloader_identifier: Mod_Loader_Id) -> bool {
	return get_engine_proctable().modmanager_remove_modloader(modloader_identifier)
}

// Returns the Mod_Loader_Id of the mod loader identified by the name. Returns 
// INVALID_MODLOADERID if the mod loader does not exists
modmanager_get_modloaderid :: #force_inline proc(loader_name: string) -> aec.Mod_Loader_Id {
	return get_engine_proctable().modmanager_get_modloaderid(loader_name)
}

// Returns the Mod_Loader_Id of the mod loader that can load a specific mod
// (identified by its path). Returns INVALID_MODLOADERID if none of the registed
// mod loaders can load the specified mod
modmanager_get_modloaderid_for_file :: #force_inline proc(file_path: string) -> aec.Mod_Loader_Id {
	return get_engine_proctable().modmanager_get_modloaderid_for_file(file_path)
}

// Returns whether or not a Mod_Loader_Id is valid, i.e. its associated mod 
// loader does exists and it is still registered
modmanager_is_modloaderid_valid :: #force_inline proc(loader_id: aec.Mod_Loader_Id) -> bool {
	return get_engine_proctable().modmanager_is_modloaderid_valid(loader_id)
}

// Returns whether or not a file can be loaded by any of the mod loaders 
// registered in the mod manager
modmanager_can_load_file :: #force_inline proc(file_path: string) -> bool {
	return get_engine_proctable().modmanager_can_load_file(file_path)
}

// Queues a mod (identified by its path) to be loaded. Loading may or may not 
// be instantaneous, depending on the mod manager implementation. To force a mod
// to load please use `modmanager_force_load_queued_mods`.
// On error, the returned Mod_Id is INVALID_MODID
modmanager_queue_load_mod :: #force_inline proc(
	mod_path: string,
) -> (
	aec.Mod_Load_Error,
	aec.Mod_Id,
) {
	return get_engine_proctable().modmanager_queue_load_mod(mod_path)
}

// Queues the loading of a mod folder. Loading may or may not  be instantaneous, 
// depending on the mod manager implementation. To force a folder to load please 
// use `modmanager_force_load_queued_mods`.
// Please note that, since also folders can be loaded as mods, the mod loading 
// is not recursive (i.e. does not follow subfolders and symbolic links)
// Returns whether or not a mod failed to load.
modmanager_queue_load_folder :: #force_inline proc(folder_path: string) -> bool {
	return get_engine_proctable().modmanager_queue_load_folder(folder_path)
}

// Queues a mod to be unloaded. Unloading may or may not be instantaneous, 
// depending on the mod manager implementation. To force a mod to unload please 
// use `modmanager_force_load_queued_mods`.
modmanager_queue_unload_mod :: #force_inline proc(mod_id: aec.Mod_Id) -> bool {
	return get_engine_proctable().modmanager_queue_unload_mod(mod_id)
}

// Normally mod loading and unloading will be applied by the mod manager in the
// most opportune moment. This function forces the mod manager to load the 
// queued loads and unloads of mods
modmanager_force_load_queued_mods :: #force_inline proc() -> bool {
	return get_engine_proctable().modmanager_force_load_queued_mods()
}

// Returns a mod proctable. Returns nil if the mod does not exist or if the mod
// does not have a proctable
modmanager_get_mod_proctable :: #force_inline proc(mod_id: aec.Mod_Id) -> rawptr {
	return get_engine_proctable().modmanager_get_mod_proctable(mod_id)
}

// Returns the info of a mod
modmanager_get_modinfo :: #force_inline proc(
	mod_id: aec.Mod_Id,
) -> (
	info: aec.Mod_Info,
	found: bool,
) {
	return get_engine_proctable().modmanager_get_modinfo(mod_id)
}

// Returns the id of the mod identified by a specified name. Returns 
// INVALID_MODID if the specified name does not exists
modmanager_get_modid_from_name :: #force_inline proc(mod_name: string) -> aec.Mod_Id {
	return get_engine_proctable().modmanager_get_modid_from_name(mod_name)
}

// Returns the id of the mod identified by a its files path. Returns 
// INVALID_MODID if the specified name does not exists
modmanager_get_modid_from_path :: #force_inline proc(mod_path: string) -> aec.Mod_Id {
	return get_engine_proctable().modmanager_get_modid_from_path(mod_path)
}

// Returns whether or not a Mod_Id is valid. Please note that a Mod_Id is valid
// even when the loading of a related mod is still queued up
modmanager_is_modid_valid :: #force_inline proc(mod_id: aec.Mod_Id) -> bool {
	return get_engine_proctable().modmanager_is_modid_valid(mod_id)
}

// Returns whether or not the mod related to a Mod_Id has been full loaded (i.e.
// its loading is not queued up). Returns false if the mod does not exist
modmanager_get_mod_status :: #force_inline proc(mod_id: aec.Mod_Id) -> Mod_Status {
	return get_engine_proctable().modmanager_get_mod_status(mod_id)
}

// Returns the list of Mod_Infos of all the currently registered mods
// @memory the list must be freed by the caller
modmanager_get_modinfo_list :: #force_inline proc(allocator := context.allocator) -> []Mod_Info {
	return get_engine_proctable().modmanager_get_modinfo_list(allocator)
}

