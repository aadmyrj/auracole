class_name JsonFileLoader
extends RefCounted


static func load_json_dictionary(file_path: String) -> Dictionary:
	var parsed: Variant = _load_json(file_path)
	if parsed is Dictionary:
		return parsed

	push_error("JSON root is not a Dictionary: %s" % file_path)
	return {}


static func _load_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_error("JSON file does not exist: %s" % file_path)
		return {}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open JSON file: %s" % file_path)
		return {}

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		push_error(
			"Failed to parse JSON %s at line %d: %s" % [
				file_path,
				json.get_error_line(),
				json.get_error_message(),
			]
		)
		return {}

	return json.data
