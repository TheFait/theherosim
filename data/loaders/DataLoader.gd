extends RefCounted

## Generic JSON file loader with error handling
## This is a utility class with static methods only

static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: File not found: " + path)
		return []

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: Failed to open file: " + path)
		return []

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(content)

	if error != OK:
		push_error("DataLoader: JSON parse error in " + path + " at line " + str(json.get_error_line()) + ": " + json.get_error_message())
		return []

	return json.data
