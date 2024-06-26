package amber_engine_utils_procedures

import "base:intrinsics"
import "base:runtime"

// Register_Snapshot saves the states of the needed registers in order to be
// able to resume a procedure.
// Only the non-volatile registers defined by the stdcall calling convention
// are saved
@(private)
_Register_Snapshot :: struct {
	register_statuses:     [Register_Type]Register_Value,
	see_register_statuses: [SSE_Register_Type]SSE_Register_Value,
}

foreign import asm_utils "utils_amd64.s"
foreign asm_utils {
	@(private, link_name = "_asmcall")
	_asmcall :: proc "stdcall" (Procedure_Context: ^Procedure_Context, address: rawptr, parameter: rawptr, ctx: ^runtime.Context) ---
	@(private, link_name = "_asmyield")
	_yield :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	@(private, link_name = "_asmresume")
	_resume :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	@(private, link_name = "_asmforce_return")
	_force_return :: proc "stdcall" (procedure_context: ^Procedure_Context) -> ! ---
	@(private, link_name = "_asmget_stack_pointer")
	_get_stack_pointer :: proc "stdcall" () -> uintptr ---
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

