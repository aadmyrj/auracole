class_name RecipeBrowser
extends Control

signal close_requested

const RECIPE_CARD_SCENE: PackedScene = preload("res://scenes/recipe_browser/recipe_card.tscn")
const FLOW_CHART_POPUP_SCENE: PackedScene = preload("res://scenes/recipe_browser/flow_chart_popup.tscn")
const NARROW_LAYOUT_WIDTH: float = 860.0
const COMPACT_LAYOUT_WIDTH: float = 620.0

@export var show_close_button: bool = true
@export var initial_search_text: String = ""

@onready var root_margin: MarginContainer = %MarginContainer
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var recipe_database: RecipeDatabase = %RecipeDatabase
@onready var close_button: Button = %CloseButton
@onready var header_panel: PanelContainer = %HeaderPanel
@onready var header_content: BoxContainer = %HeaderContent
@onready var search_container: VBoxContainer = %SearchContainer
@onready var filter_container: VBoxContainer = %FilterContainer
@onready var search_input: LineEdit = %SearchInput
@onready var category_filter: OptionButton = %CategoryFilter
@onready var content_container: VBoxContainer = %Content

var _flow_chart_popup


func _ready() -> void:
	setup_styles()
	setup_categories()
	setup_signals()
	_setup_flow_chart_popup()
	_apply_responsive_layout()

	close_button.visible = show_close_button
	if not initial_search_text.is_empty():
		search_input.text = initial_search_text

	refresh_recipes()


func setup_categories() -> void:
	category_filter.clear()
	category_filter.add_item("全部类别")
	category_filter.set_item_metadata(0, "")

	for category_id in recipe_database.get_category_order():
		var category_name: String = recipe_database.get_category_name(category_id)
		category_filter.add_item(category_name)
		category_filter.set_item_metadata(category_filter.get_item_count() - 1, category_id)

	category_filter.select(0)

	search_input.placeholder_text = "搜索设备、输入、输出或备注"
	search_input.clear_button_enabled = true
	title_label.text = "设备配方与流程"
	subtitle_label.text = "检索工业设备的输入输出，并查看对应流程图。"
	close_button.text = "关闭"


func setup_styles() -> void:
	var header_style: StyleBoxFlat = StyleBoxFlat.new()
	header_style.bg_color = Color("162238")
	header_style.border_color = Color("3d5c85")
	header_style.border_width_left = 1
	header_style.border_width_top = 1
	header_style.border_width_right = 1
	header_style.border_width_bottom = 1
	header_style.corner_radius_top_left = 14
	header_style.corner_radius_top_right = 14
	header_style.corner_radius_bottom_left = 14
	header_style.corner_radius_bottom_right = 14
	header_style.content_margin_left = 18
	header_style.content_margin_top = 18
	header_style.content_margin_right = 18
	header_style.content_margin_bottom = 18
	header_panel.add_theme_stylebox_override("panel", header_style)


func setup_signals() -> void:
	search_input.text_changed.connect(_on_search_changed)
	category_filter.item_selected.connect(_on_category_filter_changed)
	close_button.pressed.connect(_emit_close_requested)
	get_viewport().size_changed.connect(_on_viewport_resized)


func set_search_text(value: String) -> void:
	initial_search_text = value
	if not is_node_ready():
		return

	search_input.text = value
	refresh_recipes()


func refresh_recipes() -> void:
	clear_content()

	var selected_category: String = _get_selected_category()
	var search_text: String = search_input.text
	var has_visible_section: bool = false

	for category in recipe_database.get_category_order():
		if not selected_category.is_empty() and category != selected_category:
			continue

		var recipes: Array[RecipeData] = recipe_database.get_recipes_by_category(category)
		var filtered_recipes: Array[RecipeData] = []

		for recipe in recipes:
			if recipe.matches_search(search_text):
				filtered_recipes.append(recipe)

		if filtered_recipes.is_empty():
			continue

		has_visible_section = true
		add_category_section(category, filtered_recipes)

	if not has_visible_section:
		add_empty_state()


