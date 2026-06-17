class_name JsonLoader
## JSON文件加载工具

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JSON file not found: " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open JSON: " + path)
		return {}
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	return json.get_data()

static func load_all_json_in_dir(dir_path: String) -> Dictionary:
	var result = {}
	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_warning("Directory not found: " + dir_path)
		return result
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path = dir_path.path_join(file_name)
			var data = load_json(full_path)
			if data.has("id"):
				result[data["id"]] = data
			else:
				var id = file_name.get_basename()
				result[id] = data
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
