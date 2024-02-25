package amber_engine_scheduler_utils

import "base:runtime"
import "core:log"
import "core:mem"

// Generally Odin's printing procedures take a lot of (stack) memory. A simple
// print procedure with a non struct parameter takes around 14 kilobytes of 
// stack. If we are below that we issue a warning. 2 kilobytes are left as 
// wiggle room
// TODO(Vicix): This system to check for stack overflow is really bad, since 
//              the program might crash without any warnings. In a normal 
//              program when a normal stack overflow occurs, at least it is 
//              possible to see the crash reason with a debugger. However with
//              this custom stack implementation a generic access violation
//              is generated
STACK_USAGE_THRESHOLD :: 16 * mem.Kilobyte

MINIMUM_SAFE_STACK_SIZE :: 256 * mem.Kilobyte

DEFAULT_STACK_SIZE :: 2 * mem.Megabyte

Procedure_Stack :: struct {
	stack_address: uintptr,
	stack_size:    uintptr,
	stack_base:    uintptr,
}

Procedure_Context :: struct {
	caller_registers: _Register_Snapshot,
	callee_registers: _Register_Snapshot,
	callee_stack:     Procedure_Stack,
}

procedurecontext_free :: #force_inline proc(procedure_context: ^Procedure_Context) {
	_procedurecontext_free(procedure_context)
}

call :: #force_inline proc(
	procedure_context: ^Procedure_Context,
	procedure_address: rawptr,
	procedure_parameter: rawptr,
	procedure_context_parameter: ^runtime.Context,
	stack_size: uint = DEFAULT_STACK_SIZE,
	location := #caller_location,
) {
	if stack_size < 2 * MINIMUM_SAFE_STACK_SIZE {
		log.warnf(
			"A procedure is being called with a really low stack size (%d bytes). Consider using *at least* %d bytes",
			stack_size,
			MINIMUM_SAFE_STACK_SIZE,
			location = location,
		)
	}

	_call(
		procedure_context,
		procedure_address,
		procedure_parameter,
		procedure_context_parameter,
		stack_size,
	)
}

yield :: #force_inline proc(procedure_context: ^Procedure_Context) {
	bytes_remaining := _get_stack_pointer() - procedure_context.callee_stack.stack_address
	if _get_stack_pointer() < procedure_context.callee_stack.stack_address {
		log.panicf("Stack overflow in Procedure_Context %x", (uintptr)(procedure_context))
	} else if bytes_remaining < STACK_USAGE_THRESHOLD {
		log.warnf(
			"The Procedure_Context %x is about to stack overflow. Only %d bytes remaining",
			(uintptr)(procedure_context),
			bytes_remaining,
		)
	}

	_yield(procedure_context)
}

resume :: #force_inline proc(procedure_context: ^Procedure_Context) {
	_resume(procedure_context)
}

force_return :: #force_inline proc(procedure_context: ^Procedure_Context) -> ! {
	bytes_remaining := _get_stack_pointer() - procedure_context.callee_stack.stack_address
	if _get_stack_pointer() < procedure_context.callee_stack.stack_address {
		log.panicf("Stack overflow in Procedure_Context %x", (uintptr)(procedure_context))
	} else if bytes_remaining < STACK_USAGE_THRESHOLD {
		log.warnf(
			"The Procedure_Context %x is about to stack overflow. Only %d bytes remaining",
			(uintptr)(procedure_context),
			bytes_remaining,
		)
	}

	_force_return(procedure_context)
}

