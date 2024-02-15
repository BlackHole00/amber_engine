package ae_interface

import "core:fmt"
import "core:mem"
import "core:strings"
import aec "shared:ae_common"

Namespace_Id :: aec.Namespace_Id
INVALID_NAMESPACE_ID :: aec.INVALID_NAMESPACE_ID

Namespaced_String :: aec.Namespaced_String

string_as_namespacedstring :: #force_inline proc(
	namespace: Namespace_Id,
	str: string,
) -> Namespaced_String {
	return Namespaced_String{namespace = namespace, string = str}
}

string_to_namespacedstring :: proc(
	namespace: Namespace_Id,
	str: string,
	allocator: mem.Allocator,
	location := #caller_location,
) -> Namespaced_String {
	return(
		Namespaced_String {
			namespace = namespace,
			string = strings.clone(str, allocator, location),
		} \
	)
}

namespacedstring_compare :: proc(s1, s2: Namespaced_String) -> bool {
	return s1.namespace == s2.namespace && s1.string == s2.string
}

namespacedstring_to_string :: proc(str: Namespaced_String, allocator: mem.Allocator) -> string {
	// return fmt.caprintf(
	// 	"%s.%s",
	// 	namespacemanager_get_namespace_names(str.namespace)[0],
	// 	str.string,
	// )
	unimplemented()
}

