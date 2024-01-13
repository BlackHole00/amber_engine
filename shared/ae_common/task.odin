package ae_common

import "core:mem"

Task_Id :: distinct u64
INVALID_TASK_ID :: (Task_Id)(max(u64))

Task_Result :: Common_Result

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

Task_Type_Run_Once :: struct {}
Task_Type_Endless :: struct {}
Task_Type_With_Intervall :: struct {
	ms_interval: uint,
}
Task_Type :: union {
	Task_Type_Run_Once,
	Task_Type_Endless,
	Task_Type_With_Intervall,
}

Task_Proc :: #type proc(task_id: Task_Id, task: ^Task_Descriptor) -> Task_Result

Task_Descriptor :: struct {
	user_index:     int,
	user_data:      rawptr,
	user_priority:  Task_Priority,
	user_allocator: mem.Allocator,
	task_type:      Task_Type,
	task_proc:      Task_Proc,
}

Task_Info :: struct {
	using descriptor: Task_Descriptor,
	identifier:       Task_Id,
	status:           Task_Status,
}

