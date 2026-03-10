@tool class_name SafeIOBakeRegister extends EditorScript

var baked_list: Dictionary[String, StringName]


func _run() -> void:
	
	print("[SafeIO]: Baking runtime resource register.\n")
	print("[SafeIO]: (Bake 1/3) Parsing registered directories.")
	
	for directory in ProjectSettings.get_setting(SafeIO._REGISTERED_DIRS, []):
		
		if not DirAccess.dir_exists_absolute(directory):
			push_warning("[SafeIO]: Directory \"%s\" not found!" % directory)
			continue
		
		print_rich("[color=web_gray] - Parsing \"%s\"" % directory)
		
		for file in ResourceLoader.list_directory(directory):
			if not file.begins_with("/"):
				_register_file(ResourceUID.path_to_uid("%s/%s" % [directory, file]))
	
	print("[SafeIO]: (Bake 2/3) Parsing registered files.")
	
	for file in ProjectSettings.get_setting(SafeIO._REGISTERED_FILES, []):
		
		if not ResourceLoader.exists(file):
			push_warning("[SafeIO]: File \"%s\" not found!" % ResourceUID.uid_to_path(file))
			continue
		
		_register_file(file)
	
	print("[SafeIO]: (Bake 3/3) Writing baked list to file.")
	
	var register := SafeIO.get_register()
	if not register:
		return
	
	register._resource_register = baked_list
	var error := ResourceSaver.save(register)
	
	if error:
		push_error(
			"[SafeIO]: An error occured when writing to \"%s\": %s" %
			[register.resource_path, error_string(error)]
		)
		return
	
	print("\n[SafeIO]: Succesfully wrote result to \"%s\". Bake complete!\n" % register.resource_path)


func _register_file(uid_string: String) -> void:
	
	if uid_string in baked_list:
		push_warning("[SafeIO]: Duplicate file \"%s\" in register!")
		return
	
	var resource := load(uid_string)
	baked_list[uid_string] = resource.get_global_name() if resource is Script else ""
	
	print(resource)
	print_rich(
		"[color=web_gray]\t - Registered %s \"%s\"" %
		[resource.get_class(), ResourceUID.uid_to_path(uid_string)]
	)
