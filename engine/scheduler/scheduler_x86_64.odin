package amber_engine_scheduler

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

	used_stack_size := (int)(stack_base - current_stack)
	// log.infof("Copying stack: %x %x (%d bytes)", stack_base, current_stack, used_stack_size)
	// log.infof(
	// 	"Will copy from %x to %x (inclusive)",
	// 	current_stack,
	// 	current_stack + (uintptr)(used_stack_size - 8),
	// )
	// log.infof("Detected main link return: %16x", (transmute(^uintptr)(stack_base - 8))^)
	// log.infof("Detected first link return: %16x", (transmute(^uintptr)(current_stack))^)

	if stack_snapshot^ != nil {
		delete(stack_snapshot^)
	}

	stack_snapshot^ = make([]byte, used_stack_size)
	mem.copy_non_overlapping(&stack_snapshot^[0], (rawptr)(current_stack), used_stack_size)

	// log.infof(
	// 	"Copyied link return: %16x",
	// 	mem.slice_data_cast([]uintptr, stack_snapshot^)[used_stack_size / 8 - 1],
	// )
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
	@(private)
	get_stack_pointer :: proc "none" () -> uintptr ---
	@(private)
	get_location_of_this_instruction :: proc "none" () -> uintptr ---
	@(private)
	get_location_of_next_instruction :: proc "none" () -> uintptr ---
	@(private)
	advanced_jump :: proc "stdcall" (jmp_target: uintptr, stack_pointer_target: uintptr) ---
	@(private)
	simple_jump :: proc "stdcall" (jmp_target: uintptr) ---
	@(private)
	create_proceduresnapshot :: proc "stdcall" (snapshot: ^Procedure_Snapshot, stack_base: uintptr, return_instruction: uintptr = 0, current_stack: uintptr = 0) ---
	@(private)
	restore_proceduresnapshot :: proc "stdcall" (snapshot: ^Procedure_Snapshot, stack_base: uintptr) ---
	yield :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	call :: proc "stdcall" (Procedure_Context: ^Procedure_Context, address: rawptr) ---
	resume :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
}

