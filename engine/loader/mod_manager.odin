package amber_engine_loader

import aec "shared:ae_common"
import "core:mem"

Mod_Manager :: struct {
	allocator:            mem.Allocator,
	mod_loaders:          [dynamic]aec.Mod_Loader,
	mod_infos:            [dynamic]aec.Mod_Info,
	// @index_of mod_infos
	mod_dependency_graph: [dynamic]uint,
}

modmanager_init :: proc(mod_manager: ^Mod_Manager, allocator := context.allocator) {
	context.allocator = allocator
	mod_manager.allocator = allocator

	mod_manager.mod_loaders = make([dynamic]aec.Mod_Loader)
}

modmanager_free :: proc(mod_manager: Mod_Manager) {
	context.allocator = mod_manager.allocator

	delete(mod_manager.mod_loaders)
}

modmanager_register_modloader :: proc(
	mod_manager: ^Mod_Manager,
	mod_loader: aec.Mod_Loader,
) -> bool {
	context.allocator = mod_manager.allocator
	mod_loader := mod_loader

	mod_loader.identifier = (aec.Mod_Loader_Id)(len(mod_manager.mod_loaders))

	return true
}

