package ae_test_mod

import "core:log"
import ae "shared:ae_interface"

// Make sure this descriptor is static and NOT CONSTANT
// TODO(Vicix): Explain why constant does not work
MOD_DESCRIPTOR := ae.Mod_Descriptor {
	name = "Test_Mod",
	version = ae.Version{0, 1, 0},
	// dependencies = []string{"abc", "cde"},
	// dependants   = []string{"edc", "cba"},
	init = init,
	deinit = deinit,
}

init: ae.Mod_Init_Proc : proc() -> bool {
	log.infof("Hello mod init")

	log.infof("Test mod running under amber engine %v", ae.get_version())
	log.infof("Detected config: %v", ae.get_config())

	log.infof("Other mods detected:")
	mod_infos := ae.modmanager_get_modinfo_list()
	defer delete(mod_infos)
	for info in mod_infos {
		log.infof("\t%d - %s (%s) - %v", info.identifier, info.name, info.file_path, info.status)
	}

	log.infof("Getting odin and amber engine namespaces:")

	odin_namespace := ae.namespacemanager_find_namespace("odin")
	ae_namespace := ae.namespacemanager_find_namespace("amber_engine")
	assert(odin_namespace != ae.INVALID_NAMESPACE_ID)
	assert(ae_namespace != ae.INVALID_NAMESPACE_ID)

	log.infof("\tOdin: %d", odin_namespace)
	log.infof("\tAmber Engine:", ae_namespace)

	log.infof("Registering mod namespace...")
	mod_namespace := ae.namespacemanager_register_namespace(MOD_DESCRIPTOR.name)
	assert(mod_namespace != ae.INVALID_NAMESPACE_ID)
	log.infof("Using namespace %d", mod_namespace)

	return true
}

deinit: ae.Mod_Deinit_Proc : proc() {
	log.info("Hello mod deinit")
}

main :: proc() {
	ae.set_mod_descriptor(MOD_DESCRIPTOR)
}

