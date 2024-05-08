package amber_engine_utils_testing

import "base:runtime"
import "core:fmt"
import "core:time"

@(deferred_in_out=end_timing_report)
SCOPED_TIMING_REPORT :: proc(location := #caller_location) -> time.Tick {
	return time.tick_now()
}

@(private)
end_timing_report :: proc(location: runtime.Source_Code_Location, start: time.Tick) {
	end := time.tick_now()
	diff := time.tick_diff(start, end)

	fmt.printf("[Timing: %s] The test completed in %v\n", location.procedure, diff)
}
