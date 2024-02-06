package amber_engine_scheduler

import "core:log"
import "core:slice"
import "core:sync"
import "core:time"
import aec "shared:ae_common"

@(private)
TASK_PRIORITY_MODIFIERS := [?]f32 {
	aec.Task_Priority.Low    = 1,
	aec.Task_Priority.Medium = 2,
	aec.Task_Priority.High   = 3,
}

Task_Manager :: struct {
	task_index_counter:              Task_Id,
	// A list of the currently registered (and suspended tasks)
	tasks:                           [dynamic]Task_Info,
	tasks_mutex:                     sync.RW_Mutex,
	// Some tasks might not free automatically, but the user must request their
	// freeing. Those tasks will be stored in the completed_tasks field
	completed_tasks:                 map[Task_Id]Task_Info,
	completed_tasks_mutex:           sync.RW_Mutex,
	// Every thread can only execute only one task at a time. The currently 
	// executed tasks are stored here
	currently_executing_tasks:       []Maybe(Task_Info),
	currently_executing_tasks_mutex: sync.RW_Mutex,
}

taskmanager_init :: proc(manager: ^Task_Manager, thread_count: int) {
	// pq.init(&manager.tasks, priorityqueue_less, priorityqueue_swap)
	manager.tasks = make([dynamic]Task_Info)
	manager.completed_tasks = make(map[Task_Id]Task_Info)
	manager.currently_executing_tasks = make([]Maybe(Task_Info), thread_count)
}

// @thread_safety: Not thread safe, call only on main engine deinitialization
taskmanager_deinit :: proc(manager: ^Task_Manager) {
	delete(manager.tasks)
	delete(manager.completed_tasks)
	delete(manager.currently_executing_tasks)
}

//NOTE(Vicix): Very dumb way of doing things, should probably study a dynamic 
//             queue method. THIS IS VEEERY DUMB!
taskmanager_find_most_important_task :: proc(
	manager: ^Task_Manager,
	scheduler_thread: Scheduler_Thread,
	only_main_thread := false,
) -> (
	Task_Info,
	bool,
) {
	if len(manager.tasks) == 0 {
		return {}, false
	}

	now := time.now()

	best_importance_factor := min(f32)
	best_task_idx := 0

	if sync.rw_mutex_shared_guard(&manager.tasks_mutex) {
		for task, i in manager.tasks {
			if !taskinfo_can_execute_task_now(task, only_main_thread, now) {
				continue
			}

			importance_factor := taskinfo_get_importance_factor(task, now)
			if importance_factor > best_importance_factor {
				if only_main_thread && !task.execute_on_main_thread {
					continue
				}

				best_importance_factor = importance_factor
				best_task_idx = i
			}
		}
	}

	defer unordered_remove(&manager.tasks, best_task_idx)

	return manager.tasks[best_task_idx], true
}

taskmanager_register_task :: proc(manager: ^Task_Manager, task: Task_Descriptor) -> Task_Id {
	task_id := taskmanager_get_new_task_id(manager)

	now := time.now()
	taskmanager_register_task_info(
		manager,
		Task_Info {
			descriptor = task,
			identifier = task_id,
			status = .Queued,
			submission_time = now,
		},
	)

	return task_id
}

taskmanager_is_task_valid :: proc(manager: ^Task_Manager, task_id: Task_Id) -> bool {
	return(
		taskmanager_is_task_completed(manager, task_id) ||
		taskmanager_is_task_queued(manager, task_id) ||
		taskmanager_is_task_currently_executing(manager, task_id) \
	)
}

taskmanager_is_task_completed :: proc(manager: ^Task_Manager, task_id: Task_Id) -> bool {
	if sync.rw_mutex_shared_guard(&manager.completed_tasks_mutex) {
		return task_id in manager.completed_tasks
	}

	unreachable()
}

