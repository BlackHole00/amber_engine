package main

import "core:log"
import aec "shared:ae_common"
import "interface"
import "config"
import "common"
import "loader"

_ :: interface
_ :: config
_ :: common
_ :: loader

main :: proc() {
	context = common.default_context()
	defer common.default_context_deinit()

	log.info("Test, test, test")

	conf: aec.Config = ---
	err := config.config_from_file_or_default(&conf, ".")
	defer config.config_free(conf)

	log.info(err, conf)


}

