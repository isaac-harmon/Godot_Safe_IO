@tool class_name SafeIOResourceRegister extends Resource

const _FILE_PATH = "res://addons/safe_io/resource_register.res"

@export_tool_button("Bake Resource Register", "Bake") var bake_list: Callable = _bake

## Full list of all resources instantiable by by [SafeIOLoader].
## It's recommended you don't manually modify this, instead rebaking with the button
## in the resource inspector, or by running the provided editor script.
var _baked_register: Dictionary[String, StringName]


## Attempts to load the current [SafeIOResourceRegister].
## Returns the register if succesfully loaded or null otherwise.
static func get_register() -> SafeIOResourceRegister:
	
	if not ResourceLoader.exists(_FILE_PATH):
		push_error("[SafeIO]: Register file \"%s\" does not exist!" % _FILE_PATH)
		return null
	
	var register := load(_FILE_PATH) as SafeIOResourceRegister
	assert(register != null, "[SafeIO]: Existing file at \"%s\" is not a valid Register! " % _FILE_PATH)
	return register


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


## Returns the registered classname of scripts at [param path] if registered,
## or an empty string if either not found or not a script.
func get_registered_script_name(path: String) -> StringName:
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


func _add_dir(path: String, include_subdirs := false) -> Error:
	
	if not Engine.is_editor_hint():
		return Error.ERR_UNAUTHORIZED
	
	if not DirAccess.dir_exists_absolute(path):
		return Error.ERR_FILE_NOT_FOUND
	
	for file in ResourceLoader.list_directory(path):
		
		var full_path := path + file
		if not file.ends_with("/"):
			var error := _add_file(full_path)
			_print_file_error(error, full_path)
		
		elif include_subdirs:
			_add_dir(full_path, true)
	
	return Error.OK


func _add_file(path: String) -> Error:
	
	if not Engine.is_editor_hint():
		return Error.ERR_UNAUTHORIZED
	
	if not ResourceLoader.exists(path):
		return Error.ERR_FILE_NOT_FOUND
	
	if is_resource_registered(path):
		return Error.ERR_DUPLICATE_SYMBOL
	
	var resource := load(path)
	var type: String = resource.get_global_name() if resource is Script else ""
	path = ResourceUID.path_to_uid(path)
	_baked_register[path] = type
	
	return Error.OK


func _bake() -> Error:
	
	if not Engine.is_editor_hint():
		return Error.ERR_UNAUTHORIZED
	
	print("[SafeIO]: Baking runtime resource register.")
	
	_baked_register = {}
	
	print("\n[SafeIO]: (Bake 1/3) Parsing registered directories.")
	
	for directory in ProjectSettings.get_setting(SafeIO.REGISTERED_DIRS, []):
		print_rich("[color=web_gray] - Parsing \"%s\"" % directory)
		
		var error := _add_dir(directory + "/")
		match error:
			Error.OK:
				pass
			
			Error.ERR_FILE_NOT_FOUND:
				push_warning("[SafeIO]: Directory \"%s\" not found!" % directory)
			
			_:
				assert(false, "Unimplemented error message for error: %s" % error_string(error))
	
	print("\n[SafeIO]: (Bake 2/3) Parsing registered files.")
	
	for file in ProjectSettings.get_setting(SafeIO.REGISTERED_FILES, []):
		_print_file_error(_add_file(file), file)
	
	print("\n[SafeIO]: (Bake 3/3) Writing baked list to file.")
	
	var error := false
	for attempt in range(3):
		error = ResourceSaver.save(self, _FILE_PATH)
		if not error:
			break
		
		push_warning("[SafeIO]: Error code %d (%s) occured when writing to file! Retrying..." % [
			error,
			error_string(error)
		])
	
	if error:
		push_error("[SafeIO]: Bake aborted, cannot write to file path \"%s\"!" % _FILE_PATH)
		return Error.ERR_FILE_CANT_WRITE
	
	take_over_path(_FILE_PATH)
	notify_property_list_changed()
	
	print("\n[SafeIO]: Succesfully wrote result to \"%s\". Bake complete!" % _FILE_PATH)
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
			assert(false, "Unimplemented error message for error code %d: %s" % [
				error,
				error_string(error)
			])
