class_name SafeResourceIOLoader extends ResourceFormatLoader


func _get_recognized_extensions() -> PackedStringArray:
	return SafeResourceIO.get_recognized_extensions()


func _get_resource_script_class(path: String) -> String:

	var file_contents = _load_file(path)
	if file_contents is Error:
		return ""

	var type := str(file_contents.get(SafeResourceIO.TYPE_MARKER))
	var register := SafeResourceIORegister.get_register()
	return register.get_registered_script_name(path) if register else ""


func _get_resource_type(path: String) -> String:

	var file_contents = _load_file(path)
	if file_contents is Error:
		return ""

	var type := str(file_contents.get(SafeResourceIO.TYPE_MARKER))
	return type if ClassDB.class_exists(type) else "Resource"


func _handles_type(_type: StringName) -> bool:
	return true


func _load(path: String, _original_path: String, _use_sub_threads: bool, cache_mode: CacheMode):

	path = ResourceUID.ensure_path(path)

	var load_result = _load_file(path)

	if load_result is Error:
		return load_result

	var dependency_data = load_result.get(SafeResourceIO.DEPENDENCIES_MARKER)
	var metadata := LoadMetadata.new(
		dependency_data if dependency_data is Dictionary else {},
		cache_mode
	)

	var resource := _deserialize_resource(load_result, metadata)
	if resource == null:
		return Error.ERR_FILE_CORRUPT

	return resource


func _load_dependency(object_id: int, metadata: LoadMetadata) -> Resource:

	var cached_data = metadata.dependency_cache.get(object_id)
	var result: Resource

	match typeof(cached_data):

		TYPE_OBJECT:
			return cached_data

		TYPE_DICTIONARY:
			result = _deserialize_resource(cached_data, metadata)

		TYPE_STRING:
			var register = SafeResourceIORegister.get_register()
			if register != null and register.is_resource_safe(cached_data):
				result = ResourceLoader.load(cached_data, "", metadata.cache_mode)

		_:
			return null

	metadata.dependency_cache[object_id] = result
	return result


## Attempts to load and parse data from the file at [param path].
## Returns a [String]-keyed dictionary on success, or an [enum Error] on failure.
func _load_file(path: String):

	var data
	if path.ends_with(SafeResourceIO.BINARY_FILE_FORMAT):
		var file := FileAccess.open_compressed(path, FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()

		data = file.get_var()

	else:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return FileAccess.get_open_error()

		var json := JSON.new()
		if json.parse(file.get_as_text()):
			return Error.ERR_PARSE_ERROR

		data = json.data

	return data if data is Dictionary else Error.ERR_INVALID_DATA


func _deserialize_array(array: Array, metadata: LoadMetadata):

	if array[0] is String and ":" not in array[0]:
		return JSON.to_native({ "type": array[0], "args": array.slice(1) })

	return array.map(_deserialize_value.bind(metadata))


func _deserialize_dictionary(dict: Dictionary, metadata: LoadMetadata) -> Dictionary:

	var output: Dictionary
	for key in dict:

		var converted_key
		match key:
			"<null>": converted_key = null
			"false": converted_key = false
			"true": converted_key = true
			_: converted_key = _deserialize_value(key, metadata)

		output[converted_key] = _deserialize_value(dict[key], metadata)

	return output


## Converts any valid [Dictionary] into its corresponding type.
## Returns the [Resource] on success or a null value on failure.
func _deserialize_resource(object_data: Dictionary, metadata: LoadMetadata) -> Resource:

	var type := str(object_data.get(SafeResourceIO.TYPE_MARKER))
	var resource := _instantiate_resource(type)
	if resource == null:
		return null

	if metadata.base_resource == null:
		metadata.base_resource = resource

	var property_list := SafeResourceIO.get_serializeable_properties(resource)
	var name_expression := SafeResourceIO.get_name_expression()
	
	for property in property_list:

		var json_name := str(name_expression.execute([property]))
		if name_expression.has_execute_failed() or json_name not in object_data:
			continue

		var value = _deserialize_value(object_data[json_name], metadata)
		var property_type: Variant.Type = property_list[property]

		if property_type == TYPE_ARRAY or property_type == TYPE_DICTIONARY:
			var existing_value = resource.get(property)
			existing_value.assign(value)
			value = existing_value

		resource.set(property, value)

	return resource


func _deserialize_string(str: String, metadata: LoadMetadata):

	if str == SafeResourceIO.ROOT_OBJECT_MARKER:
		return metadata.base_resource

	if str.begins_with(SafeResourceIO.OBJECT_MARKER):
		return _load_dependency(str.trim_prefix(SafeResourceIO.OBJECT_MARKER).to_int(), metadata)

	return JSON.to_native(str)


func _deserialize_value(value, metadata: LoadMetadata):

	match typeof(value):

		TYPE_STRING:
			return _deserialize_string(value, metadata)

		TYPE_ARRAY:
			return _deserialize_array(value, metadata)

		TYPE_DICTIONARY:
			return _deserialize_dictionary(value, metadata)

		_:
			return value


## Instantiates a resource of the given type.
## Expects the name of a built-in type, or the path to a custom script.
func _instantiate_resource(type: String) -> Resource:

	var register = SafeResourceIORegister.get_register()
	if register == null:
		return null

	if not register.is_resource_safe(type):
		return null

	if ClassDB.class_exists(type):
		return ClassDB.instantiate(type)

	var script := load(type)
	if script is not Script:
		return null

	var base_class: StringName = script.get_instance_base_type()
	if not ClassDB.is_parent_class(base_class, &"Resource"):
		return null

	return script.new()


class LoadMetadata:

	## The top level resource being loaded
	var base_resource: Resource

	## Cache mode for external dependencies
	var cache_mode: ResourceLoader.CacheMode

	## Data for all needed dependencies, keyed by an id.
	## The type of resulting value will determine how they need to be handled.[br][br]
	## [Dictionary]: Sub-resource[br]
	## [String]: External resource[br]
	## [Object]: A cached resource that was previously loaded[br][br]
	## Any other types are invalid data and should be discarded.
	var dependency_cache: Dictionary[int, Variant]


	func _init(dependency_data: Dictionary, cache_mode: ResourceFormatLoader.CacheMode) -> void:

		match cache_mode:

			ResourceFormatLoader.CACHE_MODE_IGNORE_DEEP:
				self.cache_mode = ResourceLoader.CACHE_MODE_IGNORE_DEEP

			ResourceFormatLoader.CACHE_MODE_REPLACE_DEEP:
				self.cache_mode = ResourceLoader.CACHE_MODE_REPLACE_DEEP

			_:
				self.cache_mode = ResourceLoader.CACHE_MODE_REUSE

		for entry in dependency_data:

			var id: int
			match typeof(entry):
				TYPE_INT: id = entry
				TYPE_STRING: id = entry.to_int()
				_: continue

			dependency_cache[id] = dependency_data[entry]
