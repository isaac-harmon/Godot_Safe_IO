@tool class_name SafeIOBakeResourceRegister extends EditorScript


func _run() -> void:
	SafeIOResourceRegister.new()._bake()
