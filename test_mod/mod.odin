package ae_test_mod

import "core:log"
import ae "shared:ae_interface"

init: ae.Mod_Init_Proc : proc() -> bool {
	log.info("Hello mod init")

	log.info("Test mod running under amber engine", ae.get_version())
	log.info("Detected config: ", ae.get_config())

	log.info("Other mods detected:")
	mod_infos := ae.modmanager_get_modinfo_list()
	defer delete(mod_infos)
	for info in mod_infos {
		loaded_str := "(fully loaded)" if info.fully_loaded else ""
		log.info(
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
	log.info("Hello mod deinit")
}

main :: proc() {
	ae.set_mod_export_symbols(init, deinit)
}

