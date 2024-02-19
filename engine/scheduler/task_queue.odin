package amber_engine_scheduler

// import pq "core:container/priority_queue"
// import "core:sync"
// import "core:time"
// import aec "shared:ae_common"

// @(private)
// TASK_PRIORITY_MODIFIERS := [?]f32 {
// 	aec.Task_Priority.Low    = 1,
// 	aec.Task_Priority.Medium = 2,
// 	aec.Task_Priority.High   = 3,
// }

// Task_Queue :: struct {
// 	queues:        [len(aec.Task_Priority)]pq.Priority_Queue(Task_Info),
// 	mutexes:       [len(aec.Task_Priority)]sync.Mutex,
// 	waiting_queue: pq.Priority_Queue(Task_Info),
// 	waiting_mutex: sync.Mutex,
// }

// taskqueue_init :: proc(task_queue: ^Task_Queue) {
// 	for &q in task_queue.queues {
// 		pq.init(&q, default_prioritylist_less, prioritylist_swap)
// 	}
// 	pq.init(&task_queue.waiting_queue, waiting_prioritylist_less, prioritylist_swap)
// }

// // @thread_safety: not thread safe
// taskqueue_free :: proc(task_queue: ^Task_Queue) {
// 	for &q in task_queue.queues {
// 		pq.destroy(&q)
// 	}
// 	pq.destroy(&task_queue.waiting_queue)
// }

// taskqueue_append :: proc(task_queue: ^Task_Queue, task: Task_Info) {
// 	if taskinfo_can_execute_task_now(task, false, time.now()) {
// 		if sync.mutex_guard(&task_queue.mutexes[task.user_priority]) {
// 			pq.push(&task_queue.queues[task.user_priority], task)
// 		}
// 	} else {
// 		if sync.mutex_guard(&task_queue.waiting_mutex) {
// 			pq.push(&task_queue.waiting_queue, task)
// 		}
// 	}
// }

// taskqueue_pop :: proc(task_queue: ^Task_Queue) -> (Task_Info, bool) {
// 	possible_tasks: [len(aec.Task_Priority)]Maybe(Task_Info)

// 	for &mutex, i in task_queue.mutexes {
// 		if sync.mutex_guard(&mutex) {
// 			task, ok := pq.pop_safe(&task_queue.queues[i])
// 			if ok {
// 				possible_tasks[i] = task
// 			}
// 		}
// 	}

// 	best_task_idx := -1
// 	best_task_importance_factor := min(f32)

// 	now := time.now()

// 	for task, i in possible_tasks {
// 		if task == nil {
// 			continue
// 		}

// 		factor := taskinfo_get_importance_factor(task.?, now)
// 		if factor > best_task_importance_factor {
// 			best_task_idx = i
// 			best_task_importance_factor = factor
// 		}
// 	}

// 	if best_task_idx == -1 {
// 		return {}, false
// 	}

// 	for task, i in possible_tasks {
// 		if i == best_task_idx {
// 			continue
// 		}

// 		if task == nil {
// 			continue
// 		}

// 		taskqueue_append(task_queue, task.?)
// 	}

// 	return possible_tasks[best_task_idx].?, true
// }

// taskqueue_check_waiting_tasks :: proc(task_queue: ^Task_Queue) {
// 	if sync.mutex_guard(&task_queue.waiting_mutex) {
// 		now := time.now()

// 		for {
// 			task, ok := pq.peek_safe(task_queue.waiting_queue)
// 			if !ok {
// 				return
// 			}

// 			if !taskinfo_can_execute_task_now(task, false, now) {
// 				return
// 			}

// 			//TODO(Vicix): This will not deadlock, but I really should improve the API
// 			taskqueue_append(task_queue, task)
// 			pq.pop(&task_queue.waiting_queue)
// 		}
// 	}
// }

// taskqueue_is_empty :: proc(task_queue: ^Task_Queue) -> bool {
// 	if sync.mutex_guard(&task_queue.waiting_mutex) {
// 		if pq.len(task_queue.waiting_queue) > 0 {
// 			return false
// 		}
// 	}

// 	for queue, i in task_queue.queues {
// 		if sync.mutex_guard(&task_queue.mutexes[i]) {
// 			if pq.len(queue) > 0 {
// 				return false
// 			}
// 		}
// 	}

// 	return true
// }

// taskqueue_is_task_present :: proc(task_queue: ^Task_Queue, task_id: Task_Id) -> bool {
// 	if sync.mutex_guard(&task_queue.waiting_mutex) {
// 		for task in task_queue.waiting_queue.queue {
// 			if task.identifier == task_id {
// 				return true
// 			}
// 		}
// 	}

// 	for queue, i in task_queue.queues {
// 		if sync.mutex_guard(&task_queue.mutexes[i]) {
// 			for task in queue.queue {
// 				if task.identifier == task_id {
// 					return true
// 				}
// 			}
// 		}
// 	}

// 	return false
// }

// @(private = "file")
// prioritylist_swap :: proc(q: []Task_Info, i, j: int) {
// 	tmp := q[i]
// 	q[i] = q[j]
// 	q[j] = tmp
// }

// @(private = "file")
// default_prioritylist_less :: proc(a, b: Task_Info) -> bool {
// 	a_value := time.to_unix_nanoseconds(a.submission_time)
// 	b_value := time.to_unix_nanoseconds(b.submission_time)

// 	if a.last_suspended_execution_time != nil {
// 		a_value = time.to_unix_nanoseconds(a.last_suspended_execution_time.?)
// 	}
// 	if b.last_suspended_execution_time != nil {
// 		b_value = time.to_unix_nanoseconds(b.last_suspended_execution_time.?)
// 	}

// 	return a_value < b_value
// }

// @(private = "file")
// waiting_prioritylist_less :: proc(a, b: Task_Info) -> bool {
// 	a_value := a.last_suspended_execution_time.?
// 	b_value := b.last_suspended_execution_time.?

// 	#partial switch v in a.last_result {
// 	case aec.Task_Result_Sleep:
// 		a_value = time.time_add(a_value, v.duration)
// 	case aec.Task_Result_Repeat_After:
// 		a_value = time.time_add(b_value, v.duration)
// 	}

// 	#partial switch v in b.last_result {
// 	case aec.Task_Result_Sleep:
// 		b_value = time.time_add(b_value, v.duration)
// 	case aec.Task_Result_Repeat_After:
// 		b_value = time.time_add(b_value, v.duration)
// 	}

// 	return time.duration_nanoseconds(time.diff(a_value, b_value)) > 0
// }

