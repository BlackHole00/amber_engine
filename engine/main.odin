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
import hacks "engine:scheduler"
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
	// instruction_pointer := hacks.get_location_of_this_instruction()
	// initial_stack_pointer := hacks.get_stack_pointer()

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

	test_proc :: proc(task: ^hacks.Task) {
		log.info("Hello world with task")
		defer log.infof("deferred")

		return_val: int = 42
		hacks.task_yield(task, return_val)

		return_val = 43
		hacks.task_yield(task, return_val)

		return_val = 44
		hacks.task_return(task, return_val)
	}

	task := hacks.Task {
		task_context = context,
	}
	defer hacks.task_free(&task)

	hacks.task_call(&task, test_proc)
	log.infof("Task yielded: %d", hacks.task_returned_value(int, &task)^)
	hacks.task_resume(&task)
	log.infof("Task yielded: %d", hacks.task_returned_value(int, &task)^)
	hacks.task_resume(&task)
	log.infof("Task returned: %d", hacks.task_returned_value(int, &task)^)
	// hacks.call(nil, main)

	// test_proc :: proc(pc: ^hacks.Procedure_Context) {
	// 	local_var := 0

	// 	log.infof("Before yield: local_var = %d", local_var)
	// 	hacks.yield(pc)

	// 	local_var = 42
	// 	log.infof("After yield: local_var = %d", local_var)
	// 	hacks.yield(pc)

	// 	local_var = 420
	// 	log.infof("After second yield: local_var = %d", local_var)
	// }

	// pc := hacks.Procedure_Context{}
	// defer hacks.procedurecontext_free(&pc)

	// log.info("Calling test_proc...")
	// hacks.call(&pc, (rawptr)(test_proc), context)
	// log.info("Resuming test_proc...")
	// hacks.resume(&pc, context)
	// log.info("Resuming test_proc...")
	// hacks.resume(&pc, context)
	// log.info("test_proc returned")

	// log.infof("Initialized engine")

	// log.infof("Loading mods...")
	// loader.modmanager_queue_load_folder(&globals.mod_manager, globals.config.mods_location)
	// loader.modmanager_force_load_queued_mods(&globals.mod_manager)

	// log.infof("Deinitializing engine...")
}

