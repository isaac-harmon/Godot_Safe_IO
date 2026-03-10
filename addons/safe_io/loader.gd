class_name SafeIOLoader extends ResourceFormatLoader

var _is_compressed: bool


func _get_recognized_extensions() -> PackedStringArray:
	return SafeIO.get_recognized_extensions()


func _get_resource_script_class(path: String) -> String:
	
	var data = _load_file(path)
	if data is not Dictionary or SafeIO.TYPE_MARKER not in data:
		return ""
	
	var register := SafeIO.get_register()
	if not register:
		return ""
	
	return register.get_registered_resource_type(str(data[SafeIO.TYPE_MARKER]))


func _get_resource_type(path: String) -> String:
	var type := _get_resource_script_class(path)
	return type if ClassDB.class_exists(type) else "Resource"


func _handles_type(type: StringName) -> bool:
	return true


func _load(
	path: String,
	_original_path: String,
	_use_sub_threads: bool,
	_cache_mode: ResourceFormatLoader.CacheMode
):
	var result = _load_file(path)
	if result is not Dictionary:
		return result as Error
	
	var resource := _deserialize_resource(result)
	if resource == null:
		return Error.ERR_FILE_CORRUPT
	
	resource.resource_path = path
	return resource


## Attempts to load and parse data from the file at [param path].
## Returns a [String]-keyed dictionary on success, or an [enum Error] on failure.
func _load_file(path: String):
	
	_is_compressed = not path.ends_with(SafeIO.TEXT_FILE_FORMAT)
	
	if _is_compressed:
		var file := FileAccess.open_compressed(path, FileAccess.READ)
		if not file:
			return FileAccess.get_open_error()
		
		return file.get_var()
	
	else:
		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			return FileAccess.get_open_error()
		
		var json := JSON.new()
		if json.parse(file.get_as_text()):
			return Error.ERR_PARSE_ERROR
		
		return json.data


## Verifies the safety of a data given it contains either a relative path or a uid,
## and if safe, will load and return the resource.
func _load_external_resource(uid_path: String) -> Resource:
	
	var register = SafeIO.get_register()
	if not register:
		return null
	
	if not register.is_resource_safe(uid_path):
		var path := ResourceUID.uid_to_path(uid_path)
		push_error("[SafeIO]: Attempted to load unsafe external resource \"%s\"! " % path)
		return null
	
	return load(uid_path)


## Converts any valid [Dictionary] into its corresponding type.
## Returns the [Resource] on success or a null value on failure.
func _deserialize_resource(data: Dictionary) -> Resource:
	
	var register = SafeIO.get_register()
	if not register:
		return null
	
	var type := str(data.get(SafeIO.TYPE_MARKER))
	var resource: Resource
	
	if ClassDB.class_exists(type):
		resource = ClassDB.instantiate(type)
	
	elif register.is_resource_safe(type):
		
		var script := load(type)
		
		if script is not Script:
			var path := ResourceUID.uid_to_path(type)
			push_error("[SafeIO]: Resource \"%s\" is not a valid type! " % path)
			return null
		
		resource = script.new()
	
	else:
		var path := ResourceUID.uid_to_path(type)
		push_error("[SafeIO]: Denied load of unsafe resource \"%s\"! " % path)
		return null
	
	for property in SafeIO.get_serializeable_properties(resource):
		var json_name := SafeIO.get_json_name(property)
		if data.has(json_name):
			resource.set(property, _deserialize_value(data[json_name]))
	
	return resource


## Converts [param value] into Variant-compatible types.
## If saving as [code].json5[/code], values will be converted via [method JSON.to_native].
func _deserialize_value(value):
	
	if value is Dictionary:
		if SafeIO.TYPE_MARKER in value:
			return _deserialize_resource(value)
		
		if SafeIO.EXTERNAL_FILE_MARKER in value:
			return _load_external_resource(value)
		
		if "type" in value and "args" in value:
			return JSON.to_native(value)
		
		var dict: Dictionary
		for key in value:
			dict[key] = _deserialize_value(value[key])
		return dict
	
	if value is Array:
		return value.map(_deserialize_value)
	
	return value if _is_compressed else JSON.to_native(value)
