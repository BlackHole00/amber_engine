package amber_engine_interface

import "core:mem"
import "core:runtime"
import "engine:globals"
import "engine:storage"
import aec "shared:ae_common"

storage_register_resource_type: aec.Storage_Register_Resource_Type_Proc : proc(
	type_name: string,
	type_size: uint,
	location: runtime.Source_Code_Location,
) -> aec.Resource_Type_Id {
	return storage.storage_register_resource_type(&globals.storage, type_name, type_size, location)
}

storage_is_resource_type_valid: aec.Storage_Is_Resource_Type_Valid_Proc : proc(
	type: aec.Resource_Type_Id,
) -> bool {
	return storage.storage_is_resource_type_valid(&globals.storage, type)
}

storage_add_resource: aec.Storage_Add_Resource_Proc : proc(
	resource_type: aec.Resource_Type_Id,
	data: []byte,
	location: runtime.Source_Code_Location,
) -> aec.Resource_Id {
	return storage.storage_add_resource(&globals.storage, resource_type, data, location)
}

storage_get_resource: aec.Storage_Get_Resource_Proc : proc(
	resource: aec.Resource_Id,
	destination: []byte,
	location: runtime.Source_Code_Location,
) -> bool {
	return storage.storage_get_resource(&globals.storage, resource, destination, location)
}

storage_set_resource: aec.Storage_Set_Resource_Proc : proc(
	resource: aec.Resource_Id,
	data: []byte,
	location: runtime.Source_Code_Location,
) -> bool {
	return storage.storage_set_resource(&globals.storage, resource, data, location)
}

storage_remove_resource: aec.Storage_Remove_Resource_Proc : proc(
	resource: aec.Resource_Id,
	location: runtime.Source_Code_Location,
) -> bool {
	return storage.storage_remove_resource(&globals.storage, resource, location)
}

storage_is_resource_valid: aec.Storage_Is_Resource_Valid : proc(
	resource: aec.Resource_Id,
) -> bool {
	return storage.storage_is_resource_valid(&globals.storage, resource)
}

storage_get_resource_type_info: aec.Storage_Get_Resource_Type_Info_Proc : proc(
	resource_type: aec.Resource_Type_Id,
) -> (
	aec.Resource_Type_Info,
	bool,
) {
	return storage.storage_get_resource_type_info(&globals.storage, resource_type)
}

storage_get_resource_info: aec.Storage_Get_Resource_Info_Proc : proc(
	resource: aec.Resource_Id,
) -> (
	aec.Resource_Info,
	bool,
) {
	return storage.storage_get_resource_info(&globals.storage, resource)
}

storage_get_registered_types_info_list: aec.Storage_Get_Registered_Types_Info_List_Proc : proc(
	allocator: mem.Allocator,
) -> []aec.Resource_Type_Info {
	return storage.storage_get_registered_types_info_list(&globals.storage, allocator)
}

