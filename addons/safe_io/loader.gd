class_name SafeIOLoader extends ResourceFormatLoader

class LoadData:

	var base_resource: Resource
	var is_compressed: bool
	var cache_mode: ResourceFormatLoader.CacheMode

	## Dictionary for all unloaded resource data.
	## Sub-resources will have a dictionary of data, and external resources will have just the path.
	var raw_dependency_data: Dictionary[int, Variant]

	## Dictionary for all loaded sub-resources / dependencies.
	var dependency_cache: Dictionary[int, Resource]

## Stack of data for all current loads. Current load is at the back of the array.
var _load_stack: Array[LoadData]


func _get_classes_used(path: String) -> PackedStringArray:

	var register := SafeIO.get_register()
	if not register:
		return []

	var get_type_name := func(type: String) -> String:

		if ClassDB.class_exists(type):
			return type

		return register.get_registered_resource_type(type)

	return _process_dependency_types(path, get_type_name)


func _get_dependencies(path: String, add_types: bool) -> PackedStringArray:

	var register := SafeIO.get_register()
	if not register:
		return []

	var generate_string := func(type: String, add_types: bool) -> String:

		if not type or ClassDB.class_exists(type):
			return ""

		var primary_path := ResourceUID.path_to_uid(type)
		var secondary_path := ResourceUID.ensure_path(type)
		var type_name: String = register.get_registered_resource_type(primary_path) if add_types else ""

		if secondary_path == primary_path:
			secondary_path = ""

		var output_string := "%s::%s::%s" % [primary_path, type_name, secondary_path]
		return output_string.rstrip(":")

	return _process_dependency_types(path, generate_string.bind(add_types))


func _get_recognized_extensions() -> PackedStringArray:
	return SafeIO.get_recognized_extensions()


func _get_resource_script_class(path: String) -> String:

	var register := SafeIO.get_register()
	if not register:
		return ""

	return register.get_registered_resource_type(path)


func _get_resource_type(path: String) -> String:
	var type := _get_resource_script_class(path)
	if not type or ClassDB.class_exists(type):
		return type

	return "Resource"


func _handles_type(_type: StringName) -> bool:
	return true


func _load(path: String, _original_path: String, _use_sub_threads: bool, cache_mode: CacheMode):

	path = ResourceUID.ensure_path(path)

	var load_data := LoadData.new()
	load_data.is_compressed = path.ends_with(SafeIO.BINARY_FILE_FORMAT)
	load_data.cache_mode = cache_mode

	var result = _load_file(path, load_data.is_compressed)
	if result is Error:
		return result

	_load_stack.push_back(load_data)

	if SafeIO.DEPENDENCIES_MARKER in result:
		var dependencies := result[SafeIO.DEPENDENCIES_MARKER] as Dictionary
		for entry in dependencies:
			load_data.raw_dependency_data[int(_deserialize_value(entry))] = dependencies[entry]

	var resource := _deserialize_resource(result)

	_load_stack.pop_back()

	if resource == null:
		return ERR_FILE_CORRUPT

	resource.take_over_path(path)
	return resource


func _rename_dependencies(path: String, renames: Dictionary) -> Error:

	var data = _load_file(path, path.ends_with(SafeIO.BINARY_FILE_FORMAT))

	if data is Error:
		return data

	if data.get(SafeIO.TYPE_MARKER) in renames:
		data[SafeIO.TYPE_MARKER] = renames[data[SafeIO.TYPE_MARKER]]

	if not SafeIO.DEPENDENCIES_MARKER in data:
		return OK

	var dependencies := data[SafeIO.DEPENDENCIES_MARKER] as Dictionary
	for entry in dependencies:

		if dependencies[entry] is Dictionary:
			var type_path = dependencies[entry].get(SafeIO.TYPE_MARKER)
			if type_path in renames:
				dependencies[entry][SafeIO.TYPE_MARKER] = renames[type_path]

		elif entry in renames:
			dependencies[entry] = renames[entry]

	return OK


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
			return ERR_PARSE_ERROR

		data = json.data

	return data if data is Dictionary else ERR_INVALID_DATA


func _load_dependency(id: int) -> Resource:

	var load_data := _load_stack[-1]
	if id in load_data.dependency_cache:
		return load_data.dependency_cache[id]

	var data = load_data.raw_dependency_data.get(id)
	if data is Dictionary:
		load_data.dependency_cache[id] = _deserialize_resource(data)

	elif data is String:
		load_data.dependency_cache[id] = _load_external_resource(data)

	else:
		return null

	return load_data.dependency_cache[id]


## Verifies the safety of the resource at [param path],
## Returns the loaded resource on success or null on failure.
func _load_external_resource(path: String) -> Resource:

	var register = SafeIO.get_register()
	if not register:
		return null

	if not register.is_resource_safe(path):
		return null

	var cache_mode: ResourceLoader.CacheMode
	match _load_stack[-1].cache_mode:
		CACHE_MODE_IGNORE_DEEP: cache_mode = ResourceLoader.CACHE_MODE_IGNORE_DEEP
		CACHE_MODE_REPLACE_DEEP: cache_mode = ResourceLoader.CACHE_MODE_REPLACE_DEEP
		_: cache_mode = ResourceLoader.CACHE_MODE_REUSE

	return ResourceLoader.load(path, "", cache_mode)


## Converts any valid [Dictionary] into its corresponding type.
## Returns the [Resource] on success or a null value on failure.
func _deserialize_resource(data: Dictionary) -> Resource:

	var type := str(data.get(SafeIO.TYPE_MARKER))
	var resource := _instantiate_resource(type)
	if resource == null:
		return null

	for property in SafeIO.get_serializeable_properties(resource):

		var json_name := SafeIO.get_serialized_name(property["name"])
		if not json_name in data:
			continue

		var value = _deserialize_value(data[json_name])

		if property["type"] == TYPE_ARRAY or property["type"] == TYPE_DICTIONARY:
			var current = resource.get(property["name"])
			current.assign(value)
			value = current

		resource.set(property["name"], value)

	return resource


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

		if value.begins_with(SafeIO.ROOT_OBJECT_MARKER):
			return _load_stack[-1].base_resource

	elif value == null or _load_stack[-1].is_compressed:
		return value

	return JSON.to_native(value)


## Instantiates a resource of the given type.
## Expects the name of a built-in type, or the path to a custom script.
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

	var base_class: StringName = script.get_instance_base_type()
	if not ClassDB.is_parent_class(base_class, &"Resource"):
		return null

	var resource: Resource = script.new()
	if _load_stack[-1].base_resource == null:
		_load_stack[-1].base_resource = resource

	return resource


## Runs [param action] on each dependency in the resource at path,
## and returns an array of all non-empty results.
## Expects [param action] to take one [String] input and return a [String].
func _process_dependency_types(path: String, action: Callable) -> PackedStringArray:

	var data = _load_file(path, path.ends_with(SafeIO.BINARY_FILE_FORMAT))
	if data is Error or SafeIO.TYPE_MARKER not in data:
		return []

	var output: PackedStringArray
	var result: String = action.call(str(data[SafeIO.TYPE_MARKER]))

	if result:
		output.append(result)

	if not SafeIO.DEPENDENCIES_MARKER in data:
		return output

	for entry in data[SafeIO.DEPENDENCIES_MARKER]:

		var entry_value = data[SafeIO.DEPENDENCIES_MARKER][entry]
		if entry_value is Dictionary:
			entry_value = entry_value.get(SafeIO.TYPE_MARKER, "")

		result = action.call(str(entry_value))
		if result:
			output.append(result)

	return output
