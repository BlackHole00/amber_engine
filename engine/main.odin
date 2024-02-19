package main

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

loop_hackery :: proc "c" () {
	instruction_pointer := hacks.get_location_of_this_instruction()
	initial_stack_pointer := hacks.get_stack_pointer()

	context = common.default_context()

	log_instruction := hacks.get_location_of_this_instruction()
	log.infof("Wow, %x %x %x", instruction_pointer, initial_stack_pointer, log_instruction)

	hacks.simple_jump(log_instruction)
}

main :: proc() {
	instruction_pointer := hacks.get_location_of_this_instruction()
	initial_stack_pointer := hacks.get_stack_pointer()

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

	// loop_hackery()

	pc := hacks.Procedure_Context{}

	first := true

	current_instruction := hacks.get_location_of_this_instruction()
	pc.return_instruction_pointer = current_instruction
	pc.stack_start_address = hacks.get_stack_pointer()
	pc.return_stack_address = hacks.get_stack_pointer()

	wow :: proc(pc: ^hacks.Procedure_Context) {
		instruction_pointer := hacks.get_location_of_this_instruction()
		stack_pointer := hacks.get_stack_pointer()

		log.infof("Wow stats before yield:")
		log.infof("\tfirst recorded instruction address:\t%x", instruction_pointer)
		log.infof("\todin address:\t\t\t\t%x", transmute(uintptr)(wow))
		log.infof("\tstack pointer:\t\t\t\t%x", stack_pointer)

		hacks.yield(pc)
		new_stack_pointer := hacks.get_stack_pointer()

		log.infof("\tWow stats after yield:")
		log.infof("\t\tfirst recorded instruction address:\t%x", instruction_pointer)
		log.infof("\t\todin address:\t\t\t\t%x", transmute(uintptr)(wow))
		log.infof("\t\told tstack pointer:\t\t\t\t%x", stack_pointer)
		log.infof("\t\tnew tstack pointer:\t\t\t\t%x", new_stack_pointer)
	}

	log.infof("Main stats:")
	log.infof("\tfirst recorded instruction address:\t%x", instruction_pointer)
	log.infof("\todin address:\t\t\t\t%x", transmute(uintptr)(main))
	log.infof("\tstack pointer:\t\t\t\t%x", initial_stack_pointer)

	if first {
		first = false
		wow(&pc)
	} else {
		hacks.restore(&pc, hacks.get_stack_pointer())
	}

	// wow :: proc "c" () {
	// 	context = common.default_context()

	// 	panic("Success")
	// }

	// status := scheduler.Procedure_Context{}
	// scheduler.yield(&status, instruction_pointer, initial_stack_pointer)
	// log.infof("%v", status)

	// u64_type := storage.storage_register_resource_type(&globals.storage, "u64", size_of(u64))
	// byte_type := storage.storage_register_resource_type(&globals.storage, "byte", size_of(byte))
	// f32_type := storage.storage_register_resource_type(&globals.storage, "f32", size_of(f32))
	// f64_type := storage.storage_register_resource_type(&globals.storage, "f64", size_of(f64))

	// u64_data: []u64 = {18446744073709551615}
	// byte_data: []byte = {0b10100010}
	// f32_data: []f32 = {256.32}
	// f64_data: []f64 = {354.23}

	// u64_id := storage.storage_add_resource(
	// 	&globals.storage,
	// 	u64_type,
	// 	mem.slice_data_cast([]byte, u64_data),
	// )
	// byte_id := storage.storage_add_resource(
	// 	&globals.storage,
	// 	byte_type,
	// 	mem.slice_data_cast([]byte, byte_data),
	// )
	// f32_id := storage.storage_add_resource(
	// 	&globals.storage,
	// 	f32_type,
	// 	mem.slice_data_cast([]byte, f32_data),
	// )
	// f64_id := storage.storage_add_resource(
	// 	&globals.storage,
	// 	f64_type,
	// 	mem.slice_data_cast([]byte, f64_data),
	// )

	// u64_retrival: []u64 = {0}
	// byte_retrival: []byte = {0}
	// f32_retrival: []f32 = {0}
	// f64_retrival: []f64 = {0}
	// storage.storage_get_resource(
	// 	&globals.storage,
	// 	u64_id,
	// 	mem.slice_data_cast([]byte, u64_retrival),
	// )
	// storage.storage_get_resource(
	// 	&globals.storage,
	// 	byte_id,
	// 	mem.slice_data_cast([]byte, byte_retrival),
	// )
	// storage.storage_get_resource(
	// 	&globals.storage,
	// 	f32_id,
	// 	mem.slice_data_cast([]byte, f32_retrival),
	// )
	// storage.storage_get_resource(
	// 	&globals.storage,
	// 	f64_id,
	// 	mem.slice_data_cast([]byte, f64_retrival),
	// )

	// assert(u64_retrival[0] == u64_data[0])
	// assert(byte_retrival[0] == byte_data[0])
	// assert(f32_retrival[0] == f32_data[0])
	// assert(f64_retrival[0] == f64_data[0])

	// storage.storage_remove_resource(&globals.storage, f64_id)
	// storage.storage_remove_resource(&globals.storage, f32_id)

	// f32_data = {0.0}
	// f32_id = storage.storage_add_resource(
	// 	&globals.storage,
	// 	f32_type,
	// 	mem.slice_data_cast([]byte, f32_data),
	// )
	// f64_data = {4631279413.5}
	// f64_id = storage.storage_add_resource(
	// 	&globals.storage,
	// 	f64_type,
	// 	mem.slice_data_cast([]byte, f64_data),
	// )

	// storage.storage_get_resource(
	// 	&globals.storage,
	// 	f64_id,
	// 	mem.slice_data_cast([]byte, f64_retrival),
	// )
	// storage.storage_get_resource(
	// 	&globals.storage,
	// 	f32_id,
	// 	mem.slice_data_cast([]byte, f32_retrival),
	// )

	// assert(u64_retrival[0] == u64_data[0])
	// assert(f32_retrival[0] == f32_data[0])

	// schdlr: scheduler.Scheduler
	// scheduler.scheduler_init(
	// 	&schdlr,
	// 	scheduler.Scheduler_Descriptor{thread_count = globals.config.scheduler_threads},
	// )
	// scheduler.scheduler_start(&schdlr)
	// defer scheduler.scheduler_free(&schdlr)

	// // scheduler.taskmanager_register_task(&schdlr.task_manager, aec.Task_Descriptor {
	// // 	task_proc = proc(
	// // 		task_id: aec.Task_Id,
	// // 		task_descriptor: ^aec.Task_Descriptor,
	// // 	) -> aec.Task_Result {
	// // 		log.infof("Hello from task %d, using descriptor %#v", task_id, task_descriptor)

	// // 		return aec.Task_Result_Finished{}
	// // 	},
	// // 	free_when_finished = true,
	// // })

	// // scheduler.taskmanager_register_task(&schdlr.task_manager, aec.Task_Descriptor {
	// // 	task_proc = proc(
	// // 		task_id: aec.Task_Id,
	// // 		task_descriptor: ^aec.Task_Descriptor,
	// // 	) -> aec.Task_Result {
	// // 		log.infof(
	// // 			"Hello from repeating task %d, using descriptor %#v",
	// // 			task_id,
	// // 			task_descriptor,
	// // 		)

	// // 		return aec.Task_Result_Repeat{}
	// // 	},
	// // 	free_when_finished = true,
	// // })

	// // scheduler.taskmanager_register_task(&schdlr.task_manager, aec.Task_Descriptor {
	// // 	task_proc = proc(
	// // 		task_id: aec.Task_Id,
	// // 		task_descriptor: ^aec.Task_Descriptor,
	// // 	) -> aec.Task_Result {
	// // 		log.infof(
	// // 			"Hello from repeating task %d every 1 second. The time now is %v",
	// // 			task_id,
	// // 			time.now(),
	// // 		)

	// // 		return aec.Task_Result_Repeat_After{time.Second}
	// // 	},
	// // 	free_when_finished = true,
	// // 	user_priority = .High,
	// // })

	// // Async_Proc_1_Stage :: enum int {
	// // 	Print_A,
	// // 	Print_B,
	// // }
	// // async_proc_1 :: proc(
	// // 	task_id: aec.Task_Id,
	// // 	task_descriptor: ^aec.Task_Descriptor,
	// // ) -> aec.Task_Result {
	// // 	switch (Async_Proc_1_Stage)(task_descriptor.user_index) {
	// // 	case .Print_A:
	// // 		log.info("See you in 5 seconds")

	// // 		task_descriptor.user_index = (int)(Async_Proc_1_Stage.Print_B)
	// // 		return aec.Task_Result_Sleep{5 * time.Second}

	// // 	case .Print_B:
	// // 		log.info("Hi ho!")
	// // 		return aec.Task_Result_Finished{}
	// // 	}

	// // 	unreachable()
	// // }

	// // scheduler.taskmanager_register_task(
	// // 	&schdlr.task_manager,
	// // 	aec.Task_Descriptor{task_proc = async_proc_1, free_when_finished = true},
	// // )

	// // for i in 0 ..= 10000000 {
	// // 	j := i
	// // 	j = j * j
	// // }

	// // loader.modmanager_init(
	// // 	&globals.mod_manager,
	// // 	&globals.proc_table,
	// // 	context.allocator,
	// // 	context.temp_allocator,
	// // 	context,
	// // )
	// // defer loader.modmanager_free(&globals.mod_manager)

	// // loader.librarymodloader_init(&globals.library_mod_loader)
	// // defer loader.librarymodloader_free(globals.library_mod_loader)
	// // loader.modmanager_register_modloader(&globals.mod_manager, globals.library_mod_loader)

	log.infof("Initialized engine")

	log.infof("Loading mods...")
	loader.modmanager_queue_load_folder(&globals.mod_manager, globals.config.mods_location)
	loader.modmanager_force_load_queued_mods(&globals.mod_manager)

	log.infof("Deinitializing engine...")
}

