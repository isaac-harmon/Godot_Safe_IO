class_name SafeIOSaver extends ResourceFormatSaver

var _keep_compressed: bool
var _save_flags: ResourceSaver.SaverFlags
var _dependency_cache: Dictionary[Resource, Variant]


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	return SafeIO.get_recognized_extensions()


func _recognize(resource: Resource) -> bool:
	return resource != null


func _save(resource: Resource, path: String, flags: ResourceSaver.SaverFlags) -> Error:

	_keep_compressed = not path.ends_with(SafeIO.TEXT_FILE_FORMAT)
	_save_flags = flags
	_dependency_cache = {}
	
	var resource_data := _serialize_resource(resource)
	
	if _dependency_cache:
		var dependencies: Dictionary
		for dependency in _dependency_cache:
			dependencies[_serialize_value(dependency.get_instance_id())] = _dependency_cache[dependency]
		
		resource_data[SafeIO.DEPENDENCIES_MARKER] = dependencies
	
	if _keep_compressed:
		var file := FileAccess.open_compressed(path, FileAccess.WRITE)
		if not file:
			return Error.ERR_FILE_CANT_WRITE

		file.store_var(resource_data)

	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			return Error.ERR_FILE_CANT_WRITE

		var json_string := JSON.stringify(resource_data, "\t")
		if not json_string:
			return Error.ERR_PARSE_ERROR

		file.store_string(json_string)

	_dependency_cache = {}
	return Error.OK


func _get_property_default_value(resource: Resource, property: StringName):

	var script: Script = resource.get_script()
	while script != null:

		for p in script.get_script_property_list():
			if p["name"] != property:
				return script.get_property_default_value(property)

		script = script.get_base_script()

	return ClassDB.class_get_property_default_value(resource.get_class(), property)


## Converts [param resource] into a string-keyed [Dictionary].
func _serialize_resource(resource: Resource) -> Dictionary[String, Variant]:

	var output: Dictionary[String, Variant]
	for property in SafeIO.get_serializeable_properties(resource).map(func(p): return p["name"]):
		var value = resource.get(property)
		if value != _get_property_default_value(resource, property):
			output[SafeIO.get_json_name(property)] = _serialize_value(value)

	var custom_script: Script = resource.get_script()

	if custom_script:
		output[SafeIO.TYPE_MARKER] = ResourceUID.path_to_uid(custom_script.resource_path)
	else:
		output[SafeIO.TYPE_MARKER] = resource.get_class()

	return output


## Converts [param value] into a Dictionary-compatible format.
## If saving as [code].json5[/code], values will be stored in a compatible format,
## via [method JSON.from_native].
func _serialize_value(value):

	if value is Object:

		if value is not Resource:
			return null

		if value.resource_path and not _save_flags & ResourceSaver.FLAG_BUNDLE_RESOURCES:
			_dependency_cache[value] = ResourceUID.path_to_uid(value.resource_path)

		elif value not in _dependency_cache:
			_dependency_cache[value] = _serialize_resource(value)

		return SafeIO.OBJECT_MARKER + str(value.get_instance_id())

	elif value is Dictionary:
		var fixed := {}
		for key in value:
			var new_key = SafeIO.NULL_MARKER if key == null else _serialize_value(key)
			fixed[new_key] = _serialize_value(value[key])
		return fixed

	elif value is Array:
		return value.map(_serialize_value)

	return value if _keep_compressed else JSON.from_native(value)
