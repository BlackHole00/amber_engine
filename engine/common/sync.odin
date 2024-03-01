package amber_engine_common

import "core:sync"

_ :: sync

// @note: Do not use, it does not make code more pretty
Sync :: struct($T: typeid, $M: typeid) {
	using _sync_user_data: T,
	using _sync_mutex:     M,
}

sync_get_data :: proc(snc: ^Sync($T, $M)) -> ^T {
	return snc._sync_user_data
}

sync_get_mutex :: proc(snc: ^Sync($T, $M)) -> ^M {
	return &snc._sync_mutex
}

