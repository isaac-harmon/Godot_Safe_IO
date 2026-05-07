class_name SafeIOLoader extends ResourceFormatLoader


class LoadMetadata:

	var base_resource: Resource
	var cache_mode: ResourceLoader.CacheMode
	var is_compressed: bool

	var raw_dependency_data: Dictionary[int, Variant]
	var dependency_cache: Dictionary[int, Resource]


	func _init(dependency_data: Dictionary, cache_mode: ResourceFormatLoader.CacheMode, is_compressed: bool) -> void:

		match cache_mode:

			ResourceFormatLoader.CACHE_MODE_IGNORE_DEEP:
				self.cache_mode = ResourceLoader.CACHE_MODE_IGNORE_DEEP

			ResourceFormatLoader.CACHE_MODE_REPLACE_DEEP:
				self.cache_mode = ResourceLoader.CACHE_MODE_REPLACE_DEEP

			_:
				self.cache_mode = ResourceLoader.CACHE_MODE_REUSE

		for entry in dependency_data:

			var object_id: int
			match typeof(entry):

				TYPE_INT:
					object_id = entry

				TYPE_STRING:
					object_id = entry.to_int()

				_:
					continue

			raw_dependency_data[object_id] = dependency_data[entry]

		self.is_compressed = is_compressed


func _get_recognized_extensions() -> PackedStringArray:
	return SafeIO.get_recognized_extensions()


func _get_resource_script_class(path: String) -> String:

	var file_contents = _load_file(path, _is_file_compressed(path))
	if file_contents is Error:
		return ""

	var type := str(file_contents.get(SafeIO.TYPE_MARKER))
	var register := SafeIOResourceRegister.get_register()
	return register.get_registered_script_name(path) if register else ""


func _get_resource_type(path: String) -> String:

	var file_contents = _load_file(path, _is_file_compressed(path))
	if file_contents is Error:
		return ""

	var type := str(file_contents.get(SafeIO.TYPE_MARKER))
	return type if ClassDB.class_exists(type) else "Resource"


func _handles_type(_type: StringName) -> bool:
	return true


func _load(path: String, _original_path: String, _use_sub_threads: bool, cache_mode: CacheMode):

	path = ResourceUID.ensure_path(path)
	
	var is_compressed = _is_file_compressed(path)
	var load_result = _load_file(path, is_compressed)
	if load_result is Error:
		return load_result

	var dependency_data = load_result.get(SafeIO.DEPENDENCIES_MARKER)
	
	var metadata := LoadMetadata.new(
		dependency_data if dependency_data is Dictionary else {},
		cache_mode,
		is_compressed
	)
	
	var resource := _deserialize_resource(load_result, metadata)
	if resource == null:
		return Error.ERR_FILE_CORRUPT

	return resource


func _load_dependency(object_id: int, metadata: LoadMetadata) -> Resource:

	if object_id in metadata.dependency_cache:
		return metadata.dependency_cache[object_id]

	var object_data = metadata.raw_dependency_data.get(object_id)
	var result: Resource

	match typeof(object_data):

		TYPE_DICTIONARY:
			result = _deserialize_resource(object_data, metadata)

		TYPE_STRING:
			var register = SafeIOResourceRegister.get_register()
			if not register or not register.is_resource_safe(object_data):
				return null
			else:
				result = ResourceLoader.load(object_data, "", metadata.cache_mode)

		_:
			return null

	metadata.dependency_cache[object_id] = result
	return result


## Attempts to load and parse data from the file at [param path].
## Returns a [String]-keyed dictionary on success, or an [enum Error] on failure.
func _load_file(path: String, is_compressed: bool):

	var data
	if is_compressed:
		var file := FileAccess.open_compressed(path, FileAccess.READ)
		if not file:
			return FileAccess.get_open_error()

		data = file.get_var()

	else:
		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			return FileAccess.get_open_error()

		var json := JSON.new()
		if json.parse(file.get_as_text()):
			return Error.ERR_PARSE_ERROR

		data = json.data

	return data if data is Dictionary else Error.ERR_INVALID_DATA