taskmanager_free_task :: proc(manager: ^Task_Manager, task_id: Task_Id) -> (Task_Info, bool) {
	if !taskmanager_is_task_valid(manager, task_id) {
		log.error("The user requested freeing an invalid task")

		return {}, false
	}

	if sync.rw_mutex_guard(&manager.completed_tasks_mutex) {
		deleted_key, deleted_task := delete_key(&manager.completed_tasks, task_id)

		if deleted_key != 0 {
			taskinfo_free(deleted_task)
			return deleted_task, true
		}
	}

	if sync.rw_mutex_guard(&manager.tasks_mutex) {
		info := taskmanager_get_queued_task_ptr(manager, task_id)

		if info != nil {
			log.warn(
				"The user requested freeing a task that is currently executing or queued up. It will instead be automatically freed when it will terminate",
			)

			info.free_when_finished = true
			return info^, true
		}
	}

	if sync.rw_mutex_guard(&manager.currently_executing_tasks_mutex) {
		info := taskmanager_get_currently_executing_task_ptr(manager, task_id)

		if info != nil {
			log.warn(
				"The user requested freeing a task that is currently executing or queued up. It will instead be automatically freed when it will terminate",
			)

			info.free_when_finished = true
			return info^, true
		}
	}

	return {}, false
}

taskmanager_assign_new_task :: proc(
	manager: ^Task_Manager,
	scheduler_thread: Scheduler_Thread,
	previous_task_result: Task_Result,
) -> (
	Task_Id,
	Task_Descriptor,
) {
	previous_task: Maybe(Task_Info) = ---
	previous_task_result := previous_task_result

	next_task, has_tasks := taskmanager_find_most_important_task(
		manager,
		scheduler_thread,
		scheduler_thread.is_main_thread,
	)

	now := time.now()

	next_task.last_resumed_execution_time = now
	next_task.status = .Running

	if !has_tasks {
		if sync.rw_mutex_guard(&manager.currently_executing_tasks_mutex) {
			previous_task := manager.currently_executing_tasks[scheduler_thread.thread_id]
			manager.currently_executing_tasks[scheduler_thread.thread_id] = nil
		}
		return aec.INVALID_TASK_ID, {}
	}

	if sync.rw_mutex_guard(&manager.currently_executing_tasks_mutex) {
		previous_task := manager.currently_executing_tasks[scheduler_thread.thread_id]
		manager.currently_executing_tasks[scheduler_thread.thread_id] = next_task
	}

	if previous_task != nil && previous_task_result == nil {
		log.error("Invalid previous task provided. Converting into Task_Result_Finished")
		previous_task_result = aec.Task_Result_Finished{}
	} else if previous_task == nil && previous_task_result != nil {
		log.error("Invalid previous task provided. Ignoring")
	}

	if previous_task == nil {
		return next_task.identifier, next_task.descriptor
	}

	new_previous_task := previous_task.?

	new_previous_task.last_result = previous_task_result
	taskmanager_handle_executed_task(manager, new_previous_task)

	return next_task.identifier, next_task.descriptor
}

@(private)
taskmanager_is_task_queued :: proc(manager: ^Task_Manager, task_id: Task_Id) -> bool {
	if sync.rw_mutex_shared_guard(&manager.tasks_mutex) {
		for task in manager.tasks {
			if task.identifier == task_id {
				return true
			}
		}
	}

	return false
}

@(private)
taskmanager_is_task_currently_executing :: proc(manager: ^Task_Manager, task_id: Task_Id) -> bool {
	if sync.rw_mutex_shared_guard(&manager.currently_executing_tasks_mutex) {
		for task in manager.currently_executing_tasks {
			if task, ok := task.?; ok && task.identifier == task_id {
				return true
			}
		}
	}

	return false
}

@(private)
taskinfo_free :: proc(task_info: Task_Info) {
	delete(task_info.waiting_for_tasks)
}

@(private)
taskmanager_get_new_task_id :: proc(manager: ^Task_Manager) -> Task_Id {
	return (Task_Id)(sync.atomic_add(&manager.task_index_counter, 1))
}

