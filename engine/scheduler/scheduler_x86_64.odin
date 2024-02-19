package amber_engine_scheduler

import "core:log"
import "core:mem"
import "engine:common"

foreign import context_utils "context_x86_64.s"

Register_Type :: enum {
	Rdi,
	Rsi,
	Rbx,
	Rbp,
	Rsp,
	R12,
	R13,
	R14,
	R15,
	Rip,
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

Register_Value :: i64
SSE_Register_Value :: i128

Procedure_Context :: struct #packed {
	register_statuses:          [Register_Type]Register_Value,
	see_register_statuses:      [SSE_Register_Type]SSE_Register_Value,
	stack_start_address:        uintptr,
	return_instruction_pointer: uintptr,
	return_stack_address:       uintptr,
	stack:                      []byte,
}

@(export)
procedurecontext_save_stack :: proc "stdcall" (
	procedure_context: ^Procedure_Context,
	current_stack_address: uintptr,
) {
	context = common.default_context()

	used_stack_size := (int)(procedure_context.stack_start_address - current_stack_address)
	log.infof(
		"Used stack: %x - %x (%d bytes)",
		current_stack_address,
		procedure_context.stack_start_address,
		used_stack_size,
	)
	log.infof("Stack dump:")
	for i in 0 ..= (used_stack_size / 8) {
		current_address := current_stack_address + (uintptr)(i * 8)
		log.infof(
			"\t%x = %16x (%2x %2x %2x %2x %2x %2x %2x %2x)",
			current_address,
			(transmute(^u64)(current_address))^,
			(transmute(^byte)(current_address + 0))^,
			(transmute(^byte)(current_address + 1))^,
			(transmute(^byte)(current_address + 2))^,
			(transmute(^byte)(current_address + 3))^,
			(transmute(^byte)(current_address + 4))^,
			(transmute(^byte)(current_address + 5))^,
			(transmute(^byte)(current_address + 6))^,
			(transmute(^byte)(current_address + 7))^,
		)
	}

	log.infof("Reference points:")
	log.infof("\tCurrent stack pointer:\t\t%x", get_stack_pointer())
	log.infof("\tyield procedure address:\t%x", transmute(uintptr)(yield))
	log.infof("\trestore procedure address:\t%x", transmute(uintptr)(restore))
	log.infof("\treturn instruction pointer:\t%x", procedure_context.return_instruction_pointer)
	log.infof("\treturn stack pointer:\t\t%x", procedure_context.return_stack_address)

	if procedure_context.stack != nil {
		delete(procedure_context.stack)
	}

	procedure_context.stack = make([]byte, used_stack_size)
	mem.copy_non_overlapping(
		&procedure_context.stack[0],
		(rawptr)(current_stack_address),
		used_stack_size,
	)
}

foreign context_utils {
	get_stack_pointer :: proc "none" () -> uintptr ---
	get_location_of_this_instruction :: proc "none" () -> uintptr ---
	get_location_of_next_instruction :: proc "none" () -> uintptr ---
	advanced_jump :: proc "stdcall" (jmp_target: uintptr, stack_pointer_target: uintptr) ---
	simple_jump :: proc "stdcall" (jmp_target: uintptr) ---
	yield :: proc "stdcall" (procedure_context: ^Procedure_Context) ---
	restore :: proc "stdcall" (procedure_context: ^Procedure_Context, new_stack_base: uintptr) ---
}

