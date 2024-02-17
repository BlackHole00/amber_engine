package amber_engine_namespace_manager

import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import "core:strings"
import "core:sync"
import "engine:common"
import aec "shared:ae_common"

Namespace_Id :: aec.Namespace_Id

@(private)
ODIN_NAMESPACE_NAMES := aec.ODIN_NAMESPACE_NAMES
@(private)
AMBER_ENGINE_NAMESPACE_NAMES := aec.AMBER_ENGINE_NAMESPACE_NAMES

ODIN_NAMESPACE :: (Namespace_Id)(0)
AMBER_ENGINE_NAMESPACE :: (Namespace_Id)(1)

//TODO(Vicix): Should I create an arena for every struct? NO!
@(private)
namespace_manager: struct {
	// Used for general-purpose allocations
	allocator:              mem.Allocator,
	arena:                  virtual.Arena,
	namespace_id_generator: common.Id_Generator(Namespace_Id),
	// Should be [dynamic][dynamic]string, but since the dynamic vector does 
	// have an internal allocator and most entries have only one element it 
	// would be a waste of memory
	namespaces:             [dynamic][]string,
	// @locks: namespaces
	mutex:                  sync.Mutex,
}

init :: proc(allocator := context.allocator) {
	context.allocator = namespace_manager.allocator

	namespace_manager.allocator = allocator
	if virtual.arena_init_growing(&namespace_manager.arena, mem.Kilobyte) != .None {
		log.panicf("Could not create a virtual arena")
	}

	namespace_manager.namespaces = make([dynamic][]string)

	register_builtin_types()
}

// @thread_safety: NOT thread safe
deinit :: proc() {
	context.allocator = namespace_manager.allocator

	for names in namespace_manager.namespaces {
		delete(names)
	}
	delete(namespace_manager.namespaces)

	virtual.arena_destroy(&namespace_manager.arena)
}

register_namespace :: proc(namespace: string, location := #caller_location) -> Namespace_Id {
	context.allocator = namespace_manager.allocator

	if id := find_namespace(namespace); id != aec.INVALID_NAMESPACE_ID {
		log.warnf(
			"Could not register namespace %s: The namespace %d has the same identifier string",
			namespace,
			id,
		)
		return aec.INVALID_NAMESPACE_ID
	}

	names_slice := string_to_slice(namespace)
	if sync.guard(&namespace_manager.mutex) {
		return register_names_slice(names_slice)
	}
	unreachable()
}

register_namespace_alias :: proc(
	namespace: Namespace_Id,
	alias: string,
	location := #caller_location,
) -> bool {
	context.allocator = namespace_manager.allocator

	if !is_namespace_valid(namespace) {
		log.errorf(
			"Could not create an alias for namespace %d: The namespace is not valid",
			namespace,
			location = location,
		)
		return false
	}

	alias_str := string_clone_to_arena(alias)

	if sync.guard(&namespace_manager.mutex) {
		append_to_names_slice(namespace, alias_str)
	}

	return true
}

is_namespace_valid :: proc(namespace: Namespace_Id) -> bool {
	return common.idgenerator_is_id_valid(&namespace_manager.namespace_id_generator, namespace)
}

get_namespace_names :: proc(
	namespace: Namespace_Id,
	allocator: mem.Allocator,
	location := #caller_location,
) -> []string {
	if !is_namespace_valid(namespace) {
		log.errorf(
			"Could not get names of namespace %d: The namespace is not valid",
			namespace,
			location = location,
		)
		return {}
	}

	if sync.guard(&namespace_manager.mutex) {
		return slice.clone(namespace_manager.namespaces[namespace], allocator)
	}
	unreachable()
}

get_first_namespace_name :: proc(namespace: Namespace_Id, location := #caller_location) -> string {
	if !is_namespace_valid(namespace) {
		log.errorf(
			"Could not get the first name of namespace %d: The namespace is not valid",
			namespace,
			location = location,
		)
		return {}
	}

	if sync.guard(&namespace_manager.mutex) {
		return namespace_manager.namespaces[namespace][0]
	}
	unreachable()
}

find_namespace :: proc(namespace: string) -> Namespace_Id {
	sync.mutex_guard(&namespace_manager.mutex)

	for names, namespace_id in namespace_manager.namespaces {
		for name in names {
			if name == namespace {
				return (Namespace_Id)(namespace_id)
			}
		}
	}

	return aec.INVALID_NAMESPACE_ID
}

@(private)
string_to_slice :: proc(str: string) -> []string {
	clone_str := string_clone_to_arena(str)

	names_slice := make([]string, 1)
	names_slice[0] = clone_str

	return names_slice
}

@(private)
string_clone_to_arena :: proc(str: string) -> string {
	return strings.clone(str, arena_allocator())
}

@(private)
arena_allocator :: #force_inline proc() -> mem.Allocator {
	return virtual.arena_allocator(&namespace_manager.arena)
}

@(private)
register_builtin_types :: proc() {
	//NOTE(Vicix): The engine internals assume this EXACT order
	odin_namespace := register_namespace(ODIN_NAMESPACE_NAMES[0])
	for i in 0 ..< len(ODIN_NAMESPACE_NAMES) {
		register_namespace_alias(odin_namespace, ODIN_NAMESPACE_NAMES[i])
	}

	ae_namespace := register_namespace(AMBER_ENGINE_NAMESPACE_NAMES[0])
	for i in 0 ..< len(AMBER_ENGINE_NAMESPACE_NAMES) {
		register_namespace_alias(ae_namespace, AMBER_ENGINE_NAMESPACE_NAMES[i])
	}
}

// @thread_safety: NOT Thread-safe
@(private)
get_next_namespace_id :: #force_inline proc() -> Namespace_Id {
	return (Namespace_Id)(len(namespace_manager.namespaces))
}

// @thread_safety: NOT Thread-safe
@(private)
register_names_slice :: proc(names_slice: []string) -> Namespace_Id {
	namespace_id := common.idgenerator_generate(&namespace_manager.namespace_id_generator)
	append(&namespace_manager.namespaces, names_slice)

	return namespace_id
}

// @safety: The function does NOT check for the validity of namespace
// @thread_safety: NOT Thread-safe
@(private)
resize_names_slice :: proc(namespace: Namespace_Id, new_len: int) {
	old_names_slice := namespace_manager.namespaces[namespace]

	new_names_slice := make([]string, new_len)
	mem.copy_non_overlapping(
		&new_names_slice[0],
		&old_names_slice[0],
		len(old_names_slice) * size_of(string),
	)

	namespace_manager.namespaces[namespace] = new_names_slice
	delete(old_names_slice)
}

// @safety: The function does NOT check for the validity of namespace
// @thread_safety: NOT Thread-safe
@(private)
append_to_names_slice :: proc(namespace: Namespace_Id, name: string) {
	old_len := len(namespace_manager.namespaces[namespace])
	resize_names_slice(namespace, old_len + 1)

	namespace_manager.namespaces[namespace][old_len] = name
}

