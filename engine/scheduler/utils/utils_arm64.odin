package amber_engine_scheduler_utils

import "base:runtime"

// Register_Snapshot saves the states of the needed registers in order to be
// able to resume a procedure.
// Only the non-volatile registers defined by the c calling convention are saved
@(private)
_Register_Snapshot :: struct {
	register_statuses:      [Register_Type]Register_Value,
	simd_register_statuses: [Simd_Register_Type]Lower_Simd_Register_Value,
	fpcr_status:            Register_Value,
}

foreign import asm_utils "utils_arm64.s"
foreign asm_utils {
	@(private, link_name = "asmcall")
	_asmcall :: proc "c" (Procedure_Context: ^Procedure_Context, address: rawptr, parameter: rawptr, ctx: ^runtime.Context) ---
	@(private, link_name = "asmyield")
	_yield :: proc "c" (procedure_context: ^Procedure_Context) ---
	@(private, link_name = "asmresume")
	_resume :: proc "c" (procedure_context: ^Procedure_Context) ---
	@(private, link_name = "asmforce_return")
	_force_return :: proc "c" (procedure_context: ^Procedure_Context) -> ! ---
	@(private, link_name = "asmget_stack_pointer")
	_get_stack_pointer :: proc "c" () -> uintptr ---
}

@(private = "file")
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
}

@(private = "file")
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

@(private = "file")
Register_Value :: uintptr
@(private = "file")
Simd_Register_Value :: i128
@(private = "file")
Lower_Simd_Register_Value :: uintptr

