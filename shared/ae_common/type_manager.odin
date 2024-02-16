package ae_common

import "core:mem"

Packaged_Type_Id :: distinct u64
Lower_Type_Id_Section :: distinct u32

Type_Id :: struct #raw_union {
	full_id:        Packaged_Type_Id,
	using compound: struct #packed {
		namespace: Namespace_Id,
		type:      Lower_Type_Id_Section,
	},
}

//TODO(Vicix): Figure out how to make this an actual constant
INVALID_TYPE_ID := Type_Id {
	full_id = (Packaged_Type_Id)(max(u64)),
}

Any :: struct {
	data: rawptr,
	type: Type_Id,
}

//TODO(Vicix): Implement a reflection system, possibly using odin's reflect 
//             system
Type_Descriptor :: struct {
	name:  Namespaced_String,
	size:  uint,
	align: uint,
}

Type_Info :: struct {
	using base: Type_Descriptor,
	identifier: Type_Id,
}

Type_Manager_Register_By_Descriptor_Type_Proc :: #type proc(type: Type_Descriptor) -> Type_Id

Type_Manager_Is_Type_Valid_Proc :: #type proc(type: Type_Id) -> bool
Type_Manager_Find_Type_By_Name :: #type proc(name: Namespaced_String) -> Type_Id

Type_Manager_Get_Type_Info :: #type proc(type: Type_Id) -> ^Type_Info
Type_Manager_Get_Type_Info_List :: #type proc(allocator: mem.Allocator) -> []^Type_Info

typemanager_namespace_of :: proc(type: Type_Id) -> Namespace_Id {
	return type.namespace
}

// Implemented in ae_interface:
// typemanager_register_type :: proc(namespace: Namespace_Id, type: typeid) -> Type_Id
// typemanager_typeid_of :: proc(namespace: Namespace_Id, type: typeid) -> Type_Id
// typemanager_size_of :: proc(type: Type_Id) -> uint
// typemanager_align_of :: proc(type: Type_Id) -> uint
// typemanager_name_of :: proc(type: Type_Id) -> Namespaced_String
// any_of :: proc(namespace: Namespace_Id, data: ^$T) -> Any

