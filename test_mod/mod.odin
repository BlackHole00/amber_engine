package ae_test_mod

import "core:log"
import ae "shared:ae_interface"

init: ae.Mod_Init_Proc : proc() -> bool {
	log.infof("Hello mod init")

	log.infof("Test mod running under amber engine %v", ae.get_version())
	log.infof("Detected config: %v", ae.get_config())

	log.infof("Other mods detected:")
	mod_infos := ae.modmanager_get_modinfo_list()
	defer delete(mod_infos)
	for info in mod_infos {
		log.infof(
			"\t%d - %s (%s) %s",
			info.identifier,
			info.name,
			info.file_path,
			"(fully loaded)" if info.fully_loaded else "",
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

