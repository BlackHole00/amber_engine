package amber_engine_scheduler_utils

import "base:intrinsics"
import "base:runtime"
import "core:mem"
import "engine:common"

// @(private)
_Procedure_Context :: struct {
	callee_snapshot:           Procedure_Snapshot,
	caller_registers_snapshot: Register_Snapshot,
	caller_stack_pointer:      uintptr,
}

@(private)
_procedurecontext_free :: proc(procedure_context: ^Procedure_Context) {
	stacksnapshot_free(&procedure_context.callee_snapshot.stack)
}

foreign import asm_utils "utils_amd64.s"
foreign asm_utils {
	@(private, link_name = "procedurecontext_call")
	_call :: proc "stdcall" (Procedure_Context: ^Procedure_Context, address: rawptr, parameter: rawptr, ctx: ^runtime.Context) ---
	@(private, link_name = "procedurecontext_yield")
	_yield :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	@(private, link_name = "procedurecontext_resume")
	_resume :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	@(private, link_name = "procedurecontext_force_return")
	_force_return :: proc "stdcall" (procedure_context: ^Procedure_Context) -> ! ---
}

@(private = "file")
Register_Type :: enum {
	Rdi,
	Rsi,
	Rbx,
	Rbp,
	R12,
	R13,
	R14,
	R15,
	Rip,
	Rsp,
}

@(private = "file")
SSE_Register_Type :: enum {
	XMM6,
	XMM7,
	XMM8,
	XMM9,
	XMM10,
	XMM11,
	XMM12,
	XMM13,
	XMM14,
	XMM15,
}

@(private = "file")
Register_Value :: i64
@(private = "file")
SSE_Register_Value :: i128

@(private = "file")
Register_Snapshot :: struct {
	register_statuses:     [Register_Type]Register_Value,
	see_register_statuses: [SSE_Register_Type]SSE_Register_Value,
}

@(private = "file")
Stack_Snapshot :: struct {
	stack: []byte,
}

@(private = "file")
Procedure_Snapshot :: struct {
	registers: Register_Snapshot,
	stack:     Stack_Snapshot,
}

@(export, private = "file")
create_stacksnapshot :: proc "stdcall" (
	stack_snapshot: ^Stack_Snapshot,
	stack_base: uintptr,
	current_stack: uintptr,
) {
	context = common.default_context()

	if stack_snapshot.stack != nil {
		delete(stack_snapshot.stack)
	}

	used_stack_size := (int)(stack_base - current_stack)

	stack_snapshot.stack = make([]byte, used_stack_size)
	mem.copy_non_overlapping(&stack_snapshot.stack[0], (rawptr)(current_stack), used_stack_size)
}

@(private = "file")
stacksnapshot_free :: proc "stdcall" (stack_snaphot: ^Stack_Snapshot) {
	context = common.default_context()
	delete(stack_snaphot.stack)
}

