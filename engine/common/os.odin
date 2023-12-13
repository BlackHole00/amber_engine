package amber_engine_common

import "core:os"
import "core:strings"

file_extension_from_handle :: proc(
	handle: os.Handle,
	allocator := context.allocator,
) -> (
	string,
	bool,
) {
	context.allocator = allocator

	full_path, path_ok := os.absolute_path_from_handle(handle)
	if path_ok != os.ERROR_NONE {
		return "", false
	}

	return file_extension_from_filename(full_path)
}

file_extension_from_filename :: proc(
	file_name: string,
	allocator := context.allocator,
) -> (
	string,
	bool,
) #optional_ok {
	context.allocator = allocator

	if !strings.contains_rune(file_name, '.') {
		return "", true
	}

	splits := strings.split(file_name, ".")
	defer delete(splits)

	extension := splits[len(splits) - 1]
	return extension, true
}

remove_file_extension :: proc(file_name: string, allocator := context.allocator) -> string {
	context.allocator = allocator

	if !strings.contains_rune(file_name, '.') {
		return strings.clone(file_name)
	}

	trimmed := strings.trim_right_proc(file_name, proc(char: rune) -> bool {
		return char != '.'
	})

	return strings.clone(trimmed[:len(trimmed) - 2]) // remove the trailing '.'
}

file_extension :: proc {
	file_extension_from_handle,
	file_extension_from_filename,
}

