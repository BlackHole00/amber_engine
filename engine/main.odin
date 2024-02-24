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
		log.infof(
			"Will return to: %x (and will thus jump to %x)", 
			task.caller_registers.register_statuses[.Ip], 
			task.caller_registers.register_statuses[.Lr],
		)
		// hacks._force_return(task)
		yield_in_proc(task)

		log.infof("Resumed task %d", return_val)
		return_val = 43
		hacks.yield(task)

		log.infof("Resumed task %d", return_val)
		return_val = 44
	}

	log.infof("Test_Proc address: %x", transmute(uintptr)(test_proc))
	log.infof("Main address: %x", transmute(uintptr)(main))
	log.infof("_yield address: %x", transmute(uintptr)(hacks._yield))
	log.infof("_call address: %x", transmute(uintptr)(hacks._call))
	log.infof("_resume address: %x", transmute(uintptr)(hacks._resume))

	task := hacks.Procedure_Context{}
	defer hacks.procedurecontext_free(&task)

	log.infof("Task address: %x", transmute(uintptr)(&task))
	log.infof("Task callee snapshot address %x", transmute(uintptr)(&task.callee_snapshot))
	log.infof("Task callee register snapshot address %x", transmute(uintptr)(&task.callee_snapshot.register_snapshot))
	log.infof("Task callee stack snapshot address %x", transmute(uintptr)(&task.callee_snapshot.stack_snapshot))
	log.infof("Task caller registers address %x", transmute(uintptr)(&task.caller_registers))
	log.infof("Task ip address %x", transmute(uintptr)(&task.callee_snapshot.register_snapshot.register_statuses[.Ip]))

	ctx := common.default_context()
	hacks.call(&task, (rawptr)(test_proc), (rawptr)(&task), &ctx)
	
	log.infof("Resumed main")
	log.infof(
		"Will resume to: %x (and will thus jump to %x)", 
		task.callee_snapshot.register_snapshot.register_statuses[.Ip], 
		task.callee_snapshot.register_snapshot.register_statuses[.Lr],
	)
	hacks.resume(&task)

	log.infof("Resumed main")
	log.infof(
		"Will resume to: %x (and will thus jump to %x)", 
		task.callee_snapshot.register_snapshot.register_statuses[.Ip], 
		task.callee_snapshot.register_snapshot.register_statuses[.Lr],
	)
	hacks.resume(&task)

	log.infof("Returned main")

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