func add_category_section(category: String, recipes: Array[RecipeData]) -> void:
	var section: VBoxContainer = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	content_container.add_child(section)

	var title: Label = Label.new()
	title.custom_minimum_size = Vector2(0, 42)
	title.text = recipe_database.get_category_name(category)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_section_title_style(title)
	section.add_child(title)

	var recipes_container: VBoxContainer = VBoxContainer.new()
	recipes_container.add_theme_constant_override("separation", 12)
	section.add_child(recipes_container)

	for recipe in recipes:
		add_recipe_card(recipe, recipes_container)


func add_recipe_card(recipe_data: RecipeData, container: VBoxContainer) -> void:
	var card: RecipeCard = RECIPE_CARD_SCENE.instantiate() as RecipeCard
	container.add_child(card)
	card.setup_recipe(recipe_data)
	card.recipe_selected.connect(_on_recipe_selected)


func clear_content() -> void:
	for child in content_container.get_children():
		child.free()


func _get_selected_category() -> String:
	if category_filter.selected < 0:
		return ""
	return String(category_filter.get_item_metadata(category_filter.selected))


func _on_search_changed(_new_text: String) -> void:
	refresh_recipes()


func _on_category_filter_changed(_index: int) -> void:
	refresh_recipes()


func _setup_flow_chart_popup() -> void:
	_flow_chart_popup = FLOW_CHART_POPUP_SCENE.instantiate()
	add_child(_flow_chart_popup)


func _on_recipe_selected(recipe_data: RecipeData) -> void:
	_flow_chart_popup.show_recipe(recipe_data)


func _apply_section_title_style(title: Label) -> void:
	var title_style: StyleBoxFlat = StyleBoxFlat.new()
	title_style.bg_color = Color("2a5caa")
	title_style.corner_radius_top_left = 10
	title_style.corner_radius_top_right = 10
	title_style.corner_radius_bottom_left = 10
	title_style.corner_radius_bottom_right = 10
	title_style.content_margin_left = 14
	title_style.content_margin_top = 10
	title_style.content_margin_right = 14
	title_style.content_margin_bottom = 10
	title.add_theme_stylebox_override("normal", title_style)
	title.add_theme_color_override("font_color", Color("f8fbff"))


func add_empty_state() -> void:
	var empty_label: Label = Label.new()
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.custom_minimum_size = Vector2(0, 180)
	empty_label.text = "没有找到符合条件的配方。"
	empty_label.theme_override_colors.font_color = Color("8ea3c9")
	empty_label.theme_override_font_sizes.font_size = 18
	content_container.add_child(empty_label)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_emit_close_requested()
		get_viewport().set_input_as_handled()


func _emit_close_requested() -> void:
	close_requested.emit()


func _on_viewport_resized() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = _get_viewport_size()
	var viewport_width: float = viewport_size.x
	var is_narrow: bool = viewport_width < NARROW_LAYOUT_WIDTH
	var is_compact: bool = viewport_width < COMPACT_LAYOUT_WIDTH

	header_content.vertical = is_narrow
	header_content.alignment = BoxContainer.ALIGNMENT_BEGIN
	header_content.add_theme_constant_override("separation", 12 if is_compact else 16)

	root_margin.add_theme_constant_override("margin_left", 16 if is_compact else 28)
	root_margin.add_theme_constant_override("margin_right", 16 if is_compact else 28)
	root_margin.add_theme_constant_override("margin_top", 16 if is_compact else 24)
	root_margin.add_theme_constant_override("margin_bottom", 16 if is_compact else 24)

	title_label.add_theme_font_size_override("font_size", 26 if is_compact else 34)
	subtitle_label.add_theme_font_size_override("font_size", 14 if is_compact else 15)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	search_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_narrow else Control.SIZE_FILL
	filter_container.custom_minimum_size = Vector2(0 if is_narrow else 220, 0)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_narrow else Control.SIZE_FILL
	close_button.custom_minimum_size = Vector2(0 if is_narrow else 112, 40 if is_compact else 46)

	search_input.custom_minimum_size = Vector2(0, 40 if is_compact else 0)
	category_filter.custom_minimum_size = Vector2(0, 40 if is_compact else 0)


func _get_viewport_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size