@(private)
taskmanager_handle_executed_task :: proc(manager: ^Task_Manager, task_info: Task_Info) {
	task_info := task_info
	task_info.last_suspended_execution_time = time.now()

	switch v in task_info.last_result {
	case aec.Task_Result_Sleep:
		task_info.status = .Suspended
		taskmanager_register_task_info(manager, task_info)

	case aec.Task_Result_Yield:
		task_info.status = .Suspended
		taskmanager_register_task_info(manager, task_info)

	case aec.Task_Result_Repeat_After:
		task_info.status = .Queued
		taskmanager_handle_waitings(manager, task_info.identifier)
		taskmanager_register_task_info(manager, task_info)

	case aec.Task_Result_Repeat:
		task_info.status = .Queued
		taskmanager_handle_waitings(manager, task_info.identifier)
		taskmanager_register_task_info(manager, task_info)

	case aec.Task_Result_Wait_For:
		task_info.status = .Suspended
		task_info.remaining_waits = len(v.tasks)
		taskmanager_register_task_info(manager, task_info)

	case aec.Task_Result_Finished:
		task_info.status = .Finished

		taskmanager_handle_waitings(manager, task_info.identifier)
		if task_info.free_when_finished {
			taskinfo_free(task_info)
		} else {
			manager.completed_tasks[task_info.identifier] = task_info
		}
	}
}

@(private)
taskmanager_handle_waitings :: proc(manager: ^Task_Manager, completed_task: Task_Id) {
	if sync.rw_mutex_shared_guard(&manager.currently_executing_tasks_mutex) {
		for &maybe_task in manager.currently_executing_tasks {
			if task, ok := &maybe_task.?; ok {
				if _, found := slice.linear_search(task.waiting_for_tasks, completed_task); found {
					sync.atomic_add(&task.remaining_waits, -1)
				}
			}
		}
	}

	if sync.rw_mutex_shared_guard(&manager.tasks_mutex) {
		for &task in manager.tasks {
			if _, found := slice.linear_search(task.waiting_for_tasks, completed_task); found {
				sync.atomic_add(&task.remaining_waits, -1)
			}
		}
	}
}

@(private)
taskmanager_register_task_info :: proc(manager: ^Task_Manager, task: Task_Info) {
	if sync.rw_mutex_guard(&manager.tasks_mutex) {
		append(&manager.tasks, task)
	}
}

@(private)
taskinfo_get_importance_factor :: proc(task: Task_Info, now: time.Time) -> f32 {
	start_time: time.Time = ---
	if suspend_time, ok := task.last_suspended_execution_time.(time.Time); ok {
		start_time = suspend_time
	} else {
		start_time = task.submission_time
	}

	return(
		(f32)(time.duration_nanoseconds(time.diff(start_time, now))) *
		TASK_PRIORITY_MODIFIERS[task.user_priority] \
	)
}

@(private)
taskinfo_can_execute_task_now :: proc(
	task: Task_Info,
	should_be_main_thread: bool,
	now: time.Time,
) -> bool {
	if task.remaining_waits <= 0 {
		return false
	}

	if should_be_main_thread && !task.execute_on_main_thread {
		return false
	}

	if task.last_result == nil {
		if sleep, ok := task.last_result.(aec.Task_Result_Sleep); ok {
			if time.duration_nanoseconds(time.diff(task.last_suspended_execution_time.?, now)) <
			   time.duration_nanoseconds(sleep.duration) {
				return false
			}
		}

		if repeat, ok := task.last_result.(aec.Task_Result_Repeat_After); ok {
			if time.duration_nanoseconds(time.diff(task.last_suspended_execution_time.?, now)) <
			   time.duration_nanoseconds(repeat.duration) {
				return false
			}
		}
	}

	return true
}

// @thread_safety: not thread safe
@(private = "file")
taskmanager_get_queued_task_ptr :: proc(manager: ^Task_Manager, task_id: Task_Id) -> ^Task_Info {
	for &task in manager.tasks {
		if task.identifier == task_id {
			return &task
		}
	}

	return nil
}

// @thread_safety: not thread safe
@(private = "file")
taskmanager_get_currently_executing_task_ptr :: proc(
	manager: ^Task_Manager,
	task_id: Task_Id,
) -> ^Task_Info {
	for &task in manager.tasks {
		if task.identifier == task_id {
			return &task
		}
	}

	return nil
}

