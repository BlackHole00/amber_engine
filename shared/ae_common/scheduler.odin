package ae_common

import "core:mem"

Thread_Id :: distinct int

Scheduler_Queue_Task_Proc :: #type proc(task_descriptor: Task_Descriptor) -> Task_Id

Scheduler_Wait_For_Proc :: #type proc(task_ids: ..Task_Id, max_ms_wait_time := -1) -> bool
Scheduler_Get_Thread_Id_Proc :: #type proc() -> Thread_Id

Scheduler_Get_Task_Info_Proc :: #type proc(task_id: Task_Id) -> (Task_Info, bool)
Scheduler_Get_Task_Status_Proc :: #type proc(task_id: Task_Id) -> Task_Status
Scheduler_Free_Task_Proc :: #type proc(task_id: Task_Id) -> (Task_Info, bool)

Scheduler_Get_Task_Info_List_Proc :: #type proc(allocator: mem.Allocator) -> []Task_Info
Scheduler_Get_Thread_Count :: #type proc() -> int

// Example of use:

// print('a'), sleep 1s and then print('b')
// Async_Proc_1_Stage :: enum int {
// 	Print_A,
// 	Print_B,
// }
// async_proc_1 :: proc(task_id: Task_Id, task_descriptor: ^Task_Descriptor) -> Task_Result {
// 	switch (Async_Proc_1_Stage)(task_descriptor.user_index) {
// 	case .Print_A:
// 		log.info("a")

// 		task_descriptor.user_index = (int)(Async_Proc_1_Stage.Print_B)
// 		return Task_Result_Sleep{time.duration_seconds(1)}

// 	case .Print_B:
// 		log.info("b")
// 		return Task_Result_Finished{}
// 	}
// }

