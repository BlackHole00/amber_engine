package amber_engine_interface

import "core:mem"
import "core:runtime"
import "engine:globals"
import "engine:storage"
import ae "shared:amber_engine/common"

storage_register_resource_type: ae.Storage_Register_Resource_Type_Proc : proc(
	type_name: string,
	type_size: uint,
	location: runtime.Source_Code_Location,
) -> ae.Resource_Type_Id {
	return storage.storage_register_resource_type(&globals.storage, type_name, type_size, location)
}

storage_is_resource_type_valid: ae.Storage_Is_Resource_Type_Valid_Proc : proc(
	type: ae.Resource_Type_Id,
) -> bool {
	return storage.storage_is_resource_type_valid(&globals.storage, type)
}

storage_add_resource: ae.Storage_Add_Resource_Proc : proc(
	resource_type: ae.Resource_Type_Id,
	data: []byte,
	location: runtime.Source_Code_Location,
) -> ae.Resource_Id {
	return storage.storage_add_resource(&globals.storage, resource_type, data, location)
}

storage_get_resource: ae.Storage_Get_Resource_Proc : proc(
	resource: ae.Resource_Id,
	destination: []byte,
	location: runtime.Source_Code_Location,
) -> bool {
	return storage.storage_get_resource(&globals.storage, resource, destination, location)
}

storage_set_resource: ae.Storage_Set_Resource_Proc : proc(
	resource: ae.Resource_Id,
	data: []byte,
	location: runtime.Source_Code_Location,
) -> bool {
	return storage.storage_set_resource(&globals.storage, resource, data, location)
}

storage_remove_resource: ae.Storage_Remove_Resource_Proc : proc(
	resource: ae.Resource_Id,
	location: runtime.Source_Code_Location,
) -> bool {
	return storage.storage_remove_resource(&globals.storage, resource, location)
}

storage_is_resource_valid: ae.Storage_Is_Resource_Valid : proc(resource: ae.Resource_Id) -> bool {
	return storage.storage_is_resource_valid(&globals.storage, resource)
}

storage_get_resource_type_info: ae.Storage_Get_Resource_Type_Info_Proc : proc(
	resource_type: ae.Resource_Type_Id,
) -> (
	ae.Resource_Type_Info,
	bool,
) {
	return storage.storage_get_resource_type_info(&globals.storage, resource_type)
}

storage_get_resource_info: ae.Storage_Get_Resource_Info_Proc : proc(
	resource: ae.Resource_Id,
) -> (
	ae.Resource_Info,
	bool,
) {
	return storage.storage_get_resource_info(&globals.storage, resource)
}

storage_get_registered_types_info_list: ae.Storage_Get_Registered_Types_Info_List_Proc : proc(
	allocator: mem.Allocator,
) -> []ae.Resource_Type_Info {
	return storage.storage_get_registered_types_info_list(&globals.storage, allocator)
}

