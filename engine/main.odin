package main

import "base:runtime"
import "base:intrinsics"
import "core:sync"
import "core:log"
import "core:os"
import "engine:config"
import "engine:globals"
import "engine:interface"
import "engine:loader"
import "engine:namespace_manager"
import "engine:storage"
import "engine:type_manager"
import "shared:mimalloc"
import ae "shared:amber_engine/common"
import "shared:amber_engine/utils"
import "core:thread"
import "core:time"

_ :: runtime
_ :: log
_ :: ae
_ :: interface
_ :: config
_ :: utils
_ :: loader
_ :: globals
_ :: storage
_ :: time
_ :: os
_ :: thread
_ :: namespace_manager
_ :: type_manager
_ :: mimalloc
_ :: time

main :: proc() {
	context = utils.default_context()
	defer utils.default_context_deinit()

	log.infof(
		"Initializing Amber Engine ver.%d.%drev%d",
		config.VERSION.major,
		config.VERSION.minor,
		config.VERSION.revision,
	)

	context.allocator = mimalloc.allocator()
	test_vec()

	config.config_from_file_or_default(&globals.config, ".")
	defer config.config_free(globals.config)
	log.infof("Using config %#v", globals.config)

	context.logger.lowest_level = globals.config.logging_level

	namespace_manager.init()
	defer namespace_manager.deinit()

	type_manager.init()
	defer type_manager.deinit()

	storage.storage_init(&globals.storage)
	defer storage.storage_free(globals.storage)

	// log.infof("Loading mods...")
	// loader.modmanager_queue_load_folder(&globals.mod_manager, globals.config.mods_location)
	// loader.modmanager_force_load_queued_mods(&globals.mod_manager)

	// log.infof("Deinitializing engine...")
}

test_vec :: proc() {
	thread_proc :: proc(vec: ^utils.Async_Vec(int)) {
		for i in 0..<100000 {
			utils.asyncvec_append(vec, i)

			// utils.asyncvec_set(vec^, 0, i)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
			// utils.asyncvec_get(vec^, 0)
		}
	}

	thread_proc_mutex :: proc(vec: ^struct {
		vec: [dynamic]int,
		mutex: sync.Mutex,
	}) {
		for i in 0..<100000 {
			if sync.mutex_guard(&vec.mutex) {
				append(&vec.vec, i)
			}
			// if sync.mutex_guard(&vec.mutex) {
			// 	vec.vec[0] = i
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
			// if sync.mutex_guard(&vec.mutex) {
			// 	_ = vec.vec[0]
			// }
		}
	}

	vec: utils.Async_Vec(int)
	defer utils.asyncvec_delete(&vec)
	utils.asyncvec_init_empty(&vec, 32)

	threads: [8]^thread.Thread
	start := time.now()
	for &thr in threads {
		thr = thread.create_and_start_with_data(&vec, auto_cast thread_proc, context, .Normal, true)
	}
	thread.join_multiple(..threads[:])
	stop := time.now()

	log.info("The async_vec took", time.diff(start, stop), utils.asyncvec_len(vec))

	data: struct {
		vec: [dynamic]int,
		mutex: sync.Mutex,
	}
	data.vec = make([dynamic]int)
	start = time.now()
	for &thr in threads {
		thr = thread.create_and_start_with_data(&data, auto_cast thread_proc_mutex, context, .Normal, true)
	}
	thread.join_multiple(..threads[:])
	stop = time.now()

	log.info("The mutexed vec took", time.diff(start, stop), len(data.vec))
}

