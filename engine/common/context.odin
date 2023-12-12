package amber_engine_common

import "core:mem"
import "core:mem/virtual"
import "core:log"
import "core:os"
import "core:runtime"

LOGGER_FILE :: "amber_engine.log"
LOWEST_LOG_LEVEL :: log.Level.Debug when DEBUG else log.Level.Info

@(private)
assertion_failure_proc: runtime.Assertion_Failure_Proc : proc(
	prefix, message: string,
	loc: runtime.Source_Code_Location,
) -> ! {
	log.fatalf("PANIC: %s", message, location = loc)
	log.destroy_file_logger(&CONTEXT_DATA.file_logger)

	runtime.trap()
}

@(private)
CONTEXT_DATA: struct {
	arena:                     virtual.Arena,
	tracking_allocator:        mem.Tracking_Allocator,
	allocator:                 mem.Allocator,
	temp_arena:                virtual.Arena,
	temp_tracking_allocator:   mem.Tracking_Allocator,
	temp_allocator:            mem.Allocator,
	log_file:                  os.Handle,
	console_logger:            log.Logger,
	file_logger:               log.Logger,
	logger:                    log.Logger,
	default_context:           runtime.Context,
	is_context_initialized:    bool,
	has_initialization_failed: bool,
}

@(private)
check_context_init_error :: proc(ok: bool) {
	if !ok {
		CONTEXT_DATA.has_initialization_failed = true
	}
}

@(deferred_out = check_context_init_error)
default_context_init :: proc() -> (ok: bool) {
	if virtual.arena_init_growing(&CONTEXT_DATA.arena) != .None {
		return false
	}
	if virtual.arena_init_growing(&CONTEXT_DATA.temp_arena) != .None {
		return false
	}
	CONTEXT_DATA.allocator = virtual.arena_allocator(&CONTEXT_DATA.arena)
	CONTEXT_DATA.temp_allocator = virtual.arena_allocator(&CONTEXT_DATA.temp_arena)

	if DEBUG {
		mem.tracking_allocator_init(
			&CONTEXT_DATA.tracking_allocator,
			CONTEXT_DATA.allocator,
			CONTEXT_DATA.allocator,
		)
		CONTEXT_DATA.allocator = mem.tracking_allocator(&CONTEXT_DATA.tracking_allocator)
		mem.tracking_allocator_init(
			&CONTEXT_DATA.temp_tracking_allocator,
			CONTEXT_DATA.temp_allocator,
			CONTEXT_DATA.allocator,
		)
		CONTEXT_DATA.temp_allocator = mem.tracking_allocator(&CONTEXT_DATA.temp_tracking_allocator)
	}

	CONTEXT_DATA.console_logger = log.create_console_logger(LOWEST_LOG_LEVEL)
	open_file_args :=
		os.O_CREATE | os.O_WRONLY if !os.exists(LOGGER_FILE) else os.O_RDWR | os.O_APPEND
	if handle, handle_ok := os.open(LOGGER_FILE, open_file_args); handle_ok == os.ERROR_NONE {

		CONTEXT_DATA.log_file = handle
		CONTEXT_DATA.file_logger = log.create_file_logger(handle, LOWEST_LOG_LEVEL)
		CONTEXT_DATA.logger = log.create_multi_logger(
			CONTEXT_DATA.console_logger,
			CONTEXT_DATA.file_logger,
		)
	} else {
		CONTEXT_DATA.log_file = os.INVALID_HANDLE
		CONTEXT_DATA.logger = log.create_multi_logger(CONTEXT_DATA.console_logger)
	}

	CONTEXT_DATA.default_context = runtime.Context {
		allocator              = CONTEXT_DATA.allocator,
		temp_allocator         = CONTEXT_DATA.temp_allocator,
		logger                 = CONTEXT_DATA.logger,
		assertion_failure_proc = assertion_failure_proc,
	}
	CONTEXT_DATA.is_context_initialized = true

	return true
}

default_context_deinit :: proc() {
	log.destroy_console_logger(CONTEXT_DATA.console_logger)
	if CONTEXT_DATA.log_file != os.INVALID_HANDLE {
		log.destroy_file_logger(&CONTEXT_DATA.logger)
		os.close(CONTEXT_DATA.log_file)
	}
	log.destroy_multi_logger(&CONTEXT_DATA.logger)

	virtual.arena_destroy(&CONTEXT_DATA.arena)
	if DEBUG {
		ok := true
		log.info("Checking for memory leaks: ")
		for _, leak in CONTEXT_DATA.tracking_allocator.allocation_map {
			log.warnf("\t%v leaked %v bytes", leak.location, leak.size)
			ok = false
		}
		if ok {
			log.info("\tNo memory Leaks.")
		}

		ok = true
		log.info("Checking for bad frees: ")
		for bad_free in CONTEXT_DATA.tracking_allocator.bad_free_array {
			log.warnf("\t%v allocation %p was freed badly", bad_free.location, bad_free.memory)
		}
		if ok {
			log.info("\tNo bad frees.")
		}

		mem.tracking_allocator_destroy(&CONTEXT_DATA.tracking_allocator)
	}

	CONTEXT_DATA.default_context = runtime.Context{}
	CONTEXT_DATA.is_context_initialized = false
}

default_context :: proc() -> runtime.Context {
	if !CONTEXT_DATA.is_context_initialized {
		if CONTEXT_DATA.has_initialization_failed {
			return runtime.default_context()
		}

		if !default_context_init() {
			return runtime.default_context()
		}
	}

	return CONTEXT_DATA.default_context
}

default_context_get :: default_context

