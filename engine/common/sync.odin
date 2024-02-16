package amber_engine_common

import "core:sync"

_ :: sync

Sync :: struct($T: typeid, $M: typeid) {
	using _sync_user_data: T,
	_sync_mutex:           M,
}

sync_lock :: proc(snc: ^Sync($T, $M)) {
	sync.lock(&snc._sync_mutex)
}

sync_unlock :: proc(snc: ^Sync($T, $M)) {
	sync.unlock(&snc._sync_mutex)
}

sync_shared_lock :: proc(
	sync: ^Sync($T, $M),
) where $M == typeid_of(sync.RW_Mutex) ||
	$M == typeid_of(sync.Atomic_RW_Mutex) {
	sync.shared_lock(&snc._sync_mutex)
}

sync_shared_unlock :: proc(
	sync: ^Sync($T, $M),
) where M == typeid_of(sync.RW_Mutex) ||
	M == typeid_of(sync.Atomic_RW_Mutex) {
	sync.shared_unlock(&snc._sync_mutex)
}

// @(deferred_in = sync_unlock)
// sync_guard :: proc(snc: ^Sync($T, $M)) {
// 	sync_lock(snc)
// }

// @(deferred_in = sync_shared_unlock)
// sync_shared_guard :: proc(
// 	snc: ^Sync($T, $M),
// ) where M == typeid_of(sync.RW_Mutex) ||
// 	M == typeid_of(sync.Atomic_RW_Mutex) {
// 	sync_shared_lock(snc)
// }

sync_get_mutex :: proc(snc: ^Sync($T, $M)) -> ^M {
	return &snc._sync_mutex
}

