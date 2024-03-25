package ae_common

import "core:mem"
import "core:runtime"

Resource_Type_Id :: distinct u64
Resource_Id :: distinct u64

INVALID_RESOURCE_TYPE_ID :: max(Resource_Type_Id)
INVALID_REOSURCE_ID :: max(Resource_Id)

Resource_Type_Info :: struct {
	identifier: Resource_Type_Id,
	name:       string,
	size:       uint,
}

Resource_Info :: struct {
	identifier: Resource_Id,
	type:       Resource_Type_Id,
}

Storage_Register_Resource_Type_Proc :: #type proc(
	type_name: string,
	type_size: uint,
	location: runtime.Source_Code_Location,
) -> Resource_Type_Id
Storage_Is_Resource_Type_Valid_Proc :: #type proc(type: Resource_Type_Id) -> bool

Storage_Add_Resource_Proc :: #type proc(
	resource_type: Resource_Type_Id,
	data: []byte,
	location: runtime.Source_Code_Location,
) -> Resource_Id
Storage_Get_Resource_Proc :: #type proc(
	resource: Resource_Id,
	destination: []byte,
	location: runtime.Source_Code_Location,
) -> bool
Storage_Set_Resource_Proc :: #type proc(
	resource: Resource_Id,
	data: []byte,
	location: runtime.Source_Code_Location,
) -> bool
Storage_Remove_Resource_Proc :: #type proc(
	resource: Resource_Id,
	location: runtime.Source_Code_Location,
) -> bool
Storage_Is_Resource_Valid :: #type proc(resource: Resource_Id) -> bool

Storage_Get_Resource_Type_Info_Proc :: #type proc(
	resource_type: Resource_Type_Id,
) -> (
	Resource_Type_Info,
	bool,
)
Storage_Get_Resource_Info_Proc :: #type proc(resource: Resource_Id) -> (Resource_Info, bool)

Storage_Get_Registered_Types_Info_List_Proc :: #type proc(
	allocator: mem.Allocator,
) -> []Resource_Type_Info

