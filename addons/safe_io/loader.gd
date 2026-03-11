class_name SafeIOLoader extends ResourceFormatLoader

var _is_compressed: bool

# TODO: Add cache for loaded reosurces

## Array of [Dictionary[int, Resource]] for all loaded sub-resources.
## Access the relevant stack by reading the last index.
var _dependency_cache: Array[Dictionary]

## Array of [Dictionary[int, Variant]] for all unloaded resource data.
## Sub-resources will have a dictionary of data, and external resources will have just the path.
## Access the relevant stack by reading the last index.
var _raw_dependency_data: Array[Dictionary]


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
	
	_dependency_cache.push_back({})
	_raw_dependency_data.push_back({})
	
	if SafeIO.DEPENDENCIES_MARKER in result:
		var dependencies = result[SafeIO.DEPENDENCIES_MARKER] as Dictionary
		for entry in dependencies:
			_raw_dependency_data[-1][_deserialize_value(entry) as int] = dependencies[entry]
	
	var resource := _deserialize_resource(result)
	if resource == null:
		return Error.ERR_FILE_CORRUPT
	
	_dependency_cache.pop_back()
	_raw_dependency_data.pop_back()
	
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


func _load_dependency(id: int) -> Resource:
	
	if id in _dependency_cache[-1]:
		return _dependency_cache[-1][id]
	
	var data = _raw_dependency_data[-1].get(id)
	if data is Dictionary:
		_dependency_cache[-1][id] = _deserialize_resource(data)
	
	elif data is String:
		_dependency_cache[-1][id] = _load_external_resource(data)
	
	else:
		return null
	
	return _dependency_cache[-1][id]


## Verifies the safety of the resource at [param path],
## and if safe, will load and return the resource.
func _load_external_resource(path: String) -> Resource:
	
	var register = SafeIO.get_register()
	if not register:
		return null
	
	if not register.is_resource_safe(path):
		return null
	
	return load(path)


## Converts any valid [Dictionary] into its corresponding type.
## Returns the [Resource] on success or a null value on failure.
func _deserialize_resource(data: Dictionary) -> Resource:
	
	var type := str(data.get(SafeIO.TYPE_MARKER))
	var resource := _instantiate_resource(type)
	if resource == null:
		return null
	
	for property in SafeIO.get_serializeable_properties(resource):
		
		var json_name := SafeIO.get_json_name(property["name"])
		if not json_name in data:
			continue
		
		var value = _deserialize_value(data[json_name])
		
		if property["type"] == TYPE_ARRAY or property["type"] == TYPE_DICTIONARY:
			var current = resource.get(property["name"])
			current.assign(value)
			continue
		
		resource.set(property["name"], value)
	
	return resource


## Converts [param value] into Variant-compatible types.
## If saving as [code].json5[/code], values will be converted via [method JSON.to_native].
func _deserialize_value(value):
	
	if value is Dictionary:
		
		if "args" in value and "type" in value:
			return JSON.to_native(value)
		
		var dict: Dictionary
		for key in value:
			dict[_deserialize_value(key)] = _deserialize_value(value[key])
		return dict
	
	if value is Array:
		return value.map(_deserialize_value)
	
	if value is String:
		
		if value == SafeIO.NULL_MARKER:
			return null
		
		if value.begins_with(SafeIO.OBJECT_MARKER):
			return _load_dependency(value.trim_prefix(SafeIO.OBJECT_MARKER).to_int())
	
	if value == null:
		return null
	
	return value if _is_compressed else JSON.to_native(value)


func _instantiate_resource(type: String) -> Resource:
	
	var register = SafeIO.get_register()
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
	
	return script.new()
