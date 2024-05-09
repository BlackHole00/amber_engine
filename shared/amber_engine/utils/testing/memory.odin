package amber_engine_utils_testing

import "base:runtime"
import "core:testing"
import "core:mem"
import "core:fmt"

@(deferred_in_out=end_scoped_mem_check)
SCOPED_MEM_CHECK :: proc(
	test: ^testing.T,
	location := #caller_location,
) -> (mem.Allocator, ^mem.Tracking_Allocator) {
	tracking_allocator := new(mem.Tracking_Allocator)
	mem.tracking_allocator_init(tracking_allocator, context.allocator)

	return mem.tracking_allocator(tracking_allocator), tracking_allocator
}

@(private)
end_scoped_mem_check :: proc(
	test: ^testing.T,
	location: runtime.Source_Code_Location,
	_: mem.Allocator,
	tracking_allocator: ^mem.Tracking_Allocator,
) {
	defer mem.tracking_allocator_destroy(tracking_allocator)
	defer free(tracking_allocator, tracking_allocator.backing)

	for bad_free in tracking_allocator.bad_free_array {
		fmt.printf(
			"[memory: %s] Bad free: 0x%p - %v\n",
			location.procedure,
			bad_free.memory,
			bad_free.location,
		)
	}
	for _, leak in tracking_allocator.allocation_map {
		fmt.printf(
			"[memory: %s] Memory leak: 0x%p - %v\n",
			location.procedure,
			leak.memory,
			leak.location,
		)
	}

	testing.expectf(
		test, 
		len(tracking_allocator.bad_free_array) == 0,
		"Bad free(s) detected",
		loc = location,
	)
	testing.expectf(
		test,
		len(tracking_allocator.allocation_map) == 0,
		"Memory leak(s) detected",
		loc = location,
	)
}

