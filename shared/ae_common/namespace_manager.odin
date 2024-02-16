package ae_common

import "core:mem"
import "core:strings"

ODIN_NAMESPACE_NAMES :: [?]string{"odin", "core", "base"}
AMBER_ENGINE_NAMESPACE_NAMES :: [?]string{"amber_engine", "ae"}

Namespaced_String :: struct {
	namespace: Namespace_Id,
	string:    string,
}

Namespace_Id :: distinct u32
INVALID_NAMESPACE_ID :: max(Namespace_Id)

Namespace_Manager_Register_Namespace_Proc :: #type proc(namespace: string) -> Namespace_Id
Namespace_Manager_Register_Namespace_Alias :: #type proc(
	namespace: Namespace_Id,
	alias: string,
) -> bool

Namespace_Manager_Is_Namespace_Valid_Proc :: #type proc(namespace: Namespace_Id) -> bool

Namespace_Manager_Get_Namespace_Names_Proc :: #type proc(
	namespace: Namespace_Id,
	allocator: mem.Allocator,
) -> []string
Namespace_Manager_Find_Namespace_Proc :: #type proc(namespace: string) -> Namespace_Id

string_as_namespacedstring :: proc(namespace: Namespace_Id, str: string) -> Namespaced_String {
	return Namespaced_String{namespace = namespace, string = str}
}

string_to_namespacedstring :: proc(
	namespace: Namespace_Id,
	str: string,
	allocator := context.allocator,
	location := #caller_location,
) -> Namespaced_String {
	return(
		Namespaced_String {
			namespace = namespace,
			string = strings.clone(str, allocator, location),
		} \
	)
}

namespacedstring_get_namespace :: proc(str: Namespaced_String) -> Namespace_Id {
	return str.namespace
}

namespacedstring_as_string :: proc(str: Namespaced_String) -> string {
	return str.string
}

namespacedstring_compare :: proc(s1, s2: Namespaced_String) -> bool {
	return s1.namespace == s2.namespace && s1.string == s2.string
}

namespacedstring_clone :: proc(
	str: Namespaced_String,
	allocator := context.allocator,
	location := #caller_location,
) -> Namespaced_String {
	return string_as_namespacedstring(
		str.namespace,
		strings.clone(str.string, allocator, location),
	)
}

// Implemented in ae_interface:
//
// namespacedstring_to_string :: proc(str: Namespaced_String, allocator: mem.Allocator) -> string

