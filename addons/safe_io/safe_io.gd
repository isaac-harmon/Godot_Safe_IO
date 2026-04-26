@tool class_name SafeIO extends EditorPlugin

const TEXT_FILE_FORMAT = "sav"
const BINARY_FILE_FORMAT = "bin"

const TYPE_MARKER = "<type>"
const DEPENDENCIES_MARKER = "<dependencies>"
const OBJECT_MARKER = "obj:"
const ROOT_OBJECT_MARKER = "<rootobj>"

const REGISTERED_DIRS = "safe_io/general/registered_resource_directories"
const REGISTERED_FILES = "safe_io/general/registered_resource_files"

var rebake_required := true


## Returns an array of all file extentions recognized by [SafeIOSaver] and [SafeIOLoader].
static func get_recognized_extensions() -> PackedStringArray:
	return [
		TEXT_FILE_FORMAT,
		BINARY_FILE_FORMAT,
	]


## Returns a Dictionary of data for all properties with [constant @GlobalScope.PROPERTY_USAGE_STORAGE]
## enabled, minus those [SafeIOLoader] can't or shouldn't load.[br][br]
## [b]Keys:[/b] Property name.[br]
## [b]Values:[/b] Property type as a [enum @GlobalScope.Variant.Type].
static func get_serializeable_properties(resource: Resource) -> Dictionary[String, int]:

	# Building list
	var property_list: Dictionary[String, int]
	for property in resource.get_property_list():
		if property["usage"] & PROPERTY_USAGE_STORAGE:
			property_list[property["name"]] = property["type"]

	# erasing unneeded entries to reduce resulting file size
	property_list.erase("script")
	for entry in resource.get_meta_list():
		property_list.erase("metadata/%s" % entry)

	return property_list


## Converts a string to snake_case and strips leading underscores.
## Used to ensure a consistent naming convention of properties,
## regardless of the naming convention used in source code.
static func get_serialized_name(name: String) -> String:
	return name.lstrip("_").to_snake_case()


func _enable_plugin() -> void:

	ProjectSettings.set_setting(REGISTERED_DIRS, PackedStringArray())
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
	ProjectSettings.set_as_basic(REGISTERED_FILES, true)
	ProjectSettings.add_property_info({
		"name": REGISTERED_FILES,
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint_string": "%d/%d:" % [
			TYPE_STRING,
			PROPERTY_HINT_FILE
		]
	})

	ProjectSettings.settings_changed.connect(func(): rebake_required = true)


func _disable_plugin() -> void:
	ProjectSettings.set_setting(REGISTERED_FILES, null)
	ProjectSettings.set_setting(REGISTERED_DIRS, null)


func _build() -> bool:

	if not rebake_required:
		return true

	rebake_required = SafeIOResourceRegister.new()._bake() != Error.OK
	return not rebake_required
