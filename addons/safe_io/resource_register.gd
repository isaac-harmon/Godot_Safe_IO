@tool class_name SafeIOResourceRegister extends Resource

@export_tool_button("Bake Resource Register", "Bake") var bake_list: Callable = _bake

## Full list of all resources instantiable by by [SafeIOLoader].
## It's recommended you don't manually modify this, instead rebaking with the button
## in the resource inspector, or by running the provided editor script.
var _baked_register: Dictionary[String, StringName]


func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "_baked_register",
		"type": TYPE_DICTIONARY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:;%d:" % [
			TYPE_STRING,
			PROPERTY_HINT_FILE,
			TYPE_STRING_NAME
		],
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY
	}]


## Appends all resources within the directory at [param path] to the resource register.[br][br]
## Note: Because all files within [code]"res://"[/code] become read-only when exported,
## any appended entries must be kept in memory for the duration of the program,
## unlike permanant entries which can be loaded/unloaded when needed.
func add_dir(path: String, include_subdirs := false) -> Error:
	
	if not Engine.is_editor_hint():
		return Error.ERR_UNAUTHORIZED
	
	if not DirAccess.dir_exists_absolute(path):
		return Error.ERR_FILE_NOT_FOUND
	
	for file in ResourceLoader.list_directory(path):
		
		var full_path := path + file
		if not file.ends_with("/"):
			var error := add_file(full_path)
			_print_file_error(error, full_path)
		
		elif include_subdirs:
			add_dir(full_path, true)
	
	return Error.OK


## Appends the given resource at [param path] to the resource register.[br][br]
## Note: Because all files within [code]"res://"[/code] become read-only when exported,
## any appended entries must be kept in memory for the duration of the program,
## unlike permanant entries which can be loaded/unloaded when needed.
func add_file(path: String) -> Error:
	
	if not Engine.is_editor_hint():
		return Error.ERR_UNAUTHORIZED
	
	if not ResourceLoader.exists(path):
		return Error.ERR_FILE_NOT_FOUND
	
	if is_resource_registered(path):
		return Error.ERR_DUPLICATE_SYMBOL
	
	var resource := load(path)
	path = ResourceUID.path_to_uid(path)
	
	var script := resource.get_script() as Script
	var type := script.get_global_name() if script else resource.get_class()
	
	_baked_register[path] = type
	return Error.OK


## Returns the registered classname of resource at [param path] if registered,
## or an empty string if not found.
func get_registered_resource_type(path: String) -> StringName:
	path = ResourceUID.path_to_uid(path)
	return _baked_register.get(path, &"")


## Checks if [param path] is registered.
## If checking the safety of a file manually, use [method is_resource_safe] instead.
func is_resource_registered(path: StringName) -> bool:
	var uid := ResourceUID.path_to_uid(path)
	return uid in _baked_register


## Used to check the safety and validity of an unknown resource at [param path] before loading.
func is_resource_safe(path: StringName) -> bool:
	
	if not ResourceLoader.exists(path):
		return false
	
	if is_resource_registered(path):
		return true
	
	path = ResourceUID.ensure_path(path)
	return path.get_extension() in SafeIO.get_recognized_extensions()


func _bake() -> Error:
	
	if not Engine.is_editor_hint():
		return Error.ERR_UNAUTHORIZED
	
	print("[SafeIO]: Baking runtime resource register.")
	
	_baked_register = {}
	
	print("\n[SafeIO]: (Bake 1/3) Parsing registered directories.")
	
	for directory in ProjectSettings.get_setting(SafeIO.REGISTERED_DIRS, []):
		print_rich("[color=web_gray] - Parsing \"%s\"" % directory)
		
		var error := add_dir(directory + "/")
		match error:
			Error.OK:
				pass
			
			Error.ERR_FILE_NOT_FOUND:
				push_warning("[SafeIO]: Directory \"%s\" not found!" % directory)
			
			_:
				assert(false, "Unimplemented error message for error: %s" % error_string(error))
	
	print("\n[SafeIO]: (Bake 2/3) Parsing registered files.")
	
	for file in ProjectSettings.get_setting(SafeIO.REGISTERED_FILES, []):
		_print_file_error(add_file(file), file)
	
	print("\n[SafeIO]: (Bake 3/3) Writing baked list to file.")
	
	for attempt in range(3):
		var error := ResourceSaver.save(self)
		if not error:
			break
		
		if attempt >= 2:
			push_error("[SafeIO]: Aborted, cannot save! Error code %d: (%s)" % [error, error_string(error)])
			return Error.ERR_FILE_CANT_WRITE
		
		push_warning("[SafeIO]: An error occured when writing to path \"%s\". Retrying..." % resource_path)
	
	print("\n[SafeIO]: Succesfully wrote result to \"%s\". Bake complete!" % resource_path)
	notify_property_list_changed()
	return Error.OK


func _print_file_error(error: Error, path: String) -> void:
	
	var true_path := ResourceUID.ensure_path(path)
	match error:
		Error.OK:
			print_rich("[color=web_gray]\t - Registered \"%s\"" % [true_path])
		
		Error.ERR_FILE_NOT_FOUND:
			push_warning("[SafeIO]: File \"%s\" not found!" % true_path)
		
		Error.ERR_DUPLICATE_SYMBOL:
			push_warning("[SafeIO]: Duplicate file \"%s\" in register!" % true_path)
		
		_:
			assert(false, "Unimplemented error message for error: %s" % error_string(error))
