package main

import "core:log"
import "core:time"
import "engine:common"
import "engine:config"
import "engine:globals"
import "engine:interface"
import "engine:loader"
import "engine:scheduler"
import aec "shared:ae_common"

_ :: log
_ :: aec
_ :: interface
_ :: config
_ :: common
_ :: loader
_ :: globals
_ :: scheduler

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

	schdlr: scheduler.Scheduler
	scheduler.scheduler_init(
		&schdlr,
		scheduler.Scheduler_Descriptor{thread_count = globals.config.scheduler_threads},
	)
	scheduler.scheduler_start(&schdlr)
	defer scheduler.scheduler_free(&schdlr)

	scheduler.taskmanager_register_task(&schdlr.task_manager, aec.Task_Descriptor {
		task_proc = proc(
			task_id: aec.Task_Id,
			task_descriptor: ^aec.Task_Descriptor,
		) -> aec.Task_Result {
			log.infof("Hello from task %d, using descriptor %#v", task_id, task_descriptor)

			return aec.Task_Result_Finished{}
		},
		free_when_finished = true,
	})

	// scheduler.taskmanager_register_task(&schdlr.task_manager, aec.Task_Descriptor {
	// 	task_proc = proc(
	// 		task_id: aec.Task_Id,
	// 		task_descriptor: ^aec.Task_Descriptor,
	// 	) -> aec.Task_Result {
	// 		log.infof(
	// 			"Hello from repeating task %d, using descriptor %#v",
	// 			task_id,
	// 			task_descriptor,
	// 		)

	// 		return aec.Task_Result_Repeat{}
	// 	},
	// 	free_when_finished = true,
	// })

	scheduler.taskmanager_register_task(&schdlr.task_manager, aec.Task_Descriptor {
		task_proc = proc(
			task_id: aec.Task_Id,
			task_descriptor: ^aec.Task_Descriptor,
		) -> aec.Task_Result {
			log.infof(
				"Hello from repeating task %d every 1 second. The time now is %v",
				task_id,
				time.now(),
			)

			return aec.Task_Result_Repeat_After{time.Second}
		},
		free_when_finished = true,
	})


	Async_Proc_1_Stage :: enum int {
		Print_A,
		Print_B,
	}
	async_proc_1 :: proc(
		task_id: aec.Task_Id,
		task_descriptor: ^aec.Task_Descriptor,
	) -> aec.Task_Result {
		switch (Async_Proc_1_Stage)(task_descriptor.user_index) {
		case .Print_A:
			log.info("See you in 5 seconds")

			task_descriptor.user_index = (int)(Async_Proc_1_Stage.Print_B)
			return aec.Task_Result_Sleep{5 * time.Second}

		case .Print_B:
			log.info("Hi ho!")
			return aec.Task_Result_Finished{}
		}

		unreachable()
	}

	scheduler.taskmanager_register_task(
		&schdlr.task_manager,
		aec.Task_Descriptor{task_proc = async_proc_1, free_when_finished = true},
	)

	// for i in 0 ..= 10000000 {
	// 	j := i
	// 	j = j * j
	// }

	// loader.modmanager_init(
	// 	&globals.mod_manager,
	// 	&globals.proc_table,
	// 	context.allocator,
	// 	context.temp_allocator,
	// 	context,
	// )
	// defer loader.modmanager_free(&globals.mod_manager)

	// loader.librarymodloader_init(&globals.library_mod_loader)
	// defer loader.librarymodloader_free(globals.library_mod_loader)
	// loader.modmanager_register_modloader(&globals.mod_manager, globals.library_mod_loader)

	// log.infof("Initialized engine")

	// log.infof("Loading mods...")
	// loader.modmanager_queue_load_folder(&globals.mod_manager, globals.config.mods_location)
	log.infof("Deinitializing engine...") // loader.modmanager_force_load_queued_mods(&globals.mod_manager)
}

