@tool class_name SafeIOResourceRegister extends Resource

@export_tool_button("Bake Resource Register", "Bake") var bake_list: Callable = _bake

## Full list of all resources instantiable by by [SafeIOLoader].
## Its recommended you don't manually modify this, instead rebaking with the button
## in the resource inspector, or by running the provided editor script.
var _resource_register: Dictionary[String, StringName]


func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "_resource_register",
		"type": TYPE_DICTIONARY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:;%d:" % [
			TYPE_STRING,
			PROPERTY_HINT_FILE,
			TYPE_STRING_NAME
		],
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY
	}]


## Returns the registered classname if registered, or an empty string otherwise
func get_registered_resource_type(file_path: String) -> StringName:
	return _resource_register.get(ResourceUID.path_to_uid(file_path), &"")


func is_resource_registered(file_path: StringName) -> bool:
	return ResourceUID.path_to_uid(file_path) in _resource_register


func is_resource_safe(file_path: StringName) -> bool:
	
	if not ResourceLoader.exists(file_path):
		return false
	
	if is_resource_registered(file_path):
		return true
	
	if file_path.begins_with("uid://"):
		file_path = ResourceUID.uid_to_path(file_path)
	
	return file_path.get_extension() in SafeIO.get_recognized_extensions()


func _bake() -> void:
	
	if not Engine.is_editor_hint():
		return
	
	SafeIOBakeRegister.new()._run()
	notify_property_list_changed()
