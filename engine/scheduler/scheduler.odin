package amber_engine_scheduler

import "core:log"
import "core:mem"
import "core:os"
import aec "shared:ae_common"

Task_Descriptor :: aec.Task_Descriptor
Task_Info :: aec.Task_Info
Task_Id :: aec.Task_Id
Task_Result :: aec.Task_Result
Thread_Id :: aec.Thread_Id

Scheduler_Descriptor :: struct {
	thread_count: int,
}

Scheduler :: struct {
	allocator: mem.Allocator,
	threads:   []Scheduler_Thread,
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
				   thread_id = (Thread_Id)(idx),
			   },
		   ) {
			log.errorf("Could not init thread")
			return false
		}
	}

	return true
}

scheduler_free :: proc(scheduler: Scheduler) {
	context.allocator = scheduler.allocator

	schedulerthread_join_multiple(..scheduler.threads)
	for thread in scheduler.threads {
		schedulerthread_free(thread)
	}

	delete(scheduler.threads)
}

scheduler_start :: proc(scheduler: ^Scheduler) {
	for &thread in scheduler.threads {
		schedulerthread_start(&thread)
	}
}

scheduler_get_thread_count :: proc(scheduler: Scheduler) -> int {
	return len(scheduler.threads) + 1
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

