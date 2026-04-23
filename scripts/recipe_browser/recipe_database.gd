class_name RecipeDatabase
extends Node

const RECIPES_JSON_PATH: String = "res://data/recipe_browser/recipes.json"

var _recipes_by_category: Dictionary = {}
var _category_order: Array[String] = []
var _category_names: Dictionary = {}


func _ready() -> void:
	_build_database()


func get_recipes_by_category(category: String) -> Array[RecipeData]:
	if _recipes_by_category.is_empty():
		_build_database()

	var raw_recipes: Array = _recipes_by_category.get(category, [])
	var typed_recipes: Array[RecipeData] = []
	for recipe in raw_recipes:
		if recipe is RecipeData:
			typed_recipes.append(recipe)

	return typed_recipes


func get_category_order() -> Array[String]:
	if _category_order.is_empty():
		_build_database()
	return _category_order.duplicate()


func get_category_name(category: String) -> String:
	if _category_order.is_empty():
		_build_database()
	return String(_category_names.get(category, category))


func _build_database() -> void:
	_recipes_by_category.clear()
	_category_order.clear()
	_category_names.clear()

	var root: Dictionary = JsonFileLoader.load_json_dictionary(RECIPES_JSON_PATH)
	var categories: Array = root.get("categories", [])
	var recipes: Array = root.get("recipes", [])

	for category_entry in categories:
		if not (category_entry is Dictionary):
			continue

		var category_data: Dictionary = category_entry
		var category_id: String = String(category_data.get("id", "")).strip_edges()
		var category_name: String = String(category_data.get("name", category_id)).strip_edges()
		if category_id.is_empty():
			continue

		_category_order.append(category_id)
		_category_names[category_id] = category_name
		_recipes_by_category[category_id] = []

	for recipe_entry in recipes:
		if not (recipe_entry is Dictionary):
			continue

		var recipe_dict: Dictionary = recipe_entry.duplicate(true)
		var category_id: String = String(recipe_dict.get("category", "")).strip_edges()
		if category_id.is_empty():
			continue

		if not _recipes_by_category.has(category_id):
			_recipes_by_category[category_id] = []
			_category_order.append(category_id)
			_category_names[category_id] = String(recipe_dict.get("category_name", category_id))

		recipe_dict["category"] = category_id
		recipe_dict["category_name"] = get_category_name(category_id)

		var recipe: RecipeData = RecipeData.from_dictionary(recipe_dict)
		var category_recipes: Array = _recipes_by_category.get(category_id, [])
		category_recipes.append(recipe)
		_recipes_by_category[category_id] = category_recipes
