package amber_engine_scheduler

import "core:mem"
import "core:slice"
import "shared:amber_engine/utils"

Task_Executor :: struct {
	allocator:    mem.Allocator,
	current_task: ^utils.Arc(Task_Info),
	queues:       []^Task_Queue,
}

taskexecutor_init :: proc(
	executor: ^Task_Executor,
	queues: ..^Task_Queue,
	allocator := context.allocator,
) {
	context.allocator = allocator
	executor.allocator = allocator

	executor.queues = slice.clone(queues)
}

taskexecutor_free :: proc(executor: Task_Executor) {
	if executor.current_task != nil {
		utils.rc_drop(executor.current_task)
	}

	delete(executor.queues)
}

taskexecutor_serve :: proc(executor: ^Task_Executor) -> (did_find_any_task: bool) {
	task := taskexecutor_find_task(executor^)
	if task == nil {
		return false
	}

	return true
}

@(private = "file")
taskexecutor_find_task :: proc(executor: Task_Executor) -> (task: ^utils.Arc(Task_Info)) {
	for queue in executor.queues {
		task = taskqueue_pop(queue)

		if task != nil {
			return
		}
	}

	return
}

