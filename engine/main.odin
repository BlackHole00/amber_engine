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

loop_hackery :: proc() {
	instruction_pointer := hacks.get_location_of_this_instruction()
	initial_stack_pointer := hacks.get_stack_pointer()

	// context = common.default_context()

	log_instruction := hacks.get_location_of_this_instruction()
	log.infof("Wow, %x %x %x", instruction_pointer, initial_stack_pointer, log_instruction)

	hacks.simple_jump(log_instruction)
}

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

	ps := new(hacks.Procedure_Snapshot)

	already_restored := false

	wow :: proc(ps: ^hacks.Procedure_Snapshot, stack_base: uintptr) {
		nested_wow :: proc(ps: ^hacks.Procedure_Snapshot, stack_base: uintptr) -> int {
			stack_variable := 42
			stack_variable += 3

			hacks.create_proceduresnapshot(ps, stack_base)

			return stack_variable
		}

		stack_variable := 42

		log.infof("Before snapshot")

		stack_variable += nested_wow(ps, stack_base)

		log.infof("Current stack_variable %d", stack_variable)
	}

	main_stack_pointer := hacks.get_stack_pointer()
	instruction := hacks.get_location_of_next_instruction()
	log.infof("Main:")
	log.infof("\tstack pointer: %x", main_stack_pointer)
	log.infof("\texaple instruction: %x", instruction)
	log.infof("Wow address: %x", transmute(uintptr)(wow))

	wow(ps, main_stack_pointer)

	if !already_restored {
		log.infof("Restoring... %x", ps.registers.register_statuses[.Rip])

		already_restored = true
		hacks.restore_proceduresnapshot(ps, main_stack_pointer)
	}

	log.infof("Initialized engine")

	log.infof("Loading mods...")
	loader.modmanager_queue_load_folder(&globals.mod_manager, globals.config.mods_location)
	loader.modmanager_force_load_queued_mods(&globals.mod_manager)

	log.infof("Deinitializing engine...")
}

