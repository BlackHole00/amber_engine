package tests_utils_procedures

import "core:testing"
import "shared:amber_engine/utils/procedures"

@(test)
yield_resume :: proc(test: ^testing.T) {
	yielding_procedure :: proc(pc: ^procedures.Procedure_Context) {
		procedures.yield(pc)
		procedures.yield(pc)
		procedures.yield(pc)
	}

	context.allocator, _ = SCOPED_MEM_CHECK(test)

	pc: procedures.Procedure_Context
	defer procedures.procedurecontext_free(&pc)
	procedure_context := context

	procedures.call(
		&pc,
		auto_cast yielding_procedure,
		&pc,
		&procedure_context,
	)
	procedures.resume(&pc)
	procedures.resume(&pc)
	procedures.resume(&pc)
}

@(test)
stack_corruption :: proc(test: ^testing.T) {
	Procedure_Argument :: struct {
		pc: ^procedures.Procedure_Context,
		test: ^testing.T,
	}

	yielding_procedure :: proc(args: ^Procedure_Argument) {
		x := 42
		procedures.yield(args.pc)

		testing.expect_value(args.test, x, 42)
		x = 24
		procedures.yield(args.pc)

		testing.expect_value(args.test, x, 24)
	}

	context.allocator, _ = SCOPED_MEM_CHECK(test)

	pc: procedures.Procedure_Context
	defer procedures.procedurecontext_free(&pc)

	argument := Procedure_Argument {
		pc = &pc,
		test = test,
	}
	procedure_context := context

	procedures.call(
		&pc,
		auto_cast yielding_procedure,
		&argument,
		&procedure_context,
	)
	procedures.resume(&pc)
	procedures.resume(&pc)
}

@(test)
context_preservation :: proc(test: ^testing.T) {
	yielding_procedure :: proc(pc: ^procedures.Procedure_Context) {
		a := new(int)
		procedures.yield(pc)

		b := new(int)
		free(a)
		procedures.yield(pc)

		c := new(int)
		free(b)
		procedures.yield(pc)

		free(c)
	}

	context.allocator, _ = SCOPED_MEM_CHECK(test)

	pc: procedures.Procedure_Context
	defer procedures.procedurecontext_free(&pc)
	procedure_context := context

	procedures.call(
		&pc,
		auto_cast yielding_procedure,
		&pc,
		&procedure_context,
	)
	procedures.resume(&pc)
	procedures.resume(&pc)
	procedures.resume(&pc)
	
}

@(test)
defer_statement :: proc(test: ^testing.T) {
	yielding_procedure :: proc(pc: ^procedures.Procedure_Context) {
		ptr := new(int)
		defer free(ptr)

		procedures.yield(pc)
		procedures.yield(pc)
		procedures.yield(pc)
	}

	context.allocator, _ = SCOPED_MEM_CHECK(test)

	pc: procedures.Procedure_Context
	defer procedures.procedurecontext_free(&pc)
	procedure_context := context

	procedures.call(
		&pc,
		auto_cast yielding_procedure,
		&pc,
		&procedure_context,
	)
	procedures.resume(&pc)
	procedures.resume(&pc)
	procedures.resume(&pc)
}

@(test)
force_return :: proc(test: ^testing.T) {
	yielding_procedure :: proc(pc: ^procedures.Procedure_Context) {
		procedures.force_return(pc)
	}

	context.allocator, _ = SCOPED_MEM_CHECK(test)

	pc: procedures.Procedure_Context
	defer procedures.procedurecontext_free(&pc)
	procedure_context := context

	procedures.call(
		&pc,
		auto_cast yielding_procedure,
		&pc,
		&procedure_context,
	)
}
