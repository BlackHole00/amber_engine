package amber_engine_scheduler

// import "core:log"
// import "core:sync"
// import "core:time"
// import aec "shared:ae_common"

// Task_Manager :: struct {
// 	task_index_counter:              Task_Id,
// 	task_queue:                      Task_Queue,
// 	// Some tasks might not free automatically, but the user must request their
// 	// freeing. Those tasks will be stored in the completed_tasks field
// 	completed_tasks:                 map[Task_Id]Task_Info,
// 	completed_tasks_mutex:           sync.Mutex,
// 	// Every thread can only execute only one task at a time. The currently 
// 	// executed tasks are stored here
// 	currently_executing_tasks:       []Maybe(Task_Info),
// 	currently_executing_tasks_mutex: sync.Mutex,
// }

// taskmanager_init :: proc(manager: ^Task_Manager, thread_count: int) {
// 	// pq.init(&manager.tasks, priorityqueue_less, priorityqueue_swap)
// 	taskqueue_init(&manager.task_queue)
// 	manager.completed_tasks = make(map[Task_Id]Task_Info)
// 	manager.currently_executing_tasks = make([]Maybe(Task_Info), thread_count)
// }

// // @thread_safety: Not thread safe, call only on main engine deinitialization
// taskmanager_free :: proc(manager: ^Task_Manager) {
// 	taskqueue_free(&manager.task_queue)
// 	delete(manager.completed_tasks)
// 	delete(manager.currently_executing_tasks)
// }

// taskmanager_find_most_important_task :: proc(
// 	manager: ^Task_Manager,
// 	scheduler_thread: Scheduler_Thread,
// 	only_main_thread := false,
// ) -> (
// 	task_info: Task_Info,
// 	has_tasks: bool,
// ) {
// 	if only_main_thread {
// 		unimplemented()
// 	}

// 	return taskqueue_pop(&manager.task_queue)
// }

// taskmanager_has_tasks :: proc(manager: ^Task_Manager) -> bool {
// 	if !taskqueue_is_empty(&manager.task_queue) {
// 		return true
// 	}

// 	if sync.mutex_guard(&manager.currently_executing_tasks_mutex) {
// 		for task in manager.currently_executing_tasks {
// 			if task != nil {
// 				return true
// 			}
// 		}
// 	}

// 	return false
// }

// taskmanager_register_task :: proc(manager: ^Task_Manager, task: Task_Descriptor) -> Task_Id {
// 	task_id := taskmanager_get_new_task_id(manager)

// 	now := time.now()
// 	taskmanager_register_task_info(
// 		manager,
// 		Task_Info {
// 			descriptor = task,
// 			identifier = task_id,
// 			status = .Queued,
// 			submission_time = now,
// 		},
// 	)

// 	return task_id
// }

// taskmanager_is_task_valid :: proc(manager: ^Task_Manager, task_id: Task_Id) -> bool {
// 	return(
// 		taskmanager_is_task_completed(manager, task_id) ||
// 		taskmanager_is_task_queued(manager, task_id) ||
// 		taskmanager_is_task_currently_executing(manager, task_id) \
// 	)
// }

// taskmanager_is_task_completed :: proc(manager: ^Task_Manager, task_id: Task_Id) -> bool {
// 	if sync.mutex_guard(&manager.completed_tasks_mutex) {
// 		return task_id in manager.completed_tasks
// 	}

// 	unreachable()
// }

// taskmanager_free_task :: proc(manager: ^Task_Manager, task_id: Task_Id) -> (Task_Info, bool) {
// 	if !taskmanager_is_task_valid(manager, task_id) {
// 		log.error("The user requested freeing an invalid task")

// 		return {}, false
// 	}

// 	if sync.mutex_guard(&manager.completed_tasks_mutex) {
// 		deleted_key, deleted_task := delete_key(&manager.completed_tasks, task_id)

// 		if deleted_key != 0 {
// 			taskinfo_free(deleted_task)
// 			return deleted_task, true
// 		}
// 	}

// 	unimplemented()
// 	// if sync.mutex_guard(&manager.tasks_mutex) {
// 	// 	info := taskmanager_get_queued_task_ptr(manager, task_id)

// 	// 	if info != nil {
// 	// 		log.warn(
// 	// 			"The user requested freeing a task that is currently executing or queued up. It will instead be automatically freed when it will terminate",
// 	// 		)

// 	// 		info.free_when_finished = true
// 	// 		return info^, true
// 	// 	}
// 	// }

