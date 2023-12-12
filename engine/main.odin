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

	log.info(common.CONTEXT_DATA.tracking_allocator.bad_free_array)
	free(new(byte))
	log.info(common.CONTEXT_DATA.tracking_allocator.allocation_map)

	config.config_from_file_or_default(&globals.config, ".")
	defer config.config_free(globals.config)
	context.logger.lowest_level = globals.config.logging_level

	loader.modmanager_init(&globals.mod_manager, context.allocator)
	defer loader.modmanager_free(globals.mod_manager)

	interface.proctable_init(&globals.proc_table)
}

