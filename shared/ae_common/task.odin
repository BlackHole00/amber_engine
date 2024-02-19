package ae_common

// import "core:mem"
// import "core:time"

// Task_Id :: distinct u64
// INVALID_TASK_ID :: (Task_Id)(max(u64))

// Task_Result_Repeat_After :: struct {
// 	duration: time.Duration,
// }
// Task_Result_Repeat :: struct {}
// Task_Result_Sleep :: struct {
// 	duration: time.Duration,
// }
// Task_Result_Yield :: struct {}
// //TODO(Vicix): Handle this better
// Task_Result_Wait_For :: struct {
// 	tasks:           []Task_Id,
// 	_internal_tasks: [4]Task_Id,
// }
// Task_Result_Finished :: struct {}
// Task_Result :: union {
// 	Task_Result_Finished,
// 	Task_Result_Yield,
// 	Task_Result_Wait_For,
// 	Task_Result_Sleep,
// 	Task_Result_Repeat,
// 	Task_Result_Repeat_After,
// }

// Task_Priority :: enum {
// 	Low,
// 	Medium,
// 	High,
// }

// Task_Status :: enum {
// 	Queued,
// 	Running,
// 	Suspended,
// 	Finished,
// 	Unknown = 0,
// }

// Task_Proc :: #type proc(task_id: Task_Id, task: ^Task_Descriptor) -> Task_Result

// Task_Descriptor :: struct {
// 	user_index:             int,
// 	user_data:              rawptr,
// 	user_priority:          Task_Priority,
// 	user_allocator:         mem.Allocator,
// 	task_proc:              Task_Proc,
// 	execute_on_main_thread: bool,
// 	// Does not free user data
// 	free_when_finished:     bool,
// }

// Task_Info :: struct {
// 	using descriptor:              Task_Descriptor,
// 	identifier:                    Task_Id,
// 	status:                        Task_Status,
// 	submission_time:               time.Time,
// 	last_suspended_execution_time: Maybe(time.Time),
// 	last_resumed_execution_time:   Maybe(time.Time),
// 	// nil if does not have a result yet
// 	last_result:                   Task_Result,
// 	//TODO(Vicix): Change into normal slice
// 	waiting_for_tasks:             []Task_Id,
// }

