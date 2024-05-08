package mimalloc

import "core:mem"
import "base:runtime"

when ODIN_OS == .Darwin && ODIN_ARCH == .arm64 {
	foreign import lib_mimalloc "lib/libmimalloc_darwing_arm64.a"
} else {
	#panic("Unsupported target")
}

@(default_calling_convention = "c")
foreign lib_mimalloc {
	mi_malloc :: proc(size: uint) -> rawptr ---
	mi_calloc :: proc(count: uint, size: uint) -> rawptr ---
	mi_realloc :: proc(ptr: rawptr, size: uint) -> rawptr ---
	mi_free :: proc(ptr: rawptr) ---
	mi_aligned_alloc :: proc(alignment: uint, size: uint) -> rawptr ---
}

allocator :: proc() -> runtime.Allocator {
	allocator_proc :: proc(
		allocator_data: rawptr, 
		mode: runtime.Allocator_Mode,
        size, alignment: int,
        old_memory: rawptr, old_size: int,
        location: runtime.Source_Code_Location,
	) -> ([]byte, runtime.Allocator_Error) {
     	switch mode {
 		case .Alloc:
 			ptr :=  mi_aligned_alloc((uint)(alignment), (uint)(size))
 			if ptr == nil {
 				return nil, .Out_Of_Memory
 			}

 			mem.zero(ptr, size)
 			return mem.byte_slice(ptr, size), .None

 		case .Alloc_Non_Zeroed:
 			ptr :=  mi_aligned_alloc((uint)(alignment), (uint)(size))
 			if ptr == nil {
 				return nil, .Out_Of_Memory
 			}

 			return mem.byte_slice(ptr, size), .None

 		case .Free:
 			mi_free(old_memory)
 			return nil, .None
 			
 		case .Resize:
 			ptr := mi_realloc(old_memory, (uint)(size))
 			if ptr == nil {
 				return nil, .Out_Of_Memory
 			}

 			mem.zero(mem.ptr_offset((^byte)(ptr), old_size), size - old_size)
 			return mem.byte_slice(ptr, size), .None

 		case .Resize_Non_Zeroed:
 			ptr := mi_realloc(old_memory, (uint)(size))
 			if ptr == nil {
 				return nil, .Out_Of_Memory
 			}

 			return mem.byte_slice(ptr, size), .None

 		case .Free_All:
 			fallthrough
 		case .Query_Features:
 			fallthrough
 		case .Query_Info:
 			return nil, .Mode_Not_Implemented
     	}

    	unreachable()
    }

	return runtime.Allocator {
		procedure = allocator_proc,
	}
}
