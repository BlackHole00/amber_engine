package main

import "base:intrinsics"
import "core:log"
import "core:time"
import "engine:common"
import "engine:config"
import "engine:globals"
import "engine:interface"
import "engine:loader"
import "engine:namespace_manager"
import "engine:scheduler"
import hacks "engine:scheduler/utils"
import "engine:storage"
import "engine:type_manager"
import aec "shared:ae_common"

_ :: log
_ :: scheduler
_ :: aec
_ :: interface
_ :: config
_ :: common
_ :: loader
_ :: globals
_ :: hacks
_ :: storage
_ :: time
_ :: namespace_manager
_ :: type_manager

main :: proc() {
	context = common.default_context()
	defer common.default_context_deinit()

	log.infof(
		"Initializing Amber Engine ver.%d.%drev%d",
		config.VERSION.major,
		config.VERSION.minor,
		config.VERSION.revision,
	)

	config.config_from_file_or_default(&globals.config, ".")
	defer config.config_free(globals.config)
	log.infof("Using config %#v", globals.config)

	context.logger.lowest_level = globals.config.logging_level

	namespace_manager.init()
	defer namespace_manager.deinit()

	assert(namespace_manager.find_namespace("odin") == 0)
	assert(namespace_manager.find_namespace("core") == 0)
	assert(namespace_manager.find_namespace("base") == 0)
	assert(namespace_manager.find_namespace("amber_engine") == 1)
	assert(namespace_manager.find_namespace("ae") == 1)
	assert(namespace_manager.find_namespace("error") == aec.INVALID_NAMESPACE_ID)

	type_manager.init()
	defer type_manager.deinit()

	storage.storage_init(&globals.storage)
	defer storage.storage_free(globals.storage)

	// log.infof("Loading mods...")
	// loader.modmanager_queue_load_folder(&globals.mod_manager, globals.config.mods_location)
	// loader.modmanager_force_load_queued_mods(&globals.mod_manager)

	// log.infof("Deinitializing engine...")
}

