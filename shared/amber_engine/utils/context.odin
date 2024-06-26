package amber_engine_utils

import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "base:runtime"
import "shared:amber_engine/mimalloc"

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
	tracking_allocator:        mem.Tracking_Allocator,
	allocator:                 mem.Allocator,
	temp_arena:                virtual.Arena,
	temp_allocator:            mem.Allocator,
	console_logger:            log.Logger,
	file_logger:               log.Logger,
	is_file_logger_valid:      bool,
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
	if virtual.arena_init_growing(&CONTEXT_DATA.temp_arena) != .None {
		return false
	}

	CONTEXT_DATA.allocator = mimalloc.allocator()
	CONTEXT_DATA.temp_allocator = virtual.arena_allocator(&CONTEXT_DATA.temp_arena)

	if DEBUG {
		mem.tracking_allocator_init(
			&CONTEXT_DATA.tracking_allocator,
			CONTEXT_DATA.allocator,
			CONTEXT_DATA.allocator,
		)
		CONTEXT_DATA.allocator = mem.tracking_allocator(&CONTEXT_DATA.tracking_allocator)
	}

	CONTEXT_DATA.console_logger = log.create_console_logger(LOWEST_LOG_LEVEL)
	if os.exists(LOGGER_FILE) {
		os.remove(LOGGER_FILE)
	}

	open_file_args := os.O_CREATE | os.O_RDWR
	when ODIN_OS != .Windows {
		open_mode := os.S_IRUSR | os.S_IWUSR
	} else {
		open_mode := 0
	}

	if handle, handle_ok := os.open(LOGGER_FILE, open_file_args, open_mode);
	   handle_ok == os.ERROR_NONE {
		CONTEXT_DATA.is_file_logger_valid = true
		CONTEXT_DATA.file_logger = log.create_file_logger(handle, LOWEST_LOG_LEVEL)
		CONTEXT_DATA.logger = log.create_multi_logger(
			CONTEXT_DATA.console_logger,
			CONTEXT_DATA.file_logger,
		)

		os.close(handle)
	} else {
		CONTEXT_DATA.is_file_logger_valid = false
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
	if !CONTEXT_DATA.is_context_initialized {
		return
	}

	if DEBUG {
		ok := true
		log.infof(
			"Checking for memory leaks (note: the logger and the tracking allocator has not been freed yet): ",
		)
		for _, leak in CONTEXT_DATA.tracking_allocator.allocation_map {
			log.warnf("\t%v leaked %v bytes", leak.location, leak.size)
			ok = false
		}
		if ok {
			log.infof("\tNo memory Leaks.")
		}

		ok = true
		log.info("Checking for bad frees: ")
		for bad_free in CONTEXT_DATA.tracking_allocator.bad_free_array {
			log.warnf("\t%v allocation %p was freed badly", bad_free.location, bad_free.memory)
		}
		if ok {
			log.infof("\tNo bad frees.")
		}

		mem.tracking_allocator_destroy(&CONTEXT_DATA.tracking_allocator)
	}
	context.allocator = CONTEXT_DATA.allocator

	log.destroy_console_logger(CONTEXT_DATA.console_logger)
	if CONTEXT_DATA.is_file_logger_valid {
		// TODO(Vicix): Fix This line. Under windows the internal file handle of 
		// the logger seems to be invalid?
		when ODIN_OS != .Windows {
			log.destroy_file_logger(&CONTEXT_DATA.logger)
		}
	}
	log.destroy_multi_logger(&CONTEXT_DATA.logger)

	virtual.arena_destroy(&CONTEXT_DATA.temp_arena)

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

