class_name SafeResourceIOSaver extends ResourceFormatSaver

class SaveMetadata:
	var keep_compressed: bool
	var save_flags: ResourceSaver.SaverFlags
	var base_resource: Resource
	var dependency_cache: Dictionary[int, Variant]


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	return SafeResourceIO.get_recognized_extensions()


func _recognize(resource: Resource) -> bool:
	return resource != null


func _save(resource: Resource, path: String, flags: ResourceSaver.SaverFlags) -> Error:

	var metadata := SaveMetadata.new()
	metadata.keep_compressed = path.ends_with(SafeResourceIO.BINARY_FILE_FORMAT)
	metadata.save_flags = flags
	metadata.base_resource = resource

	var resource_data := _serialize_resource(resource, metadata)
	if metadata.dependency_cache:
		resource_data[SafeResourceIO.DEPENDENCIES_MARKER] = metadata.dependency_cache

	return _save_to_file(resource_data, path, metadata.keep_compressed)


func _save_to_file(resource_data: Dictionary, path: String, compress: bool) -> Error:

	if compress:
		var file := FileAccess.open_compressed(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()

		if not file.store_var(resource_data):
			return file.get_error()

	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()

		var json_string := JSON.stringify(resource_data, "\t")
		if not json_string:
			return Error.ERR_PARSE_ERROR

		if not file.store_string(json_string):
			return file.get_error()

	return Error.OK


## Finds the default value of a property with name [param property] for the resource [param resource].
## Assumes a property exists under that name.
func _get_property_default_value(resource: Resource, property: StringName):

	var script: Script = resource.get_script()
	while script != null:

		if property in script.get_script_property_list().map(func(p: Dictionary) -> String: return p.name):
			return script.get_property_default_value(property)

		script = script.get_base_script()

	return ClassDB.class_get_property_default_value(resource.get_class(), property)


func _serialize_dictionary(dictionary: Dictionary, metadata: SaveMetadata) -> Dictionary:

	var serialized := {}
	for key in dictionary:

		var new_key = _serialize_value(key, metadata)
		match typeof(new_key):

			TYPE_NIL, TYPE_BOOL, TYPE_STRING:
				pass

			_ when not metadata.keep_compressed:
				new_key = JSON.from_native(new_key)
				if new_key is not String:
					continue

		serialized[new_key] = _serialize_value(dictionary[key], metadata)

	return serialized


func _serialize_resource(resource: Resource, metadata: SaveMetadata) -> Dictionary[String, Variant]:

	var output: Dictionary[String, Variant]
	for property in SafeResourceIO.get_serializeable_properties(resource):
		var value = resource.get(property)
		if value != _get_property_default_value(resource, property):
			output[SafeResourceIO.get_serialized_name(property)] = _serialize_value(value, metadata)

	var custom_script: Script = resource.get_script()

	if custom_script:
		output[SafeResourceIO.TYPE_MARKER] = ResourceUID.path_to_uid(custom_script.resource_path)
	else:
		output[SafeResourceIO.TYPE_MARKER] = resource.get_class()

	return output


func _serialize_value(value, metadata: SaveMetadata):

	match typeof(value):

		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return value

		TYPE_STRING:
			return JSON.from_native(value)

		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return value if metadata.keep_compressed else JSON.from_native(value)

		TYPE_ARRAY:
			return value.map(_serialize_value.bind(metadata))

		TYPE_DICTIONARY:
			return _serialize_dictionary(value, metadata)

		TYPE_OBJECT:
			if value is not Resource:
				return null

			if value == metadata.base_resource:
				return SafeResourceIO.ROOT_OBJECT_MARKER

			return _update_dependency_cache(value, metadata)

		_:
			if metadata.keep_compressed:
				return value 

			var json_output: Dictionary = JSON.from_native(value)
			json_output.args.push_front(json_output.type)
			return json_output.args


func _update_dependency_cache(resource: Resource, metadata: SaveMetadata) -> String:

	var object_id: int = resource.get_instance_id()

	if object_id not in metadata.dependency_cache:
		if (
			not metadata.save_flags & ResourceSaver.FLAG_BUNDLE_RESOURCES
			and resource.resource_path
			and ResourceLoader.exists(resource.resource_path)
		):
			metadata.dependency_cache[object_id] = ResourceUID.path_to_uid(resource.resource_path)

		else:
			metadata.dependency_cache[object_id] = true # Prevents infinite recursion
			metadata.dependency_cache[object_id] = _serialize_resource(resource, metadata)

	return SafeResourceIO.OBJECT_MARKER + str(object_id)
