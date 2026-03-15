extends GutTest

const path = "res://demo/binary_resource.bin"

var expected: TestResource
var actual: TestResource


func before_all() -> void:
	var resource := TestResource.generate()
	expected = resource.duplicate()
	ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	actual = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


func test_binary_resource_loaded() -> void:
	assert_not_null(actual)


func test_bool_stored_correctly() -> void:
	assert_eq(actual.boolean, expected.boolean)


func test_int_stored_correctly() -> void:
	assert_eq(actual.integer, expected.integer)


func test_float_stored_correctly() -> void:
	assert_eq(actual.floating_point, expected.floating_point)


func test_enum_stored_correctly() -> void:
	assert_eq(actual.enumeration, expected.enumeration)


func test_string_stored_correctly() -> void:
	assert_eq(actual.string, expected.string)


func test_string_name_stored_correctly() -> void:
	assert_eq(actual.string_name, expected.string_name)


func test_node_path_stored_correctly() -> void:
	assert_eq(actual.node_path, expected.node_path)


func test_self_ref_stored_correctly() -> void:
	assert_eq(actual.self_ref, actual)


func test_sub_resource_stored_correctly() -> void:
	assert_not_null(actual.sub_resource)


func test_external_trusted_resource_stored_correctly() -> void:
	assert_eq(actual.external_trusted_resource, expected.external_trusted_resource)


func test_external_untrusted_resource_stored_correctly() -> void:
	assert_null(actual.external_untrusted_resource)


func test_external_unknown_resource_stored_correctly() -> void:
	assert_eq(actual.external_unknown_resource, expected.external_unknown_resource)


func test_vector2_stored_correctly() -> void:
	assert_eq(actual.vector2, expected.vector2)


func test_vector2i_stored_correctly() -> void:
	assert_eq(actual.vector2i, expected.vector2i)


func test_vector3_stored_correctly() -> void:
	assert_eq(actual.vector3, expected.vector3)


func test_vector3i_stored_correctly() -> void:
	assert_eq(actual.vector3i, expected.vector3i)


func test_vector4_stored_correctly() -> void:
	assert_eq(actual.vector4, expected.vector4)


func test_vector4i_stored_correctly() -> void:
	assert_eq(actual.vector4i, expected.vector4i)


func test_color_stored_correctly() -> void:
	assert_eq(actual.color, expected.color)


func test_transform2d_stored_correctly() -> void:
	assert_eq(actual.transform2d, expected.transform2d)


func test_transform3d_stored_correctly() -> void:
	assert_eq(actual.transform3d, expected.transform3d)


func test_basis_stored_correctly() -> void:
	assert_eq(actual.basis, expected.basis)


func test_projection_stored_correctly() -> void:
	assert_eq(actual.projection, expected.projection)


func test_quaternion_stored_correctly() -> void:
	assert_eq(actual.quaternion, expected.quaternion)


func test_rect2_stored_correctly() -> void:
	assert_eq(actual.rect2, expected.rect2)


func test_rect2i_stored_correctly() -> void:
	assert_eq(actual.rect2i, expected.rect2i)


func test_aabb_stored_correctly() -> void:
	assert_eq(actual.aabb, expected.aabb)


func test_plane_stored_correctly() -> void:
	assert_eq(actual.plane, expected.plane)


func test_array_stored_correctly() -> void:
	assert_eq(actual.array, expected.array)


func test_typed_array_stored_correctly() -> void:
	assert_eq(actual.typed_array, expected.typed_array)


func test_object_array_stored_correctly() -> void:
	assert_eq_deep(actual.object_array, expected.object_array)


func test_packed_byte_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_byte_array, expected.packed_byte_array)


func test_packed_int32_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_int32_array, expected.packed_int32_array)


func test_packed_int64_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_int64_array, expected.packed_int64_array)


func test_packed_float32_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_float32_array, expected.packed_float32_array)


func test_packed_float64_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_float64_array, expected.packed_float64_array)


func test_packed_string_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_string_array, expected.packed_string_array)


func test_packed_vector2_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_vector2_array, expected.packed_vector2_array)


func test_packed_vector3_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_vector3_array, expected.packed_vector3_array)


func test_packed_vector4_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_vector4_array, expected.packed_vector4_array)


func test_packed_color_array_stored_correctly() -> void:
	assert_eq_deep(actual.packed_color_array, expected.packed_color_array)


func test_dictionary_stored_correctly() -> void:
	assert_eq_deep(actual.dictionary, expected.dictionary)


func test_typed_dictionary_stored_correctly() -> void:
	assert_eq_deep(actual.typed_dictionary, expected.typed_dictionary)


func test_object_dictionary_stored_correctly() -> void:
	assert_eq_deep(actual.object_dictionary, expected.object_dictionary)
