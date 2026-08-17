@tool class_name SafeResourceIO extends EditorPlugin

const TEXT_FILE_FORMAT = "sav"
const BINARY_FILE_FORMAT = "bin"

const TYPE_MARKER = "<type>"
const DEPENDENCIES_MARKER = "<dependencies>"
const OBJECT_MARKER = "obj:"
const ROOT_OBJECT_MARKER = "obj:<root>"

const REGISTERED_BASE_TYPES = "safe_resource_io/general/registered_base_types"
const REGISTERED_DIRS = "safe_resource_io/general/registered_resource_directories"
const REGISTERED_FILES = "safe_resource_io/general/registered_resource_files"
const NAME_EXPRESSION = "safe_resource_io/general/serialized_name_expression"

const NAME_EXPRESSION_DEFAULT = "name.lstrip(\"_\").to_snake_case()"

var rebake_required := true


## Returns an [Expression] object which has parsed the expression text
## specified at "safe_resource_io/advanced/serialized_name_expression"
static func get_name_expression() -> Expression:

	var expression := Expression.new()
	var expression_string: String = ProjectSettings.get_setting(NAME_EXPRESSION, NAME_EXPRESSION_DEFAULT)

	if expression.parse(expression_string, ["name"]) != Error.OK:
		expression.parse(NAME_EXPRESSION_DEFAULT, ["name"])

	return expression


## Returns an array of all file extentions recognized by [SafeResourceIOSaver] and [SafeResourceIOLoader].
static func get_recognized_extensions() -> PackedStringArray:
	return [
		TEXT_FILE_FORMAT,
		BINARY_FILE_FORMAT,
	]


## Returns a Dictionary of data for all properties with [constant @GlobalScope.PROPERTY_USAGE_STORAGE]
## enabled, minus those [SafeResourceIOLoader] can't or shouldn't load.[br][br]
## [b]Keys:[/b] Property name.[br]
## [b]Values:[/b] Property type as a [enum @GlobalScope.Variant.Type].
static func get_serializeable_properties(resource: Resource) -> Dictionary[String, int]:

	# Building list
	var property_list: Dictionary[String, int]
	for property in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE:
			property_list[property.name] = property.type

	# erasing unneeded entries to reduce resulting file size
	property_list.erase("script")
	for entry in resource.get_meta_list():
		property_list.erase("metadata/%s" % entry)

	return property_list


func _enable_plugin() -> void:

	if not ProjectSettings.has_setting(REGISTERED_BASE_TYPES):
		ProjectSettings.set_setting(REGISTERED_BASE_TYPES, PackedStringArray())

	ProjectSettings.set_as_basic(REGISTERED_BASE_TYPES, true)
	ProjectSettings.add_property_info({
		"name": REGISTERED_BASE_TYPES,
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint_string": "%d/%d:%s" % [
			TYPE_STRING,
			PROPERTY_HINT_ENUM,
			",".join(_get_all_engine_resource_types()),
		]
	})

	if not ProjectSettings.has_setting(REGISTERED_DIRS):
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

	if not ProjectSettings.has_setting(REGISTERED_FILES):
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

	if not ProjectSettings.has_setting(NAME_EXPRESSION):
		ProjectSettings.set_setting(NAME_EXPRESSION, NAME_EXPRESSION_DEFAULT)

	ProjectSettings.set_initial_value(NAME_EXPRESSION, NAME_EXPRESSION_DEFAULT)
	ProjectSettings.add_property_info({
		"name": NAME_EXPRESSION,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_EXPRESSION,
	})

	ProjectSettings.settings_changed.connect(_on_project_settings_changed)


func _disable_plugin() -> void:
	ProjectSettings.set_setting(REGISTERED_BASE_TYPES, null)
	ProjectSettings.set_setting(REGISTERED_FILES, null)
	ProjectSettings.set_setting(REGISTERED_DIRS, null)
	ProjectSettings.set_setting(NAME_EXPRESSION, null)


func _build() -> bool:

	if not rebake_required:
		return true

	rebake_required = SafeResourceIORegister.new()._bake() != Error.OK
	return not rebake_required


func _get_all_engine_resource_types() -> PackedStringArray:

	var output: PackedStringArray
	for type in ClassDB.get_class_list():
		if ClassDB.is_parent_class(type, &"Resource"):
			output.append(type)

	output.sort()
	return output


func _on_project_settings_changed() -> void:
	if ProjectSettings.check_changed_settings_in_group("safe_resource_io"):
		rebake_required = true
