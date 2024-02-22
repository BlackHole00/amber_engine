package amber_engine_scheduler

import "base:intrinsics"
import "base:runtime"
import "core:mem"
import "core:slice"
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

Task :: struct {
	// NOTE(Vicix): The ASM code assumes this is the first field
	procedure_context: Procedure_Context,
	user_ptr:          rawptr,
	user_index:        uint,
	task_context:      runtime.Context,
	return_value:      []byte,
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

@(private)
procedurecontext_free :: proc(procedure_context: ^Procedure_Context) {
	stacksnapshot_free(&procedure_context.callee_snapshot.stack)
}

task_free :: proc(task: ^Task) {
	procedurecontext_free(&task.procedure_context)

	if task.return_value != nil {
		delete(task.return_value)
	}
}

foreign context_utils {
	@(private)
	procedurecontext_yield :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	@(private)
	procedurecontext_call :: proc "stdcall" (Procedure_Context: ^Procedure_Context, address: rawptr, ctx: ^runtime.Context) ---
	@(private)
	procedurecontext_resume :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	@(private)
	procedurecontext_force_return :: proc "stdcall" (procedure_context: ^Procedure_Context) -> ! ---
}

task_call :: #force_inline proc(
	task: ^Task,
	procedure: $T,
) where intrinsics.type_is_proc(T) &&
	intrinsics.type_proc_parameter_count(T) == 1 &&
	intrinsics.type_proc_parameter_type(T, 0) == ^Task &&
	intrinsics.type_proc_return_count(T) == 0 {
	// NOTE(Vicix): task == &task.procedure_context
	procedurecontext_call(&task.procedure_context, (rawptr)(procedure), &task.task_context)
}

@(private)
task_yield_no_return_value :: #force_inline proc(task: ^Task) {
	procedurecontext_yield(&task.procedure_context)
}

@(private)
task_yield_with_return_value :: #force_inline proc(task: ^Task, return_value: any) {
	task_set_return_value(task, return_value)
	procedurecontext_yield(&task.procedure_context)
}

task_yield :: proc {
	task_yield_no_return_value,
	task_yield_with_return_value,
}

@(private)
task_force_return_no_return_value :: #force_inline proc(task: ^Task) -> ! {
	procedurecontext_force_return(&task.procedure_context)
}

@(private)
task_force_return_with_return_value :: #force_inline proc(task: ^Task, return_value: any) -> ! {
	task_set_return_value(task, return_value)
	procedurecontext_force_return(&task.procedure_context)
}

task_force_return :: proc {
	task_return_with_return_value,
	task_return_no_return_value,
}

task_return_no_return_value :: #force_inline proc(task: ^Task) {

}

task_return_with_return_value :: #force_inline proc(task: ^Task, return_value: any) {
	task_set_return_value(task, return_value)
}

task_return :: proc {
	task_return_no_return_value,
	task_return_with_return_value,
}

task_resume :: #force_inline proc(task: ^Task) {
	// NOTE(Vicix): task == &task.procedure_context
	procedurecontext_resume(&task.procedure_context)
}

@(private)
task_returned_value_rawptr :: #force_inline proc(task: ^Task) -> rawptr {
	return &task.return_value[0]
}

@(private)
task_returned_value_typed :: #force_inline proc($T: typeid, task: ^Task) -> ^T {
	return (^T)(&task.return_value[0])
}

task_returned_value :: proc {
	task_returned_value_rawptr,
	task_returned_value_typed,
}

@(private)
task_set_return_value :: proc(task: ^Task, return_value: any) {
	if task.return_value != nil {
		delete(task.return_value)
	}
	task.return_value = slice.clone(mem.any_to_bytes(return_value), task.task_context.allocator)
}

