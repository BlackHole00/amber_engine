package ae_common

import "base:runtime"
import "core:time"

Task_Id :: distinct u64
INVALID_TASK_ID :: (Task_Id)(max(u64))

INVALID_TIME :: time.Time{0}

Task_Priority :: enum {
	Low,
	Medium,
	High,
}

Task_Status :: enum {
	Queued,
	Running,
	Suspended,
	Finished,
	Unknown = 0,
}

Task_Proc :: #type proc(task: ^Task)

Task_Descriptor :: struct {
	user_index:             int,
	user_data:              rawptr,
	user_priority:          Task_Priority,
	user_context:           runtime.Context,
	task_proc:              Task_Proc,
	execute_on_main_thread: bool,
	// Does not free user data
	free_when_finished:     bool,
}

Task :: struct {
	using descriptor:    Task_Descriptor,
	identifier:          Task_Id,
	implementation_data: rawptr,
}

Task_Info :: struct {
	using descriptor:     Task_Descriptor,
	identifier:           Task_Id,
	status:               Task_Status,
	user_submission_time: time.Time,
	last_submission_time: time.Time,
	waiting_for_tasks:    []Task_Id,
	implementation_data:  rawptr,
}

