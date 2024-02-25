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
import hacks "engine:scheduler/utils"
import "engine:storage"
import "engine:type_manager"
import aec "shared:ae_common"

_ :: log
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

	interface.proctable_init(&globals.proc_table)

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

	test_proc :: proc(task: ^hacks.Procedure_Context) {
		yield_in_proc :: proc(task: ^hacks.Procedure_Context) {
			hacks.yield(task)
		}

		log.info("%v", task)

		log.info("Hello world with task")
		defer log.infof("deferred")

		return_val: int = 42
		yield_in_proc(task)

		log.infof("Resumed task %d", return_val)
		return_val = 43
		hacks.yield(task)

		log.infof("Resumed task %d", return_val)
		return_val = 44
	}

	task := hacks.Procedure_Context{}
	defer hacks.procedurecontext_free(&task)

	ctx := common.default_context()
	hacks.call(&task, (rawptr)(test_proc), (rawptr)(&task), &ctx)

	log.infof("Resumed main")
	hacks.resume(&task)

	log.infof("Resumed main")
	hacks.resume(&task)

	log.infof("Returned main")

	// log.infof("Initialized engine")

	// log.infof("Loading mods...")
	// loader.modmanager_queue_load_folder(&globals.mod_manager, globals.config.mods_location)
	// loader.modmanager_force_load_queued_mods(&globals.mod_manager)

	// log.infof("Deinitializing engine...")
}

