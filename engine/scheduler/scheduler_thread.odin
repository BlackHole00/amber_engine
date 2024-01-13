//+private
package amber_engine_scheduler

import "core:log"
import "core:mem"
import "core:sync"
import "core:thread"

_ :: sync

Scheduler_Thread_Status :: enum {
	Ready,
	Running,
	Should_Stop,
	Stopped,
}

Scheduler_Thread_Descriptor :: struct {
	scheduler:      ^Scheduler,
	priority:       thread.Thread_Priority,
	thread_idx:     int,
	is_main_thread: bool,
}

Scheduler_Thread :: struct {
	allocator:      mem.Allocator,
	scheduler:      ^Scheduler,
	// @index_of: scheduler.threads
	thread_idx:     int,
	priority:       thread.Thread_Priority,
	status:         Scheduler_Thread_Status,
	is_main_thread: bool,
	thread:         ^thread.Thread,
}

schedulerthread_init :: proc(
	scheduler_thread: ^Scheduler_Thread,
	descriptor: Scheduler_Thread_Descriptor,
	allocator := context.allocator,
) -> bool {
	context.allocator = allocator
	scheduler_thread.allocator = allocator

	if descriptor.thread_idx > scheduler_get_thread_count(descriptor.scheduler^) {
		log.errorf("The provided thread idx %d is not valid", descriptor.thread_idx)
		return false
	}
	scheduler_thread.thread_idx = descriptor.thread_idx

	if descriptor.is_main_thread && scheduler_has_main_thread(descriptor.scheduler^) {
		log.errorf("The user is trying to register a main thread whilst it is already registered")
		return false
	}
	scheduler_thread.is_main_thread = descriptor.is_main_thread

	scheduler_thread.priority = descriptor.priority
	scheduler_thread.thread = thread.create(schedulerthread_thread_proc, descriptor.priority)
	if scheduler_thread.thread == nil {
		log.error("Could not create a thread")
		return false
	}

	scheduler_thread.thread.user_args[0] = scheduler_thread
	// Also uses provided allocator
	scheduler_thread.thread.init_context = context
	scheduler_thread.status = .Ready

	return true
}

schedulerthread_start :: proc(scheduler_thread: ^Scheduler_Thread) {
	scheduler_thread.status = .Running
	thread.start(scheduler_thread.thread)
}

schedulerthread_join :: proc(scheduler_thread: Scheduler_Thread) {
	thread.join(scheduler_thread.thread)
}

schedulerthread_join_multiple :: proc(scheduler_threads: ..Scheduler_Thread) {
	raw_threads := make([]^thread.Thread, len(scheduler_threads))
	defer delete(raw_threads)

	started_threads := 0
	for &scheduler_thread in scheduler_threads {
		if sync.atomic_load(&scheduler_thread.status) == .Running {
			sync.atomic_store(&scheduler_thread.status, .Should_Stop)

			raw_threads[started_threads] = scheduler_thread.thread
			started_threads += 1
		}
	}

	thread.join_multiple(..raw_threads[:started_threads])
}

// @usage: Should be called after `schedulerthread_join` or `schedulerthread_join_multiple`
schedulerthread_free :: proc(scheduler_thread: Scheduler_Thread) {
	// thread.destroy also joins the thread
	free(scheduler_thread.thread, scheduler_thread.thread.creation_allocator)
}

schedulerthread_thread_proc :: proc(thr: ^thread.Thread) {
	data := (^Scheduler_Thread)(thr.user_args[0])

	log.infof("Hello from Scheduler_Thread %d", data.thread_idx)

	for sync.atomic_load(&data.status) != .Should_Stop {

	}
}

