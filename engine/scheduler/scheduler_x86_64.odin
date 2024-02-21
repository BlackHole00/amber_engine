package amber_engine_scheduler

import "base:runtime"
import "core:mem"
import "engine:common"

foreign import context_utils "context_x86_64.s"

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

Register_Snapshot :: struct {
	register_statuses:     [Register_Type]Register_Value,
	see_register_statuses: [SSE_Register_Type]SSE_Register_Value,
}

Stack_Snapshot :: []byte

Procedure_Snapshot :: struct {
	registers: Register_Snapshot,
	stack:     Stack_Snapshot,
}

Register_Value :: i64
SSE_Register_Value :: i128

Procedure_Context :: struct {
	callee_snapshot:           Procedure_Snapshot,
	caller_registers_snapshot: Register_Snapshot,
	caller_stack_pointer:      uintptr,
}

@(export, private)
create_stacksnapshot :: proc "stdcall" (
	stack_snapshot: ^Stack_Snapshot,
	stack_base: uintptr,
	current_stack: uintptr,
) {
	context = common.default_context()

	if stack_snapshot^ != nil {
		delete(stack_snapshot^)
	}

	used_stack_size := (int)(stack_base - current_stack)

	stack_snapshot^ = make([]byte, used_stack_size)
	mem.copy_non_overlapping(&stack_snapshot^[0], (rawptr)(current_stack), used_stack_size)
}

@(private)
stacksnapshot_free :: proc "stdcall" (stack_snaphot: ^Stack_Snapshot) {
	context = common.default_context()
	delete(stack_snaphot^)
}

procedurecontext_free :: proc(procedure_context: ^Procedure_Context) {
	stacksnapshot_free(&procedure_context.callee_snapshot.stack)
}

foreign context_utils {
	odin_call :: proc "stdcall" (address: rawptr, #by_ptr ctx: runtime.Context) ---
	yield :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	call :: proc "stdcall" (Procedure_Context: ^Procedure_Context, address: rawptr, #by_ptr ctx: runtime.Context) ---
	resume :: proc "stdcall" (procedure_context: ^Procedure_Context, #by_ptr ctx: runtime.Context) ---
}

