class_name SafeIOSaver extends ResourceFormatSaver

var _keep_compressed: bool
var _save_flags: ResourceSaver.SaverFlags


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	return SafeIO.get_recognized_extensions()


func _recognize(resource: Resource) -> bool:
	return resource != null


func _save(resource: Resource, path: String, flags: ResourceSaver.SaverFlags) -> Error:

	_keep_compressed = not path.ends_with(SafeIO.TEXT_FILE_FORMAT)
	_save_flags = flags
	var resource_data := _serialize_resource(resource)

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

	return Error.OK


## Attempts to save path information for [param resource] if possible.
## Will fallback to manual serialization if that is not possible.
func _serialize_external_resource(resource: Resource) -> Dictionary[String, String]:

	var register := SafeIO.get_register()
	var uid_string := ResourceUID.path_to_uid(resource.resource_path)

	if not register.is_resource_safe(uid_string):
		push_error(
			"[SafeIO]: Resource \"%s\" is not registered!" % resource.resource_path
			+ " Attempting to load without registering will fail!"
		)

	return { SafeIO.EXTERNAL_FILE_MARKER: uid_string }


## Converts [param resource] into a string-keyed [Dictionary].
func _serialize_resource(resource: Resource) -> Dictionary[String, Variant]:

	var properties := SafeIO.get_serializeable_properties(resource)
	var output: Dictionary[String, Variant]

	for property in properties.filter(_filter_default_values.bind(resource)):
		var value = resource.get(property)
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

	if value is Resource:

		if value.resource_path and _save_flags & ResourceSaver.FLAG_BUNDLE_RESOURCES == 0:
			return _serialize_external_resource(value)

		return _serialize_resource(value)

	if value is Object:

		var custom_script = value.get_script()
		var type_name = custom_script.get_global_name() if custom_script else value.get_class()
		push_error("[SafeIO]: Object serialization of type %s is not supported!" % type_name)
		return null

	if value is Dictionary:
		var dict: Dictionary[String, Variant]
		for key in value:
			dict[str(key)] = _serialize_value(value[key])
		return dict

	if value is Array:
		return value.map(_serialize_value)

	return value if _keep_compressed else JSON.from_native(value)


func _filter_default_values(property: String, resource: Resource) -> bool:

	var name = resource.get_class()
	if property not in ClassDB.class_get_property_list(name).map(func(p): return p["name"]):
		return true

	return ClassDB.class_get_property_default_value(name, property) != resource.get(property)
