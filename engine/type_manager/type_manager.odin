package amber_engine_type_manager

import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:reflect"
import "core:slice"
import "core:sync"
import "engine:common"
import "engine:namespace_manager"
import aec "shared:ae_common"

Type_Id :: aec.Type_Id
Lower_Type_Id_Section :: aec.Lower_Type_Id_Section
Type_Descriptor :: aec.Type_Descriptor
Any :: aec.Any

namespace_of :: aec.typemanager_namespace_of

@(private)
type_manager: struct {
	allocator:         mem.Allocator,
	arena:             virtual.Arena,
	type_id_generator: common.Id_Generator(Lower_Type_Id_Section),
	types:             [dynamic]^aec.Type_Info,
	types_mutex:       sync.Mutex,
}

init :: proc(allocator := context.allocator) {
	context.allocator = allocator
	type_manager.allocator = allocator

	assert(
		virtual.arena_init_growing(&type_manager.arena, mem.Kilobyte) == .None,
		"Could not create an arena",
	)

	type_manager.types = make([dynamic]^aec.Type_Info)

	register_builtin_types()
}

deinit :: proc() {
	context.allocator = type_manager.allocator

	delete(type_manager.types)
	virtual.arena_destroy(&type_manager.arena)
}

register_type_by_descriptor :: proc(
	type: Type_Descriptor,
	location := #caller_location,
) -> Type_Id {
	if is_descriptor_already_registered(type) {
		namespace := aec.namespacedstring_get_namespace(type.name)

		log.warnf(
			"Could not register type %s.%s: It a type with the same name already exists",
			namespace_manager.get_first_namespace_name(namespace),
			aec.namespacedstring_as_string(type.name),
			location = location,
		)

		return aec.INVALID_TYPE_ID
	}

	context.allocator = type_manager.allocator

	if sync.guard(&type_manager.types_mutex) {
		idx := common.idgenerator_generate(&type_manager.type_id_generator)
		id := Type_Id {
			compound =  {
				namespace = aec.namespacedstring_get_namespace(type.name),
				type = (Lower_Type_Id_Section)(idx),
			},
		}

		new_descriptor := new(aec.Type_Info, arena_allocator())
		new_descriptor.base = type
		new_descriptor.name = aec.namespacedstring_clone(type.name, arena_allocator())
		new_descriptor.identifier = id

		append(&type_manager.types, new_descriptor)

		return id
	}
	unreachable()
}

is_type_valid :: proc(type: Type_Id) -> bool {
	if !common.idgenerator_is_id_valid(&type_manager.type_id_generator, type.type) {
		return false
	}

	if sync.guard(&type_manager.types_mutex) {
		return aec.namespacedstring_get_namespace(get_typeinfo_unsafe(type).name) == type.namespace
	}
	unreachable()
}

find_type_by_name :: proc(name: aec.Namespaced_String) -> Type_Id {
	sync.guard(&type_manager.types_mutex)

	for type, i in type_manager.types {
		if aec.namespacedstring_compare(type.name, name) {
			return index_to_typeid(i)
		}
	}

	return aec.INVALID_TYPE_ID
}

get_typeinfo :: proc(type: Type_Id, location := #caller_location) -> ^aec.Type_Info {
	if !is_type_valid(type) {
		log.warn(
			"Could not get type info of type %d: The type is not valid",
			type.full_id,
			location = location,
		)
		return nil
	}

	if sync.guard(&type_manager.types_mutex) {
		return get_typeinfo_unsafe(type)
	}
	unreachable()
}

get_typeinfo_list :: proc(allocator := context.temp_allocator) -> []^aec.Type_Info {
	sync.guard(&type_manager.types_mutex)

	return slice.clone(type_manager.types[:], allocator)
}

// @note: use ONLY with the engine types. DO NOT use with mod typeids
register_type :: proc(
	$T: typeid,
	namespace: aec.Namespace_Id,
	location := #caller_location,
) -> Type_Id {
	if !namespace_manager.is_namespace_valid(namespace) {
		type_id := typeid_of(T)
		log.errorf(
			"Could not register type %v: Invalid namespace provided",
			type_id,
			location = location,
		)
		return aec.INVALID_TYPE_ID
	}

	name := aec.string_as_namespacedstring(namespace, get_name_of_odin_typeid(T))
	return register_type_by_descriptor(
		Type_Descriptor{name = name, size = size_of(T), align = align_of(T)},
		location,
	)
}

