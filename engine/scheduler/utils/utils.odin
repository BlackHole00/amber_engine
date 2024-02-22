package amber_engine_scheduler_utils

import "core:runtime"

Procedure_Context :: _Procedure_Context

procedurecontext_free :: #force_inline proc(procedure_context: ^_Procedure_Context) {
	_procedurecontext_free(procedure_context)
}

call :: #force_inline proc(
	procedure_context: ^Procedure_Context,
	procedure_address: rawptr,
	procedure_parameter: rawptr,
	procedure_context_parameter: ^runtime.Context,
) {
	_call(procedure_context, procedure_address, procedure_parameter, procedure_context_parameter)
}

yield :: #force_inline proc(procedure_context: ^Procedure_Context) {
	_yield(procedure_context)
}

resume :: #force_inline proc(procedure_context: ^Procedure_Context) {
	_resume(procedure_context)
}

force_return :: #force_inline proc(procedure_context: ^Procedure_Context) -> ! {
	_force_return(procedure_context)
}

