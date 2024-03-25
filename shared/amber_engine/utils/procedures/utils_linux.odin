package amber_engine_scheduler_utils

import "base:runtime"
import "core:sys/linux"

// @source _asmcall is architecture dependant
@(private)
_call :: #force_inline proc(
	procedure_context: ^Procedure_Context,
	procedure_address: rawptr,
	procedure_parameter: rawptr,
	procedure_context_parameter: ^runtime.Context,
	stack_size: uint,
) {
	address, _ := linux.mmap(0, (uint)(stack_size), {.READ, .WRITE}, {.ANONYMOUS, .PRIVATE})

	procedure_context.callee_stack.stack_address = (uintptr)(address)
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
	linux.munmap(
		(rawptr)(procedure_context.callee_stack.stack_address),
		(uint)(procedure_context.callee_stack.stack_size),
	)
}

