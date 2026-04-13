@tool class_name BakeSafeIOResourceRegister extends EditorScript


func _run() -> void:
	var register := SafeIO.get_register()
	if register:
		register._bake()
