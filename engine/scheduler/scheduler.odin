package amber_engine_scheduler

import "core:log"
import "core:mem"
import "core:os"
import "core:sync"
import aec "shared:ae_common"

Task_Descriptor :: aec.Task_Descriptor
Task_Info :: aec.Task_Info
Task_Id :: aec.Task_Id

Scheduler_Descriptor :: struct {
	thread_count: int,
}

Scheduler :: struct {
	allocator:            mem.Allocator,
	threads:              []Scheduler_Thread,
	incremental_task_idx: uint,
	tasks:                map[Task_Id]Task_Info,
	tasks_mutex:          sync.Mutex,
}

scheduler_init :: proc(
	scheduler: ^Scheduler,
	descriptor: Scheduler_Descriptor,
	allocator := context.allocator,
) -> (
	ok: bool,
) {
	context.allocator = allocator
	scheduler.allocator = allocator

	thread_count, thread_count_was_higher := cap_thread_count(descriptor.thread_count)
	if thread_count_was_higher {
		log.warnf(
			"The requested thread count (%d) was too high for the machine. It will be adjusted to %d",
			descriptor.thread_count,
			thread_count,
		)
	}

	scheduler.threads = make([]Scheduler_Thread, thread_count)
	defer if !ok {
		delete(scheduler.threads)
	}

	for &thread, idx in scheduler.threads {
		if !schedulerthread_init(
			   &thread,
			   Scheduler_Thread_Descriptor {
				   scheduler = scheduler,
				   priority = .Normal,
				   thread_idx = idx,
			   },
		   ) {
			log.errorf("Could not init thread")
			return false
		}
	}

	scheduler.tasks = make(map[Task_Id]Task_Info)

	return true
}

scheduler_free :: proc(scheduler: Scheduler) {
	context.allocator = scheduler.allocator

	schedulerthread_join_multiple(..scheduler.threads)
	for thread in scheduler.threads {
		schedulerthread_free(thread)
	}

	delete(scheduler.threads)
	delete(scheduler.tasks)
}

scheduler_start :: proc(scheduler: ^Scheduler) {
	for &thread in scheduler.threads {
		schedulerthread_start(&thread)
	}
}

scheduler_add_task :: proc(scheduler: ^Scheduler, task_descriptor: Task_Descriptor) -> Task_Id {
	task_id := scheduler_get_task_id(scheduler)

	task_info := Task_Info {
		descriptor = task_descriptor,
		identifier = task_id,
		status     = .Queued,
	}
	if (sync.mutex_guard(&scheduler.tasks_mutex)) {
		scheduler.tasks[task_id] = task_info
	}

	return task_id
}

scheduler_get_thread_count :: proc(scheduler: Scheduler) -> int {
	return len(scheduler.threads) + 1
}

@(private)
scheduler_get_task_id :: proc(scheduler: ^Scheduler) -> Task_Id {
	return (Task_Id)(sync.atomic_add(&scheduler.incremental_task_idx, 1))
}

@(private)
scheduler_has_main_thread :: proc(scheduler: Scheduler) -> bool {
	for thread in scheduler.threads {
		if thread.is_main_thread {
			return true
		}
	}

	return false
}

@(private)
cap_thread_count :: proc(thread_count: int) -> (new_thread_count: int, has_changed: bool) {
	if thread_count > os.processor_core_count() {
		return os.processor_core_count(), true
	}

	return thread_count, false
}

