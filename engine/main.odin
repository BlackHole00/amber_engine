package main

import "core:log"
import aec "shared:ae_common"
import "interface"
import "config"
import "common"
import "loader"
import "globals"

_ :: log
_ :: aec
_ :: interface
_ :: config
_ :: common
_ :: loader
_ :: globals

main :: proc() {
	context = common.default_context()
	defer common.default_context_deinit()

	log.infof(
		"Initializing Amber Engine ver.%d.%drev%d",
		config.VERSION.major,
		config.VERSION.minor,
		config.VERSION.revision,
	)

	interface.proctable_init(&globals.proc_table)

	config.config_from_file_or_default(&globals.config, ".")
	defer config.config_free(globals.config)
	log.infof("Using config %#v", globals.config)

	context.logger.lowest_level = globals.config.logging_level

	loader.modmanager_init(
		&globals.mod_manager,
		&globals.proc_table,
		context.allocator,
		context.temp_allocator,
		context,
	)
	defer loader.modmanager_free(&globals.mod_manager)

	loader.librarymodloader_init(&globals.library_mod_loader)
	defer loader.librarymodloader_free(globals.library_mod_loader)
	loader.modmanager_register_modloader(&globals.mod_manager, globals.library_mod_loader)

	log.infof("Initialized engine")

	log.infof("Loading mods...")
	loader.modmanager_queue_load_folder(&globals.mod_manager, globals.config.mods_location)
	loader.modmanager_force_load_queued_mods(&globals.mod_manager)

	log.infof("Deinitializing engine...")
}

