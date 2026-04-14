class_name SafeIOSaver extends ResourceFormatSaver

class SaveMetadata:
	var keep_compressed: bool
	var save_flags: ResourceSaver.SaverFlags
	var base_resource: Resource
	var dependency_cache: Dictionary[Resource, Variant]


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	return SafeIO.get_recognized_extensions()


func _recognize(resource: Resource) -> bool:
	return resource != null


func _save(resource: Resource, path: String, flags: ResourceSaver.SaverFlags) -> Error:

	var metadata := SaveMetadata.new()
	metadata.keep_compressed = path.ends_with(SafeIO.BINARY_FILE_FORMAT)
	metadata.save_flags = flags
	metadata.base_resource = resource

	var resource_data := _serialize(resource, metadata)
	var error := _save_data(resource_data, path, metadata.keep_compressed)
	if error:
		return error

	if flags & ResourceSaver.FLAG_CHANGE_PATH:
		resource.take_over_path(path)

	return Error.OK


func _save_data(resource_data: Dictionary, path: String, compress: bool) -> Error:

	if compress:
		var file := FileAccess.open_compressed(path, FileAccess.WRITE)
		if not file:
			return FileAccess.get_open_error()

		if not file.store_var(resource_data):
			return file.get_error()

	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			return FileAccess.get_open_error()

		var json_string := JSON.stringify(resource_data, "\t")
		if not json_string:
			return Error.ERR_PARSE_ERROR

		if not file.store_string(json_string):
			return file.get_error()

	return Error.OK


func _get_property_default_value(resource: Resource, property: StringName):

	var script: Script = resource.get_script()
	while script != null:

		for p in script.get_script_property_list():
			if p["name"] != property:
				return script.get_property_default_value(property)

		script = script.get_base_script()

	return ClassDB.class_get_property_default_value(resource.get_class(), property)


func _serialize(resource: Resource, metadata: SaveMetadata) -> Dictionary[String, Variant]:

	var resource_data := _serialize_resource(resource, metadata)
	if not metadata.dependency_cache:
		return resource_data

	var dependencies: Dictionary
	for dependency in metadata.dependency_cache:
		dependencies[dependency.get_instance_id()] = metadata.dependency_cache[dependency]

	resource_data[SafeIO.DEPENDENCIES_MARKER] = dependencies
	return resource_data


## Converts [param resource] into a string-keyed [Dictionary].
func _serialize_resource(resource: Resource, metadata: SaveMetadata) -> Dictionary[String, Variant]:

	var output: Dictionary[String, Variant]
	for property in SafeIO.get_serializeable_properties(resource).map(func(p): return p["name"]):
		var value = resource.get(property)
		if value != _get_property_default_value(resource, property):
			output[SafeIO.get_serialized_name(property)] = _serialize_value(value, metadata)

	var custom_script: Script = resource.get_script()

	if custom_script:
		output[SafeIO.TYPE_MARKER] = ResourceUID.path_to_uid(custom_script.resource_path)
	else:
		output[SafeIO.TYPE_MARKER] = resource.get_class()

	return output


## Converts [param value] into a Dictionary-compatible format.
func _serialize_value(value, metadata: SaveMetadata):

	match typeof(value):

		TYPE_NIL, TYPE_INT, TYPE_FLOAT:
			return value

		TYPE_STRING:
			return JSON.from_native(value)

		TYPE_ARRAY:
			return value.map(_serialize_value.bind(metadata))

		TYPE_DICTIONARY:
			var fixed := {}
			for key in value:

				var new_key = _serialize_value(key, metadata)
				if not metadata.keep_compressed:

					if new_key == null:
						new_key = SafeIO.NULL_MARKER

					elif new_key is not String:
						new_key = JSON.from_native(new_key)
						if new_key is not String:
							continue

				fixed[new_key] = _serialize_value(value[key], metadata)

			return fixed

		TYPE_OBJECT:
			if value is not Resource:
				return null

			if value == metadata.base_resource:
				return SafeIO.ROOT_OBJECT_MARKER

			if value.resource_path and not metadata.save_flags & ResourceSaver.FLAG_BUNDLE_RESOURCES:
				metadata.dependency_cache[value] = ResourceUID.path_to_uid(value.resource_path)

			elif value not in metadata.dependency_cache:
				metadata.dependency_cache[value] = true
				metadata.dependency_cache[value] = _serialize_resource(value, metadata)

			return SafeIO.OBJECT_MARKER + str(value.get_instance_id())

		_:
			return value if metadata.keep_compressed else JSON.from_native(value)