// 	// if sync.mutex_guard(&manager.currently_executing_tasks_mutex) {
// 	// 	info := taskmanager_get_currently_executing_task_ptr(manager, task_id)

// 	// 	if info != nil {
// 	// 		log.warn(
// 	// 			"The user requested freeing a task that is currently executing or queued up. It will instead be automatically freed when it will terminate",
// 	// 		)

// 	// 		info.free_when_finished = true
// 	// 		return info^, true
// 	// 	}
// 	// }

// 	// return {}, false
// }

// taskmanager_assign_new_task :: proc(
// 	manager: ^Task_Manager,
// 	scheduler_thread: Scheduler_Thread,
// 	previous_task_result: Task_Result,
// 	previous_task_descriptor: Task_Descriptor,
// ) -> (
// 	Task_Id,
// 	Task_Descriptor,
// ) {
// 	defer taskqueue_check_waiting_tasks(&manager.task_queue)

// 	// if sync.mutex_guard(&manager.task_queue.waiting_mutex) {
// 	// 	log.infof("%#v", manager.task_queue.waiting_queue.queue[:])
// 	// }

// 	previous_task: Maybe(Task_Info) = nil
// 	previous_task_result := previous_task_result

// 	next_task, has_tasks := taskmanager_find_most_important_task(
// 		manager,
// 		scheduler_thread,
// 		scheduler_thread.is_main_thread,
// 	)

// 	now := time.now()

// 	if !has_tasks {
// 		if sync.mutex_guard(&manager.currently_executing_tasks_mutex) {
// 			previous_task = manager.currently_executing_tasks[scheduler_thread.thread_id]
// 			manager.currently_executing_tasks[scheduler_thread.thread_id] = nil
// 		}
// 	} else if sync.mutex_guard(&manager.currently_executing_tasks_mutex) {
// 		next_task.last_resumed_execution_time = now
// 		next_task.status = .Running

// 		previous_task = manager.currently_executing_tasks[scheduler_thread.thread_id]
// 		manager.currently_executing_tasks[scheduler_thread.thread_id] = next_task
// 	}

// 	if previous_task != nil && previous_task_result == nil {
// 		log.error("Invalid previous task provided. Converting into Task_Result_Finished")
// 		previous_task_result = aec.Task_Result_Finished{}
// 	} else if previous_task == nil && previous_task_result != nil {
// 		log.error("Invalid previous task provided. Ignoring")
// 	}

// 	if previous_task == nil {
// 		if has_tasks {
// 			return next_task.identifier, next_task.descriptor
// 		}
// 		return aec.INVALID_TASK_ID, {}
// 	}

// 	new_previous_task := previous_task.?

// 	new_previous_task.last_result = previous_task_result
// 	new_previous_task.descriptor = previous_task_descriptor
// 	taskmanager_handle_executed_task(manager, new_previous_task)

// 	if has_tasks {
// 		return next_task.identifier, next_task.descriptor
// 	}
// 	return aec.INVALID_TASK_ID, {}
// }

// @(private)
// taskmanager_is_task_queued :: proc(manager: ^Task_Manager, task_id: Task_Id) -> bool {
// 	return taskqueue_is_task_present(&manager.task_queue, task_id)
// }

// @(private)
// taskmanager_is_task_currently_executing :: proc(manager: ^Task_Manager, task_id: Task_Id) -> bool {
// 	if sync.mutex_guard(&manager.currently_executing_tasks_mutex) {
// 		for task in manager.currently_executing_tasks {
// 			if task, ok := task.?; ok && task.identifier == task_id {
// 				return true
// 			}
// 		}
// 	}

// 	return false
// }

// @(private)
// taskinfo_free :: proc(task_info: Task_Info) {
// }

// @(private)
// taskmanager_get_new_task_id :: proc(manager: ^Task_Manager) -> Task_Id {
// 	return (Task_Id)(sync.atomic_add(&manager.task_index_counter, 1))
// }

// @(private)
// taskmanager_handle_executed_task :: proc(manager: ^Task_Manager, task_info: Task_Info) {
// 	task_info := task_info
// 	task_info.last_suspended_execution_time = time.now()

// 	switch v in task_info.last_result {
// 	case aec.Task_Result_Sleep:
// 		task_info.status = .Suspended
// 		taskmanager_register_task_info(manager, task_info)

// 	case aec.Task_Result_Yield:
// 		task_info.status = .Suspended
// 		taskmanager_register_task_info(manager, task_info)

