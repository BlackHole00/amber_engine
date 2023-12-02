package ae_common

DEFAULT_ARCHIVE_EXTENSIONS :: [?]string{"zip", "aemod"}
DEFAULT_LIBRARY_EXTENSIONS :: [?]string{"dll", "so", "dylib"}

Mod_Id :: distinct u64

Mod_Info :: struct {
	mod_id:       Mod_Id,
	name:         string,
	file_path:    string,
	dependencies: []string,
	dependants:   []string,
	loader:       Mod_Loader_Id,
}