## Turns arrays into the complex [enum Variant.Type] specified by [param type].
## Ex: Vector2, Transform3D, Rect2i, etc...
func _deserialize_complex_type(type: Variant.Type, args: Array):

	var type_name: String
	match type:

		TYPE_RECT2, TYPE_RECT2I: type_name = "Rect2"
		TYPE_VECTOR2, TYPE_VECTOR2I: type_name = "Vector2"
		TYPE_VECTOR3, TYPE_VECTOR3I: type_name = "Vector3"
		TYPE_VECTOR4, TYPE_VECTOR4I: type_name = "Vector4"
		TYPE_COLOR: type_name = "Color"

		TYPE_AABB: type_name = "AABB"
		TYPE_BASIS: type_name = "Basis"
		TYPE_PLANE: type_name = "Plane"
		TYPE_TRANSFORM2D: type_name = "Transform2D"
		TYPE_TRANSFORM3D: type_name = "Transform3D"

		TYPE_PACKED_COLOR_ARRAY: type_name = "PackedColorArray"
		TYPE_PACKED_VECTOR2_ARRAY: type_name = "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: type_name = "PackedVector3Array"
		TYPE_PACKED_VECTOR4_ARRAY: type_name = "PackedVector4Array"

		_: return args

	return JSON.to_native({
		"args": args,
		"type": type_name,
	})


func _deserialize_dictionary(new_dict: Dictionary, key_type: Variant.Type,
	value_type: Variant.Type, metadata: LoadMetadata) -> Dictionary:

	var output: Dictionary
	for key in new_dict:

		var converted_key
		match key:
			_ when metadata.is_compressed: converted_key = key

			"<null>": converted_key = null
			"false": converted_key = false
			"true": converted_key = true
			
			_ when key.begins_with(SafeIO.OBJECT_MARKER): converted_key = key

			_: converted_key = JSON.to_native(key)

		converted_key = _deserialize_value(
			converted_key,
			converted_key,
			key_type,
			metadata
		)

		var converted_value = _deserialize_value(
			new_dict[key],
			new_dict[key],
			value_type,
			metadata
		)

		output[converted_key] = converted_value

	return output


func _deserialize_string(string: String, metadata: LoadMetadata, load_objects := true):

	if load_objects and string == SafeIO.ROOT_OBJECT_MARKER:
		return metadata.base_resource

	if load_objects and string is String and string.begins_with(SafeIO.OBJECT_MARKER):
		return _load_dependency(string.trim_prefix(SafeIO.OBJECT_MARKER).to_int(), metadata)

	return string if not metadata.is_compressed else JSON.to_native(string)


## Converts any valid [Dictionary] into its corresponding type.
## Returns the [Resource] on success or a null value on failure.
func _deserialize_resource(object_data: Dictionary, metadata: LoadMetadata) -> Resource:

	var type := str(object_data.get(SafeIO.TYPE_MARKER))
	var resource := _instantiate_resource(type)
	if resource == null:
		return null

	if metadata.base_resource == null:
		metadata.base_resource = resource

	var property_list := SafeIO.get_serializeable_properties(resource)
	for property in property_list:

		var json_name := SafeIO.get_serialized_name(property)
		if not json_name in object_data:
			continue

		var value = _deserialize_value(
			object_data[json_name],
			resource.get(property),
			property_list[property],
			metadata
		)

		resource.set(property, value)

	return resource


func _deserialize_value(new_value, current_value, type: Variant.Type, metadata: LoadMetadata):

	match type:

		TYPE_ARRAY:
			var mapped: Array = new_value.map(func(entry):
				return _deserialize_value(
					entry,
					entry,
					current_value.get_typed_builtin(),
					metadata
				)
			)
			
			current_value.assign(mapped)
			return current_value

		TYPE_DICTIONARY:
			var mapped: Dictionary = _deserialize_dictionary(
				new_value,
				current_value.get_typed_key_builtin(),
				current_value.get_typed_value_builtin(),
				metadata
			)
			
			current_value.assign(mapped)
			return current_value

		TYPE_OBJECT:
			var output = _deserialize_string(new_value, metadata) if new_value is String else new_value
			return output if output is Resource else null

		_ when new_value is Array:
			return _deserialize_complex_type(type, new_value)

		_ when new_value is String:
			return _deserialize_string(new_value, metadata, type != TYPE_STRING)

		_:
			return new_value


## Instantiates a resource of the given type.
## Expects the name of a built-in type, or the path to a custom script.
func _instantiate_resource(type: String) -> Resource:

	var register = SafeIOResourceRegister.get_register()
	if not register:
		return null

	if ClassDB.class_exists(type):

		if not ClassDB.is_parent_class(type, &"Resource"):
			return null

		return ClassDB.instantiate(type)

	if not register.is_resource_safe(type):
		return null

	var script := load(type)
	if script is not Script:
		return null

	var base_class: StringName = script.get_instance_base_type()
	if not ClassDB.is_parent_class(base_class, &"Resource"):
		return null

	return script.new()


func _is_file_compressed(path: String) -> bool:
	return path.ends_with(SafeIO.BINARY_FILE_FORMAT)
