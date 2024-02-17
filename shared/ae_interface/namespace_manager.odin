package ae_interface

import "core:fmt"
import aec "shared:ae_common"

Namespace_Id :: aec.Namespace_Id
INVALID_NAMESPACE_ID :: aec.INVALID_NAMESPACE_ID

Namespaced_String :: aec.Namespaced_String

namespacemanager_register_namespace :: #force_inline proc(
	namespace: string,
	location := #caller_location,
) -> Namespace_Id {
	return get_engine_proctable().namespacemanager_register_namespace(namespace, location)
}
namespacemanager_register_namespace_alias :: #force_inline proc(
	namespace: Namespace_Id,
	alias: string,
	location := #caller_location,
) -> bool {
	return get_engine_proctable().namespacemanager_register_namespace_alias(
		namespace,
		alias,
		location,
	)
}

namespacemanager_is_namespace_valid :: #force_inline proc(namespace: Namespace_Id) -> bool {
	return get_engine_proctable().namespacemanager_is_namespace_valid(namespace)
}

namespacemanager_get_namespace_names :: #force_inline proc(
	namespace: Namespace_Id,
	allocator := context.temp_allocator,
	location := #caller_location,
) -> []string {
	return get_engine_proctable().namespacemanager_get_namespace_names(
		namespace,
		allocator,
		location,
	)
}
namespacemanager_get_first_namespace_name :: #force_inline proc(
	namespace: Namespace_Id,
	location := #caller_location,
) -> string {
	return get_engine_proctable().namespacemanager_get_first_namespace_name(namespace, location)
}

namespacemanager_find_namespace :: #force_inline proc(namespace: string) -> Namespace_Id {
	return get_engine_proctable().namespacemanager_find_namespace(namespace)
}

string_as_namespacedstring :: aec.string_to_namespacedstring
string_to_namespacedstring :: aec.string_to_namespacedstring
namespacedstring_as_string :: aec.namespacedstring_as_string
namespacedstring_get_namespace :: aec.namespacedstring_get_namespace
namespacedstring_clone :: aec.namespacedstring_compare
namespacedstring_compare :: aec.namespacedstring_compare

namespacedstring_to_string :: proc(
	str: Namespaced_String,
	allocator := context.allocator,
) -> string {
	return fmt.aprintf(
		"%s.%s",
		namespacemanager_get_first_namespace_name(str.namespace),
		str.string,
	)
}

