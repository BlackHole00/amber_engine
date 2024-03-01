package amber_engine_scheduler

import "core:mem"
import "core:slice"
import "core:sync"
import "core:time"
import "engine:scheduler/utils"
import aec "shared:ae_common"

Task_Id :: aec.Task_Id
Task_Descriptor :: aec.Task_Descriptor
Task_Data :: aec.Task_Data

// @thread_safety: The field status is atomic. Every other read or write needs
//                 to lock the mutex
Task_Info :: struct {
	using base:          aec.Task_Info,
	implementation_data: Task_Implementation_Data,
	scheduler_allocator: mem.Allocator,
	procedure_context:   utils.Procedure_Context,
	mutex:               sync.Mutex,
	// @atomic
	waiting_count:       uint,
	waiting_for:         []Task_Id,
}

Task_Implementation_Data :: ^Task_Info

taskinfo_from_taskdescriptor :: proc(
	task_info: ^Task_Info,
	task_descriptor: Task_Descriptor,
	task_identifier: Task_Id,
	now := aec.INVALID_TIME,
	allocator := context.allocator,
) {
	now := now

	if now == aec.INVALID_TIME {
		now = time.now()
	}

	task_info.descriptor = task_descriptor
	task_info.identifier = task_identifier
	task_info.status = .Queued
	task_info.user_submission_time = now
	task_info.resume_time = now

	task_info.implementation_data.scheduler_allocator = allocator
}

taskinfo_clone_to_aec :: proc(
	task_info: ^Task_Info,
	aec_info: ^aec.Task_Info,
	allocator := context.allocator,
) {
	sync.guard(&task_info.mutex)

	aec_info^ = task_info.base

	aec_info.status = sync.atomic_load(&task_info.status)
	if task_info.return_value != nil {
		aec_info.return_value = slice.clone(task_info.return_value, allocator)
	}
}

taskdata_from_taskinfo :: proc(task_data: ^Task_Data, task_info: ^Task_Info) {
	task_data.descriptor = task_info.descriptor
	task_data.identifier = task_info.identifier

	task_data.implementation_data = (rawptr)(task_info)
}

taskinfo_call :: proc(task_info: ^Task_Info, task_data: ^Task_Data) {
	taskdata_from_taskinfo(task_data, task_info)

	sync.atomic_store(&task_info.status, .Running)
	utils.call(
		&task_info.implementation_data.procedure_context,
		(rawptr)(task_info.task_proc),
		(rawptr)(task_data),
		&task_info.user_context,
	)

	// NOTE(Vicix): If the status is still running, it means that the procedure
	//              returned normally, thus it finished
	sync.atomic_compare_exchange_strong(&task_info.status, .Running, .Finished)
}

taskdata_yield :: proc(task_data: ^Task_Data) {
	task_info := (^Task_Info)(task_data.implementation_data)
	sync.atomic_store(&task_info.status, .Suspended)

	utils.yield(&task_info.procedure_context)
}

taskdata_sleep :: proc(task_data: ^Task_Data, wait_time: time.Duration) {
	task_info := (^Task_Info)(task_data.implementation_data)

	if sync.guard(&task_info.mutex) {
		sync.atomic_store(&task_info.status, .Waiting_For_Time)
		task_info.resume_time = time.time_add(time.now(), wait_time)
	}

	utils.yield(&task_info.procedure_context)
}

taskdata_await :: proc(task_data: ^Task_Data, tasks: []Task_Id) {
	task_info := (^Task_Info)(task_data.implementation_data)
	context.allocator = task_info.scheduler_allocator

	if sync.guard(&task_info.mutex) {
		sync.atomic_store(&task_info.status, .Waiting_For_Tasks)

		// Should not happen
		if task_info.waiting_for != nil {
			delete(task_info.waiting_for)
		}
		task_info.waiting_for = slice.clone(tasks)
	}

	utils.yield(&task_info.procedure_context)
}

taskinfo_resume :: proc(task_info: ^Task_Info) {
	sync.atomic_store(&task_info.status, .Running)
	utils.resume(&task_info.procedure_context)
}

taskdata_force_return :: proc(task_data: ^Task_Data) -> ! {
	task_info := (^Task_Info)(task_data.implementation_data)
	sync.atomic_store(&task_info.status, .Finished)

	utils.force_return(&task_info.procedure_context)
}

taskdata_set_return_data :: proc(task_data: ^Task_Data, data: []byte) {
	task_info := (^Task_Info)(task_data.implementation_data)
	context.allocator = task_info.scheduler_allocator

	if sync.guard(&task_info.mutex) {
		if task_info.return_value != nil {
			delete(task_info.return_value)
		}
		task_info.return_value = slice.clone(data)
	}
}

taskinfo_get_return_data :: proc(
	task_info: ^Task_Info,
	destination: []byte,
	allocator := context.allocator,
) {
	if sync.guard(&task_info.mutex) {
		assert(len(task_info.return_value) == len(destination))

		mem.copy_non_overlapping(&destination[0], &task_info.return_value[0], len(destination))
	}
}

// taskinfo_handle_result :: proc(task_info: ^Task_Info) {
// 	context.allocator = task_info.implementation_data.scheduler_allocator

// 	sync.guard(&task_info.mutex)

// 	#partial switch task_info.implementation_data.return_status {
// 	case .Waiting_For_Tasks:
// 		// This should not happend
// 		if task_info.waiting_for_tasks != nil {
// 			task_info.waiting_for_tasks = nil
// 			delete(task_info.waiting_for_tasks)
// 		}

// 		waiting_for_tasks := make([dynamic]Task_Id)

// 		for waiting_task in task_info.implementation_data.waiting_tasks {
// 			if waiting_task == task_info.identifier {
// 				continue
// 			}

// 			waiting_task_info := common.resourcemanager_get(&scheduler.task_manager, waiting_task)
// 			if waiting_task_info == nil {
// 				continue
// 			}
// 			defer common.rc_drop(waiting_task_info)

// 			if waiting_task_info.status == .Finished {
// 				continue
// 			}

// 			append(&waiting_for_tasks, waiting_task)
// 		}
// 		delete(task_info.implementation_data.waiting_tasks)

// 		if len(waiting_for_tasks) == 0 {
// 			sync.atomic_store(&task_info.status, .Suspended)
// 			delete(waiting_for_tasks)
// 		} else {
// 			sync.atomic_store(&task_info.status, .Waiting_For_Tasks)
// 			task_info.waiting_for_tasks = waiting_for_tasks[:]
// 		}

// 	case .Waiting_For_Time:
// 		task_info.resume_time = time.time_add(time.now(), task_info.implementation_data.wait_time)
// 		sync.atomic_store(&task_info.status, .Waiting_For_Time)

// 	case .Finished:
// 		utils.procedurecontext_free(&task_info.implementation_data.procedure_context)
// 		sync.atomic_store(&task_info.status, .Finished)

// 	case .Suspended:
// 		sync.atomic_store(&task_info.status, .Suspended)

// 	case:
// 		unreachable()
// 	}
// }

