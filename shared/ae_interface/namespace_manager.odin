package ae_interface

import "core:fmt"
import "core:mem"
import "core:strings"
import aec "shared:ae_common"

Namespace_Id :: aec.Namespace_Id
INVALID_NAMESPACE_ID :: aec.INVALID_NAMESPACE_ID

Namespaced_String :: aec.Namespaced_String

namespacedstring_to_string :: proc(str: Namespaced_String, allocator: mem.Allocator) -> string {
	// return fmt.caprintf(
	// 	"%s.%s",
	// 	namespacemanager_get_namespace_names(str.namespace)[0],
	// 	str.string,
	// )
	unimplemented()
}

