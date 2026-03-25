class_name SafeIOSaver extends ResourceFormatSaver

var _keep_compressed: bool
var _save_flags: ResourceSaver.SaverFlags
var _base_resource: Resource


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	return SafeIO.get_recognized_extensions()


func _recognize(resource: Resource) -> bool:
	return resource != null


func _save(resource: Resource, path: String, flags: ResourceSaver.SaverFlags) -> Error:
	
	_keep_compressed = path.ends_with(SafeIO.BINARY_FILE_FORMAT)
	_save_flags = flags
	_base_resource = resource
	
	var resource_data := _serialize(resource)
	var error := _save_data(resource_data, path)

	if error:
		return error

	if flags & ResourceSaver.FLAG_CHANGE_PATH:
		resource.take_over_path(path)

	return OK


func _save_data(resource_data: Dictionary, path: String) -> Error:

	if _keep_compressed:
		var file := FileAccess.open_compressed(path, FileAccess.WRITE)
		if not file:
			return Error.ERR_FILE_CANT_OPEN

		if not file.store_var(resource_data):
			return Error.ERR_FILE_CANT_WRITE

	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			return Error.ERR_FILE_CANT_OPEN

		var json_string := JSON.stringify(resource_data, "\t")
		if not json_string:
			return Error.ERR_PARSE_ERROR

		if not file.store_string(json_string):
			return Error.ERR_FILE_CANT_WRITE

	return OK


func _get_property_default_value(resource: Resource, property: StringName):

	var script: Script = resource.get_script()
	while script != null:

		for p in script.get_script_property_list():
			if p["name"] != property:
				return script.get_property_default_value(property)

		script = script.get_base_script()

	return ClassDB.class_get_property_default_value(resource.get_class(), property)


func _serialize(resource: Resource) -> Dictionary[String, Variant]:

	var dependency_cache: Dictionary[Resource, Variant]
	var resource_data := _serialize_resource(resource, dependency_cache)

	if not dependency_cache:
		return resource_data

	var dependencies: Dictionary
	for dependency in dependency_cache:
		var index = _serialize_value(dependency.get_instance_id(), dependency_cache)
		dependencies[index] = dependency_cache[dependency]

	resource_data[SafeIO.DEPENDENCIES_MARKER] = dependencies
	return resource_data


## Converts [param resource] into a string-keyed [Dictionary].
func _serialize_resource(resource: Resource, dependency_cache: Dictionary[Resource, Variant]) -> Dictionary[String, Variant]:

	var output: Dictionary[String, Variant]
	for property in SafeIO.get_serializeable_properties(resource).map(func(p): return p["name"]):
		var value = resource.get(property)
		if value != _get_property_default_value(resource, property):
			output[SafeIO.get_serialized_name(property)] = _serialize_value(value, dependency_cache)

	var custom_script: Script = resource.get_script()

	if custom_script:
		output[SafeIO.TYPE_MARKER] = ResourceUID.path_to_uid(custom_script.resource_path)
	else:
		output[SafeIO.TYPE_MARKER] = resource.get_class()

	return output


## Converts [param value] into a Dictionary-compatible format.
func _serialize_value(value, dependency_cache: Dictionary[Resource, Variant]):

	if value is Object:

		if value is not Resource:
			return null

		if value == _base_resource:
			return SafeIO.ROOT_OBJECT_MARKER

		if value.resource_path and not _save_flags & ResourceSaver.FLAG_BUNDLE_RESOURCES:
			dependency_cache[value] = ResourceUID.path_to_uid(value.resource_path)

		elif value not in dependency_cache:
			dependency_cache[value] = true
			dependency_cache[value] = _serialize_resource(value, dependency_cache)

		return SafeIO.OBJECT_MARKER + str(value.get_instance_id())

	if value is Dictionary:

		var fixed := {}
		for key in value:
			var new_key = SafeIO.NULL_MARKER if key == null else _serialize_value(key, dependency_cache)
			fixed[new_key] = _serialize_value(value[key], dependency_cache)

		return fixed

	if value is Array:
		return value.map(_serialize_value.bind(dependency_cache))

	if value is String:
		return JSON.from_native(value)

	if value == null or _keep_compressed:
		return value

	return JSON.from_native(value)
