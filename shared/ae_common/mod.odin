package ae_common

DEFAULT_ARCHIVE_EXTENSIONS :: [?]string{"zip", "aemod"}
DEFAULT_LIBRARY_EXTENSIONS :: [?]string{"dll", "so", "dylib"}

Mod_Id :: distinct u64
INVALID_MODID :: (Mod_Id)(max(u64))

// Describes a mod. 
// @lifetime static.
Mod_Info :: struct {
	// Filled at runtime by the Mod_Manager
	identifier:   Mod_Id,
	name:         string,
	file_path:    string,
	dependencies: []string,
	dependants:   []string,
	// Filled at runtime by the Mod_Manager
	loader:       Mod_Loader_Id,
	// Filled at runtime by the Mod_Manager
	fully_loaded: bool,
}

