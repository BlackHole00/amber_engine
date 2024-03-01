package amber_engine_scheduler

import pq "core:container/priority_queue"
import "core:container/queue"
import "core:mem"
import "core:sync"
import "core:time"
import "engine:common"

Task_Queue :: struct {
	allocator:                mem.Allocator,
	ready_tasks:              queue.Queue(^common.Arc(Task_Info)),
	ready_tasks_mutex:        sync.Mutex,
	time_waiting_tasks:       pq.Priority_Queue(^common.Arc(Task_Info)),
	time_waiting_tasks_mutex: sync.Mutex,
	task_waiting_tasks:       map[Task_Id]common.Small_Dyn_Array(^common.Arc(Task_Info)),
	task_waiting_tasks_mutex: sync.Mutex,
}

taskqueue_init :: proc(task_queue: ^Task_Queue, allocator := context.allocator) {
	context.allocator = allocator
	task_queue.allocator = allocator

	queue.init(&task_queue.ready_tasks)
	pq.init(&task_queue.time_waiting_tasks, priorityqueue_less, priorityqueue_swap)

	task_queue.task_waiting_tasks = make(
		map[Task_Id]common.Small_Dyn_Array(^common.Arc(Task_Info)),
	)
}

taskqueue_push_ready :: proc(task_queue: ^Task_Queue, task: ^common.Arc(Task_Info)) {
	sync.guard(&task_queue.ready_tasks_mutex)

	queue.push(&task_queue.ready_tasks, task)
}

taskqueue_push_time_waiting :: proc(task_queue: ^Task_Queue, task: ^common.Arc(Task_Info)) {
	sync.guard(&task_queue.ready_tasks_mutex)

	pq.push(&task_queue.time_waiting_tasks, task)
}

taskqueue_push_task_waiting :: proc(
	task_queue: ^Task_Queue,
	task: ^common.Arc(Task_Info),
	awaits: []Task_Id,
) {
	context.allocator = task_queue.allocator

	// TODO(Vicix):
	assert(len(awaits) > 0)

	waiting_count: uint = 0
	if sync.guard(&task_queue.task_waiting_tasks_mutex) {
		to_remove := make([dynamic]Task_Id)
		defer delete(to_remove)

		for id in awaits {
			// Check if a task is finished or invalid.
			task_info := common.resourcemanager_get(&scheduler.task_manager, id)
			if task_info == nil {
				continue
			}
			defer common.rc_drop(task_info)

			if sync.atomic_load(&task_info.status) == .Finished {
				continue
			}

			waiting_tasks, ok := task_queue.task_waiting_tasks[id]
			if !ok {
				common.smalldynarray_init(&waiting_tasks, 1)
				task_queue.task_waiting_tasks[id] = waiting_tasks
			}

			common.smalldynarray_append(&waiting_tasks, task)
			waiting_count += 1
		}
	}

	sync.atomic_store(&task.waiting_count, waiting_count)
	if waiting_count == 0 {
		taskqueue_push_ready(task_queue, task)
	}
}

taskqueue_pop :: proc(task_queue: ^Task_Queue) -> ^common.Arc(Task_Info) {
	context.allocator = task_queue.allocator

	time_waiting_ready := make([dynamic]^common.Arc(Task_Info))
	defer delete(time_waiting_ready)

	now := time.now()

	if sync.guard(&task_queue.time_waiting_tasks_mutex) {
		for {
			task, ok := pq.peek_safe(task_queue.time_waiting_tasks)

			if !ok || time.diff(task.resume_time, now) > 0 {
				break
			}

			pq.pop(&task_queue.time_waiting_tasks)
			append(&time_waiting_ready, task)
		}
	}

	if sync.guard(&task_queue.ready_tasks_mutex) {
		for task in time_waiting_ready {
			queue.push(&task_queue.ready_tasks, task)
		}

		// NOTE(Vicix): task is nil if the queue is empty
		task, _ := queue.pop_front_safe(&task_queue.ready_tasks)
		return task
	}

	// unreachable
	return nil
}

taskqueue_mark_as_finished :: proc(task_queue: ^Task_Queue, finished_task: Task_Id) {
	context.allocator = task_queue.allocator

	ready_tasks := make([dynamic]^common.Arc(Task_Info))
	defer delete(ready_tasks)

	if sync.guard(&task_queue.task_waiting_tasks_mutex) {
		waiting_tasks, ok := task_queue.task_waiting_tasks[finished_task]

		if !ok {
			return
		}

		i := 0
		removed_count := 0
		for {
			waiting_task := common.smalldynarray_as_slice(waiting_tasks)[i - removed_count]

			// NOTE(Vicix): This isn't a rage condition: the only other part of
			//              the code that requires a lock on a waiting task is
			//              when the user fetches the task info. That lock
			//              does not require any other lock that might cause a 
			//              dead lock. Tldr: This lock is (currently) safe
			old_count := sync.atomic_sub(&waiting_task.waiting_count, 1)
			if old_count == 1 {
				append(&ready_tasks, waiting_task)
				common.smalldynarray_remove_index(&waiting_tasks, i)
				removed_count += 1
			}

			i += 1
		}
	}

	if sync.guard(&task_queue.ready_tasks_mutex) {
		for ready_task in ready_tasks {
			queue.push(&task_queue.ready_tasks, ready_task)
		}
	}
}

@(private = "file")
priorityqueue_less :: proc(a: ^common.Arc(Task_Info), b: ^common.Arc(Task_Info)) -> bool {
	return time.diff(a.resume_time, b.resume_time) < 0
}

@(private = "file")
priorityqueue_swap :: proc(q: []^common.Arc(Task_Info), i: int, j: int) {
	tmp := q[i]
	q[i] = q[j]
	q[j] = tmp
}

