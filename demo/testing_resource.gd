class_name TestResource extends Resource

enum TestEnum {
	Zero,
	One,
	Two,
	Three,
}

@export var boolean: bool
@export var integer: int
@export var floating_point: float
@export var enumeration: TestEnum

@export var string: String
@export var string_name: StringName
@export var node_path: NodePath

@export var self_ref: TestResource
@export var sub_resource: TestResource
@export var external_trusted_resource: TestResource
@export var external_unknown_resource: TestResource
@export var external_untrusted_resource: TestResource

@export var vector2: Vector2
@export var vector2i: Vector2i
@export var vector3: Vector3
@export var vector3i: Vector3i
@export var vector4: Vector4
@export var vector4i: Vector4i
@export var color: Color

@export var transform2d: Transform2D
@export var transform3d: Transform3D
@export var basis: Basis
@export var projection: Projection

@export var quaternion: Quaternion

@export var rect2: Rect2
@export var rect2i: Rect2i
@export var aabb: AABB

@export var plane: Plane

@export var array: Array
@export var typed_array: Array[int]
@export var object_array: Array[Resource]

@export var packed_byte_array: PackedByteArray
@export var packed_int32_array: PackedInt32Array
@export var packed_int64_array: PackedInt64Array
@export var packed_float32_array: PackedFloat32Array
@export var packed_float64_array: PackedFloat64Array

@export var packed_string_array: PackedStringArray

@export var packed_vector2_array: PackedVector2Array
@export var packed_vector3_array: PackedVector3Array
@export var packed_vector4_array: PackedVector4Array
@export var packed_color_array: PackedColorArray

@export var dictionary: Dictionary
@export var typed_dictionary: Dictionary[int, int]
@export var object_dictionary: Dictionary[Resource, Resource]


static func generate() -> TestResource:

	var resource = TestResource.new()
	var trusted_resource = load("res://demo/external_trusted_resource.tres")
	var untrusted_resource = load("res://demo/external_untrusted_resource.tres")
	var unknown_resource = load("res://demo/external_unknown_resource.sav")

	resource.boolean = true
	resource.integer = 1
	resource.floating_point = 2.0
	resource.enumeration = TestResource.TestEnum.Three

	resource.string = "4"
	resource.string_name = &"5"
	resource.node_path = "."

	resource.sub_resource = TestResource.new()
	resource.sub_resource.boolean = true
	resource.sub_resource.sub_resource = resource

	resource.self_ref = resource
	resource.external_trusted_resource = trusted_resource
	resource.external_unknown_resource = unknown_resource
	resource.external_untrusted_resource = untrusted_resource

	resource.vector2 = Vector2.ONE
	resource.vector2i = Vector2i.ONE
	resource.vector3 = Vector3.ONE
	resource.vector3i = Vector3i.ONE
	resource.vector4 = Vector4.ONE
	resource.vector4i = Vector4i.ONE
	resource.color = Color.BEIGE

	resource.transform2d = Transform2D.FLIP_X
	resource.transform3d = Transform3D.FLIP_Y
	resource.basis = Basis.FLIP_Z
	resource.projection = Projection.IDENTITY

	resource.quaternion = Quaternion.IDENTITY

	resource.rect2 = Rect2(Vector2.ONE, Vector2.ONE)
	resource.rect2i = Rect2i(Vector2i.ONE, Vector2i.ONE)
	resource.aabb = AABB(Vector3.ONE, Vector3.ONE)

	resource.plane = Plane.PLANE_XY

	resource.array = [true, 1, 2.0, "3"]
	resource.typed_array.assign([1, 2, 3])
	resource.object_array.assign([
		trusted_resource,
		unknown_resource,
		null,
	])

	resource.packed_byte_array = [1, 2, 3]
	resource.packed_int32_array = [1, 2, 3]
	resource.packed_int64_array = [1, 2, 3]
	resource.packed_float32_array = [1, 2, 3]
	resource.packed_float64_array = [1, 2, 3]

	resource.packed_string_array = ["1", "2", "3"]

	resource.packed_vector2_array = [Vector2.ONE]
	resource.packed_vector3_array = [Vector3.ONE]
	resource.packed_vector4_array = [Vector4.ONE]
	resource.packed_color_array = [Color.BEIGE]

	resource.dictionary.assign({
		true: true,
		false: false,
		1: 1,
		2.0: 2.0,
		"3": "3",
	})
	resource.typed_dictionary.assign({
		1: 1,
		2: 2,
		3: 3,
	})
	resource.object_dictionary.assign({
		trusted_resource: trusted_resource,
		unknown_resource: unknown_resource,
		null: null,
	})

	return resource
