package amber_engine_scheduler_utils

import "base:runtime"
import "core:log"
import "core:sys/darwin"

Register_Snapshot :: _Register_Snapshot

_call :: #force_inline proc(
	procedure_context: ^Procedure_Context,
	procedure_address: rawptr,
	procedure_parameter: rawptr,
	procedure_context_parameter: ^runtime.Context,
	stack_size: uint,
) {
	procedure_context.callee_stack.stack_address = (uintptr)(
		darwin.syscall_mmap(
			nil,
			(u64)(stack_size),
			darwin.PROT_READ | darwin.PROT_WRITE,
			darwin.MAP_ANONYMOUS | darwin.MAP_PRIVATE,
			-1,
			0,
		),
	)
	procedure_context.callee_stack.stack_size = (uintptr)(stack_size)
	procedure_context.callee_stack.stack_base =
		procedure_context.callee_stack.stack_address + (uintptr)(stack_size) - size_of(uintptr)

	log.infof("Will use stack at address %x", procedure_context.callee_stack.stack_address)
	log.infof("Starting from address %x", procedure_context.callee_stack.stack_base)

	_asmcall(
		procedure_context,
		procedure_address,
		procedure_parameter,
		procedure_context_parameter,
	)
}

_yield :: #force_inline proc(procedure_context: ^Procedure_Context) {
	_asmyield(procedure_context)
}

_resume :: #force_inline proc(procedure_context: ^Procedure_Context) {
	_asmresume(procedure_context)
}

_force_return :: #force_inline proc(procedure_context: ^Procedure_Context) -> ! {
	_asmforce_return(procedure_context)
}

_procedurecontext_free :: #force_inline proc(procedure_context: ^Procedure_Context) {
	darwin.syscall_munmap(
		(rawptr)(procedure_context.callee_stack.stack_address),
		(u64)(procedure_context.callee_stack.stack_size),
	)
}