// 	case aec.Task_Result_Repeat_After:
// 		task_info.status = .Queued
// 		taskmanager_handle_waitings(manager, task_info.identifier)
// 		taskmanager_register_task_info(manager, task_info)

// 	case aec.Task_Result_Repeat:
// 		task_info.status = .Queued
// 		taskmanager_handle_waitings(manager, task_info.identifier)
// 		taskmanager_register_task_info(manager, task_info)

// 	case aec.Task_Result_Wait_For:
// 		task_info.status = .Suspended
// 		task_info.remaining_waits = len(v.tasks)
// 		taskmanager_register_task_info(manager, task_info)

// 	case aec.Task_Result_Finished:
// 		task_info.status = .Finished

// 		taskmanager_handle_waitings(manager, task_info.identifier)
// 		if task_info.free_when_finished {
// 			taskinfo_free(task_info)
// 		} else {
// 			manager.completed_tasks[task_info.identifier] = task_info
// 		}
// 	}
// }

// @(private)
// taskmanager_handle_waitings :: proc(manager: ^Task_Manager, completed_task: Task_Id) {
// 	//TODO
// 	// if sync.mutex_guard(&manager.currently_executing_tasks_mutex) {
// 	// 	for &maybe_task in manager.currently_executing_tasks {
// 	// 		if task, ok := &maybe_task.?; ok {
// 	// 			if _, found := slice.linear_search(task.waiting_for_tasks, completed_task); found {
// 	// 				sync.atomic_add(&task.remaining_waits, -1)
// 	// 			}
// 	// 		}
// 	// 	}
// 	// }

// 	// if sync.mutex_guard(&manager.tasks_mutex) {
// 	// 	for &task in manager.tasks {
// 	// 		if _, found := slice.linear_search(task.waiting_for_tasks, completed_task); found {
// 	// 			sync.atomic_add(&task.remaining_waits, -1)
// 	// 		}
// 	// 	}
// 	// }
// }

// @(private)
// taskmanager_register_task_info :: proc(manager: ^Task_Manager, task: Task_Info) {
// 	taskqueue_append(&manager.task_queue, task)
// }

// @(private)
// taskinfo_get_importance_factor :: proc(task: Task_Info, now: time.Time) -> f32 {
// 	start_time: time.Time = ---
// 	if suspend_time, ok := task.last_suspended_execution_time.(time.Time); ok {
// 		start_time = suspend_time
// 	} else {
// 		start_time = task.submission_time
// 	}

// 	return(
// 		(f32)(time.duration_nanoseconds(time.diff(start_time, now))) *
// 		TASK_PRIORITY_MODIFIERS[task.user_priority] \
// 	)
// }

// @(private)
// taskinfo_can_execute_task_now :: proc(task: Task_Info, main_thread: bool, now: time.Time) -> bool {
// 	if task.remaining_waits > 0 {
// 		return false
// 	}

// 	if !main_thread && task.execute_on_main_thread {
// 		return false
// 	}

// 	if task.last_result != nil {
// 		if sleep, ok := task.last_result.(aec.Task_Result_Sleep); ok {
// 			if time.duration_nanoseconds(time.diff(task.last_suspended_execution_time.?, now)) <
// 			   time.duration_nanoseconds(sleep.duration) {
// 				return false
// 			}
// 		}

// 		if repeat, ok := task.last_result.(aec.Task_Result_Repeat_After); ok {
// 			if time.duration_nanoseconds(time.diff(task.last_suspended_execution_time.?, now)) <
// 			   time.duration_nanoseconds(repeat.duration) {
// 				return false
// 			}
// 		}
// 	}

// 	return true
// }

// // // @thread_safety: not thread safe
// // @(private = "file")
// // taskmanager_get_queued_task_ptr :: proc(manager: ^Task_Manager, task_id: Task_Id) -> ^Task_Info {
// // 	for &task in manager.tasks {
// // 		if task.identifier == task_id {
// // 			return &task
// // 		}
// // 	}

// // 	return nil
// // }

// // @thread_safety: not thread safe
// @(private = "file")
// taskmanager_get_currently_executing_task_ptr :: proc(
// 	manager: ^Task_Manager,
// 	task_id: Task_Id,
// ) -> ^Task_Info {
// 	for &task in manager.currently_executing_tasks {
// 		if task == nil {
// 			continue
// 		}

// 		if task.?.identifier == task_id {
// 			return &task.?
// 		}
// 	}

// 	return nil
// }

