package amber_engine_scheduler

import "core:mem"
import "core:os"
import "core:sync"
import "engine:common"
import aec "shared:ae_common"

Scheduler_Descriptor :: struct {
	thread_count:                        uint,
	// If true allows the main thread to execute also tasks not designated for
	// the main thread.
	main_thread_dynamic_queue_selection: bool,
}

scheduler: struct {
	using configuration: Scheduler_Descriptor,
	allocator:           mem.Allocator,
	task_manager:        common.Resource_Manager(Task_Info, Task_Id),
	task_queue:          Task_Queue,
	main_task_queue:     Task_Queue,
}

init :: proc(descriptor: Scheduler_Descriptor, allocator := context.allocator) {
	context.allocator = allocator
	scheduler.allocator = allocator

	scheduler.configuration = descriptor

	common.resourcemanager_init(&scheduler.task_manager)
	taskqueue_init(&scheduler.task_queue)
	taskqueue_init(&scheduler.main_task_queue)

	thread_count, did_change := cap_thread_count(descriptor.thread_count)
	if did_change {
		scheduler.thread_count = thread_count
	}
}

free :: proc() {
	context.allocator = scheduler.allocator

	common.resourcemanager_free(scheduler.task_manager)
	taskqueue_init(&scheduler.task_queue)
	taskqueue_init(&scheduler.main_task_queue)
}

queue_task :: proc(task_descriptor: Task_Descriptor) -> Task_Id {
	id := common.resourcemanager_reserve_new(&scheduler.task_manager)

	task_info: Task_Info
	taskinfo_from_taskdescriptor(&task_info, task_descriptor, id)

	task := common.resourcemanager_resolve_reserved_and_get(&scheduler.task_manager, id, task_info)

	if task.execute_on_main_thread {
		taskqueue_push_ready(&scheduler.main_task_queue, task)
	} else {
		taskqueue_push_ready(&scheduler.task_queue, task)
	}

	return id
}

free_task :: proc(task_id: Task_Id) -> bool {
	task := common.resourcemanager_get(&scheduler.task_manager, task_id)
	if task == nil {
		return false
	}
	defer common.rc_drop(task)

	if sync.atomic_load(&task.status) == .Finished {
		common.resourcemanager_remove(&scheduler.task_manager, task_id)

		return true
	} else {
		sync.guard(&task.mutex)
		task.free_when_finished = true

		return true
	}
}

get_return_value :: proc(task_id: Task_Id, destination: []byte) -> bool {
	task := common.resourcemanager_get(&scheduler.task_manager, task_id)
	if task == nil {
		return false
	}
	defer common.rc_drop(task)

	if sync.guard(&task.mutex) {
		if len(task.return_value) != len(destination) {
			return false
		}

		mem.copy_non_overlapping(&destination[0], &task.return_value[0], len(destination))
	}

	return true
}

is_task_id_valid :: proc(task_id: Task_Id) -> bool {
	return common.resourcemanager_is_id_valid(&scheduler.task_manager, task_id)
}

get_task_info :: proc(
	task_id: Task_Id,
	allocator := context.allocator,
) -> (
	info: aec.Task_Info,
	ok: bool,
) {
	task := common.resourcemanager_get(&scheduler.task_manager, task_id)
	if task == nil {
		return
	}
	defer common.rc_drop(task)

	taskinfo_clone_to_aec(task, &info)
	return info, true
}

@(private)
cap_thread_count :: proc(thread_count: uint) -> (new_thread_count: uint, has_changed: bool) {
	if thread_count > (uint)(os.processor_core_count()) {
		return (uint)(os.processor_core_count()), true
	}

	return thread_count, false
}

