package amber_engine_utils

import "core:strings"

file_extension :: proc(
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
	return strings.clone(extension), true
}

remove_file_extension :: proc(file_name: string, allocator := context.allocator) -> string {
	context.allocator = allocator

	if !strings.contains_rune(file_name, '.') {
		return strings.clone(file_name)
	}

	trimmed := strings.trim_right_proc(file_name, proc(char: rune) -> bool {
		return char != '.'
	})
	trimmed = trimmed[:len(trimmed) - 1] // remove the trailing '.'

	when ODIN_OS == .Windows {
		splits := strings.split(trimmed, "\\")
	} else {
		splits := strings.split(trimmed, "/")
	}
	defer delete(splits)

	return strings.clone(splits[len(splits) - 1])
}

