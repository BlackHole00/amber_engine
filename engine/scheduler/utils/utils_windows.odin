package amber_engine_scheduler_utils

import "base:runtime"
import "core:log"
import win "core:sys/windows"

Procedure_Stack :: struct {
	stack_address: uintptr,
	stack_size:    uintptr,
	stack_base:    uintptr,
}
Register_Snapshot :: _Register_Snapshot

_call :: #force_inline proc(
	procedure_context: ^Procedure_Context,
	procedure_address: rawptr,
	procedure_parameter: rawptr,
	procedure_context_parameter: ^runtime.Context,
	stack_size: uint,
) {
	procedure_context.callee_stack.stack_address = (uintptr)(
		win.VirtualAlloc(nil, stack_size, win.MEM_COMMIT | win.MEM_RESERVE, win.PAGE_READWRITE),
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
	win.VirtualFree(
		transmute(rawptr)(procedure_context.callee_stack.stack_address),
		0,
		win.MEM_RELEASE,
	)
}

