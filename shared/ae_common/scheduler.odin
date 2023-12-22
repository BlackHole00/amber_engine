package ae_common

import "core:mem"

Thread_Id :: distinct int

Scheduler_Add_Task_Proc :: #type proc(task_descriptor: Task_Descriptor) -> Task_Id
Scheduler_Remove_Task_Proc :: #type proc(task_id: Task_Id) -> bool

Scheduler_Wait_For_Proc :: #type proc(
	task_ids: ..Task_Id,
	max_ms_wait_time := -1,
) -> (
	did_wait: bool
)
Scheduler_Yield_Proc :: #type proc(yield_ptr: rawptr)
Scheduler_Get_Thread_Id_Proc :: #type proc() -> Thread_Id

Scheduler_Get_Task_Info_Proc :: #type proc(task_id: Task_Id) -> (Task_Info, bool)
Scheduler_Get_Task_Status_Proc :: #type proc(task_id: Task_Id) -> Task_Status

Scheduler_Gat_Task_Info_List_Proc :: #type proc(allocator: mem.Allocator) -> []Task_Info

