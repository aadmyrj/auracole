class_name RecipeData
extends Resource

@export var recipe_id: String = ""
@export var device_name: String = ""
@export var category: String = ""
@export var category_name: String = ""
@export_multiline var input_items: String = ""
@export_multiline var output_items: String = ""
@export_multiline var notes: String = ""


static func from_dictionary(data: Dictionary) -> RecipeData:
	var recipe: RecipeData = RecipeData.new()
	recipe.recipe_id = String(data.get("id", ""))
	recipe.device_name = String(data.get("name", ""))
	recipe.category = String(data.get("category", ""))
	recipe.category_name = String(data.get("category_name", ""))
	recipe.input_items = String(data.get("input", ""))
	recipe.output_items = String(data.get("output", ""))
	recipe.notes = String(data.get("notes", ""))
	return recipe


func matches_search(search_text: String) -> bool:
	if search_text.strip_edges().is_empty():
		return true

	var search_lower: String = search_text.to_lower()
	var fields: PackedStringArray = [
		device_name,
		input_items,
		output_items,
		notes,
		category,
		category_name,
	]

	for field in fields:
		if field.to_lower().find(search_lower) != -1:
			return true

	return false


func get_input_items() -> PackedStringArray:
	return _split_items(input_items)


func get_output_items() -> PackedStringArray:
	return _split_items(output_items)


static func _split_items(text: String) -> PackedStringArray:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return PackedStringArray()

	var normalized: String = trimmed.replace("\n", "+")
	for separator in ["，", ",", "、", "＋"]:
		normalized = normalized.replace(separator, "+")

	var result: PackedStringArray = PackedStringArray()
	for part in normalized.split("+", false):
		var item: String = part.strip_edges()
		if not item.is_empty():
			result.append(item)

	if result.is_empty():
		result.append(trimmed)

	return result
