package amber_engine_utils_procedures

import "base:runtime"
import win "core:sys/windows"

// @source _asmcall is architecture dependant
@(private)
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

	_asmcall(
		procedure_context,
		procedure_address,
		procedure_parameter,
		procedure_context_parameter,
	)
}

@(private)
_procedurecontext_free :: #force_inline proc(procedure_context: ^Procedure_Context) {
	win.VirtualFree(
		transmute(rawptr)(procedure_context.callee_stack.stack_address),
		0,
		win.MEM_RELEASE,
	)
}

