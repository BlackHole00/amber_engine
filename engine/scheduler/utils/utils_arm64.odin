package amber_engine_scheduler_utils

import "base:runtime"
import "core:log"
import "core:mem"
import "engine:common"

Register_Type :: enum {
	X18,
	X19,
	X20,
	X21,
	X22,
	X23,
	X24,
	X25,
	X26,
	X27,
	X28,
	Fp,
	Lr,
	Sp,
	Ip,
}

Simd_Register_Type :: enum {
	V8,
	V9,
	V10,
	V11,
	V12,
	V13,
	V14,
	V15,
}

Register_Snapshot :: struct {
	register_statuses:      [Register_Type]Register_Value,
	simd_register_statuses: [Simd_Register_Type]Lower_Float_Register_Value,
	fpcr_status:            Register_Value,
}

_Procedure_Context :: struct {
	callee_snapshot:  Procedure_Snapshot,
	caller_registers: Register_Snapshot,
}

// REGISTER_SIZE :: 8
Register_Value :: uintptr
Float_Register_Value :: i128
Lower_Float_Register_Value :: uintptr

foreign import asm_utils "utils_arm64.s"
foreign asm_utils {
	@(link_name="call")
	_call :: proc "c" (Procedure_Context: ^Procedure_Context, address: rawptr, parameter: rawptr, ctx: ^runtime.Context) ---
	@(link_name="yield")
	_yield :: proc "c" (procedure_context: ^Procedure_Context) ---
	@(link_name="resume")
	_resume :: proc "c" (procedure_context: ^Procedure_Context) ---
	@(link_name="force_return")
	_force_return :: proc "c" (procedure_context: ^Procedure_Context) -> ! ---
}

@(export, private = "file")
stacksnapshot_create :: proc "c" (
	stack_snapshot: ^Stack_Snapshot,
	stack_base: uintptr,
	current_stack: uintptr,
	link_return_to_caller: uintptr,
	caller_frame_pointer: uintptr,
) {
	context = common.default_context()

	if stack_snapshot.stack != nil {
		delete(stack_snapshot.stack)
	}

	log.infof("will copy from %x to %x", current_stack, stack_base)
	used_stack_size := (int)(stack_base - current_stack)

	stack_snapshot.stack = make([]byte, used_stack_size)
	mem.copy_non_overlapping(&stack_snapshot.stack[0], (rawptr)(current_stack), used_stack_size)

	stack_as_uintprts := mem.slice_data_cast([]uintptr, stack_snapshot.stack)
	stack_as_uintprts_len := len(stack_as_uintprts)
	stack_as_uintprts[stack_as_uintprts_len - 1] = link_return_to_caller
	stack_as_uintprts[stack_as_uintprts_len - 2] = caller_frame_pointer

	log.infof("will return at %x", link_return_to_caller)
}

@(private = "file")
stacksnapshot_free :: proc "c" (stack_snapshot: ^Stack_Snapshot) {
	context = common.default_context()

	if stack_snapshot.stack != nil {
		delete(stack_snapshot.stack)
	}
}

Stack_Snapshot :: struct {
	// Teorically the stack should be aligned to 128 bits
	stack: []byte,
}

Procedure_Snapshot :: struct {
	register_snapshot: Register_Snapshot,
	stack_snapshot:    Stack_Snapshot,
}

_procedurecontext_free :: proc(procedure_context: ^Procedure_Context) {
	stacksnapshot_free(&procedure_context.callee_snapshot.stack_snapshot)
}

