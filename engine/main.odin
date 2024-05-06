package main

import "base:intrinsics"
import "core:log"
import "core:time"
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

	assert(namespace_manager.find_namespace("odin") == 0)
	assert(namespace_manager.find_namespace("core") == 0)
	assert(namespace_manager.find_namespace("base") == 0)
	assert(namespace_manager.find_namespace("amber_engine") == 1)
	assert(namespace_manager.find_namespace("ae") == 1)
	assert(namespace_manager.find_namespace("error") == ae.INVALID_NAMESPACE_ID)

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
		for i in 0..<10000 {
			utils.asyncvec_append(vec, i)
			log.info(os.current_thread_id(), utils.asyncvec_len(vec^))
		}
	}

	vec: utils.Async_Vec(int)
	defer utils.asyncvec_delete(&vec)
	utils.asyncvec_init_empty(&vec, 32)

	log.info(utils.item_index_to_bucket_index(140))

	threads: [2]^thread.Thread
	for &thr in threads {
		thr = thread.create_and_start_with_data(&vec, auto_cast thread_proc, context)
	}
	thread.join_multiple(..threads[:])

	assert(utils.asyncvec_len(vec) == 10000 * 2)
}