typeid_of_odin_type :: proc(
	namespace: aec.Namespace_Id,
	$T: typeid,
	location := #caller_location,
) -> Type_Id {
	if !namespace_manager.is_namespace_valid(namespace) {
		type_id := typeid_of(T)
		log.errorf(
			"Could not register type %v: Invalid namespace provided",
			type_id,
			location = location,
		)
		return aec.INVALID_TYPE_ID
	}

	name := aec.string_as_namespacedstring(namespace, get_name_of_odin_typeid(T))
	return find_type_by_name(name)
}

size_of_type :: proc(type: Type_Id, location := #caller_location) -> (uint, bool) #optional_ok {
	return get_typeinfo(type, location).size, true
}

align_of_type :: proc(type: Type_Id, location := #caller_location) -> (uint, bool) #optional_ok {
	return get_typeinfo(type, location).align, true
}

name_of_type :: proc(
	type: Type_Id,
	location := #caller_location,
) -> (
	aec.Namespaced_String,
	bool,
) #optional_ok {
	return get_typeinfo(type, location).name, true
}

any_of :: proc(type: Type_Id, data: ^$T) -> Any {
	if !is_type_valid(type.namespace) {
		log.errorf("Could not create Any of type %d: The provided type is not valid", type.full_id)
		return Any{type = aec.INVALID_TYPE_ID}
	}

	return Any{type = type, data = data}
}

@(private)
register_builtin_types :: proc() {
	odin_namespace := namespace_manager.find_namespace(aec.ODIN_NAMESPACE_NAMES[0])
	assert(odin_namespace != aec.INVALID_NAMESPACE_ID)

	assert(register_type(u8, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(u16, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(u32, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(u64, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(i8, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(i16, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(i32, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(i64, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(f32, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(f64, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(string, odin_namespace) != aec.INVALID_TYPE_ID)
	assert(register_type(cstring, odin_namespace) != aec.INVALID_TYPE_ID)
}

@(private)
arena_allocator :: #force_inline proc() -> mem.Allocator {
	return virtual.arena_allocator(&type_manager.arena)
}

// @thread_safety: Thread-safe
@(private)
is_descriptor_already_registered :: proc(type: Type_Descriptor) -> bool {
	return find_type_by_name(type.name) != aec.INVALID_TYPE_ID
}

// @thread_safety: NOT Thread-safe
@(private)
get_typeinfo_unsafe :: proc(type: Type_Id) -> ^aec.Type_Info {
	return type_manager.types[typeid_to_index(type)]
}

// @thread_safety: NOT Thread-safe
@(private)
index_to_typeid :: proc(idx: int) -> Type_Id {
	return(
		Type_Id {
			compound =  {
				type = (Lower_Type_Id_Section)(idx),
				namespace = aec.namespacedstring_get_namespace(type_manager.types[idx].name),
			},
		} \
	)
}

@(private)
typeid_to_index :: proc(type: Type_Id) -> int {
	return (int)(type.type)
}

@(private)
get_name_of_odin_typeid :: proc(type: typeid) -> string {
	info := type_info_of(type)

	//TODO(Vicix): do ALL types
	#partial switch v in info.variant {
	case reflect.Type_Info_Named:
		return v.name

	case reflect.Type_Info_Integer:
		switch {
		case v.signed && info.size == 1:
			return "i8"
		case v.signed && info.size == 2:
			return "i16"
		case v.signed && info.size == 4:
			return "i32"
		case v.signed && info.size == 8:
			return "i64"
		case v.signed && info.size == 16:
			return "i128"
		case !v.signed && info.size == 1:
			return "u8"
		case !v.signed && info.size == 2:
			return "u16"
		case !v.signed && info.size == 4:
			return "u32"
		case !v.signed && info.size == 8:
			return "u64"
		case !v.signed && info.size == 16:
			return "u128"
		}

	case reflect.Type_Info_Float:
		if info.size == 4 {
			return "f32"
		} else {
			return "f64"
		}

	case reflect.Type_Info_String:
		if v.is_cstring {
			return "cstring"
		} else {
			return "string"
		}
	}

	panic("Unsupported type")
}

