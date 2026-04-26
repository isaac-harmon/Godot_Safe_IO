class_name SafeIOLoader extends ResourceFormatLoader


class LoadMetadata:

	var base_resource: Resource
	var cache_mode: ResourceLoader.CacheMode
	var raw_dependency_data: Dictionary[int, Variant]
	var dependency_cache: Dictionary[int, Resource]


	func _init(dependency_data: Dictionary, cache_mode: ResourceFormatLoader.CacheMode) -> void:

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


func _get_recognized_extensions() -> PackedStringArray:
	return SafeIO.get_recognized_extensions()


func _get_resource_script_class(path: String) -> String:

	var file_contents = _load_file(path)
	if file_contents is Error:
		return ""

	var type := str(file_contents.get(SafeIO.TYPE_MARKER))
	var register := SafeIOResourceRegister.get_register()
	return register.get_registered_script_name(path) if register else ""


func _get_resource_type(path: String) -> String:

	var file_contents = _load_file(path)
	if file_contents is Error:
		return ""

	var type := str(file_contents.get(SafeIO.TYPE_MARKER))
	return type if ClassDB.class_exists(type) else "Resource"


func _handles_type(_type: StringName) -> bool:
	return true


func _load(path: String, _original_path: String, _use_sub_threads: bool, cache_mode: CacheMode):

	path = ResourceUID.ensure_path(path)
	var load_result = _load_file(path)
	if load_result is Error:
		return load_result

	var dependency_data = load_result.get(SafeIO.DEPENDENCIES_MARKER)
	var metadata := LoadMetadata.new(dependency_data if dependency_data is Dictionary else {}, cache_mode)
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
func _load_file(path: String):

	var data
	if path.ends_with(SafeIO.BINARY_FILE_FORMAT):
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


func _deserialize_string(string: String, metadata: LoadMetadata):

	if string.begins_with(SafeIO.OBJECT_MARKER):
		return _load_dependency(string.trim_prefix(SafeIO.OBJECT_MARKER).to_int(), metadata)

	if string == SafeIO.ROOT_OBJECT_MARKER:
		return metadata.base_resource

	match string.get_slice(":", 0):
		"s", "sn", "np", "i", "f":
			return JSON.to_native(string)

	match string.get_slice("(", 0):
		"object", "resource", "subresource", "extresource":
			return string

	return str_to_var(string)


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

		var value = _deserialize_value(object_data[json_name], metadata)

		if property_list[property] == TYPE_ARRAY or property_list[property] == TYPE_DICTIONARY:
			var current = resource.get(property)
			current.assign(value)
			value = current

		resource.set(property, value)

	return resource


func _deserialize_value(value, metadata: LoadMetadata):

	match typeof(value):

		TYPE_STRING:
			return _deserialize_string(value, metadata)

		TYPE_ARRAY:
			return value.map(_deserialize_value.bind(metadata))

		TYPE_DICTIONARY:
			var dict: Dictionary
			for key in value:
				dict[_deserialize_value(key, metadata)] = _deserialize_value(value[key], metadata)
			return dict

		_:
			return value


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
