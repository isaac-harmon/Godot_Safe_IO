@tool class_name SafeIO extends EditorPlugin

const TEXT_FILE_FORMAT = "json5"
const BINARY_FILE_FORMAT = "save"

const TYPE_MARKER = "<type>"
const DEPENDENCIES_MARKER = "<dependencies>"
const OBJECT_MARKER = "<obj>"
const NULL_MARKER = "<null>"

const REGISTERED_DIRS = "safe_io/general/registered_resource_directories"
const REGISTERED_FILES = "safe_io/general/registered_resource_files"
const CUSTOM_FILE_PATH = "safe_io/general/custom_register_file_path"

var rebake_required := true


func _enable_plugin() -> void:
	
	ProjectSettings.set_setting(REGISTERED_DIRS, PackedStringArray())
	ProjectSettings.set_initial_value(REGISTERED_DIRS, PackedStringArray())
	ProjectSettings.set_as_basic(REGISTERED_DIRS, true)
	ProjectSettings.add_property_info({
		"name": REGISTERED_DIRS,
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint_string": "%d/%d:" % [
			TYPE_STRING,
			PROPERTY_HINT_DIR
		]
	})
	
	ProjectSettings.set_setting(REGISTERED_FILES, PackedStringArray())
	ProjectSettings.set_initial_value(REGISTERED_FILES, PackedStringArray())
	ProjectSettings.set_as_basic(REGISTERED_FILES, true)
	ProjectSettings.add_property_info({
		"name": REGISTERED_FILES,
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint_string": "%d/%d:" % [
			TYPE_STRING,
			PROPERTY_HINT_FILE
		]
	})
	
	ProjectSettings.set_setting(CUSTOM_FILE_PATH, "")
	ProjectSettings.set_initial_value(CUSTOM_FILE_PATH, "")
	ProjectSettings.add_property_info({
		"name": CUSTOM_FILE_PATH,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE
	})
	
	ProjectSettings.settings_changed.connect(func(): rebake_required = true)


func _disable_plugin() -> void:
	ProjectSettings.set_setting(REGISTERED_FILES, null)
	ProjectSettings.set_setting(REGISTERED_DIRS, null)
	ProjectSettings.set_setting(CUSTOM_FILE_PATH, null)


func _build() -> bool:
	
	if rebake_required and Engine.is_editor_hint():
		SafeIOBakeRegister.new()._run()
	
	return true


## Attempts to load the [SafeIOResourceRegister] pointed to by the setting:
## [member ProjectSetings.safe_io/general/custom_list_file_path].[br][br]
## Returns one of the following options:[br][br]
## [b]Load successful[/b]: The loaded resource.[br]
## [b]No file found[/b]: A empty list resource with the correct path applied.[br]
## [b]Incorrect file type[/b]: Throws an error and returns null.
static func get_register() -> SafeIOResourceRegister:
	
	var file_path = ProjectSettings.get_setting(CUSTOM_FILE_PATH)
	if not file_path:
		file_path = "res://addons/safe_io/resource_register.res"
	
	if not ResourceLoader.exists(file_path):
		
		if not Engine.is_editor_hint():
			push_error("[SafeIO]: Register file \"%s\" does not exist!" % file_path)
			return null
		
		push_warning("[SafeIO]: Creating new register file at \"%s\"." % file_path)
		
		var new_list := SafeIOResourceRegister.new()
		new_list.take_over_path(file_path)
		return new_list
	
	var register := load(file_path) as SafeIOResourceRegister
	var error := "[SafeIO]: Existing file at \"%s\" is not a valid TypeList! " % file_path
	
	if not Engine.is_editor_hint():
		assert(register is SafeIOResourceRegister, error)
	
	elif register is not SafeIOResourceRegister:
		push_error(error)
		return null
	
	return register


## Returns an array of all file extentions recognized by [SafeIOSaver] and [SafeIOLoader].
static func get_recognized_extensions() -> PackedStringArray:
	return [
		TEXT_FILE_FORMAT,
		BINARY_FILE_FORMAT,
	]


## Converts a string to snake_case and strips leading underscores.
## Used to ensure a consistent naming convention of properties,
## regardless of the naming convention used in source code.
static func get_json_name(name: String) -> String:
	return name.lstrip("_").to_snake_case()


## Returns an array of Dictionaries of property data that can be serialized by [SafeIOSaver].
## Entries are identical to those from [method Object.get_property_list].
static func get_serializeable_properties(resource: Resource) -> Array:
	return resource.get_property_list().filter(_is_valid_property)


static func _is_valid_property(property: Dictionary) -> bool:
	var serializable: bool = property["usage"] & PROPERTY_USAGE_STORAGE
	return serializable and property["name"] != "script"
