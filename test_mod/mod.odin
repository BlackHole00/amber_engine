package ae_test_mod

import "core:fmt"
import ae "shared:ae_interface"

init: ae.Mod_Init_Proc : proc() -> bool {
	fmt.println("Hello mod init")

	fmt.println("Test mod running under amber engine", ae.get_version())
	fmt.println("Detected config: ", ae.get_config())

	fmt.println("Other mods detected:")
	mod_infos := ae.modmanager_get_modinfo_list()
	for info in mod_infos {
		loaded_str := "(fully loaded)" if info.fully_loaded else ""
		fmt.println(
			"\t",
			info.identifier,
			" - ",
			info.name,
			" (",
			info.file_path,
			") ",
			loaded_str,
			sep = "",
		)
	}

	return true
}

deinit: ae.Mod_Deinit_Proc : proc() {
	fmt.println("Hello mod deinit")
}

main :: proc() {
	ae.set_mod_export_symbols(init, deinit)
}

