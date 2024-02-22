package ae_common

import "core:mem"
import "core:time"

Thread_Id :: distinct int

Scheduler_Queue_Task_Proc :: #type proc(task_descriptor: Task_Descriptor) -> Task_Id
Scheduler_Free_Task_Proc :: #type proc(task_id: Task_Id) -> bool

Scheduler_Yield_Proc :: #type proc(task: ^Task)
Scheduler_Return_Proc :: #type proc(task: ^Task)
Scheduler_Sleep_Proc :: #type proc(task: ^Task, duration: time.Duration)
Scheduler_Await_Proc :: #type proc(task: ^Task, tasks: []Task_Id)

Scheduler_Set_Return_Value_Proc :: #type proc(task: ^Task, return_value: []byte)
Scheduler_Get_Return_Value_Proc :: #type proc(task_id: Task_Id) -> []byte

Scheduler_Is_Task_Valid_Proc :: #type proc(task_id: Task_Id) -> bool
Scheduler_Get_Task_Info_Proc :: #type proc(task_id: Task_Id) -> (Task_Info, bool)

Scheduler_Get_Task_Info_List_Proc :: #type proc(allocator: mem.Allocator) -> []Task_Info
Scheduler_Get_Thread_Count :: #type proc() -> int

