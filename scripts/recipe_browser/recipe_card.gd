class_name RecipeCard
extends PanelContainer

signal recipe_selected(recipe_data: RecipeData)

@onready var device_name_label: Label = %DeviceName
@onready var category_label: Label = %Category
@onready var input_label: Label = %InputContent
@onready var output_label: Label = %OutputContent
@onready var notes_container: VBoxContainer = %NotesContainer
@onready var notes_label: Label = %NotesContent
@onready var hint_label: Label = %HintLabel

var _recipe_data: RecipeData
var _normal_style: StyleBoxFlat = StyleBoxFlat.new()
var _hover_style: StyleBoxFlat = StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_configure_panel_styles()
	_apply_style(_normal_style)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func setup_recipe(recipe_data: RecipeData) -> void:
	_recipe_data = recipe_data
	device_name_label.text = recipe_data.device_name
	category_label.text = _get_category_text(recipe_data)
	input_label.text = _format_field(recipe_data.input_items)
	output_label.text = _format_field(recipe_data.output_items)

	var has_notes: bool = not recipe_data.notes.strip_edges().is_empty()
	notes_container.visible = has_notes
	notes_label.text = recipe_data.notes

	tooltip_text = "输入：%s\n输出：%s" % [
		_format_field(recipe_data.input_items),
		_format_field(recipe_data.output_items),
	]
	hint_label.text = "点击查看流程图"


func _format_field(value: String) -> String:
	var trimmed: String = value.strip_edges()
	if trimmed.is_empty():
		return "无"
	return trimmed


func _get_category_text(recipe_data: RecipeData) -> String:
	var trimmed: String = recipe_data.category_name.strip_edges()
	if trimmed.is_empty():
		return recipe_data.category
	return trimmed


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		recipe_selected.emit(_recipe_data)
		accept_event()


func _configure_panel_styles() -> void:
	_normal_style.bg_color = Color("1a2439")
	_normal_style.border_color = Color("3d5c85")
	_normal_style.border_width_left = 1
	_normal_style.border_width_top = 1
	_normal_style.border_width_right = 1
	_normal_style.border_width_bottom = 1
	_normal_style.corner_radius_top_left = 14
	_normal_style.corner_radius_top_right = 14
	_normal_style.corner_radius_bottom_left = 14
	_normal_style.corner_radius_bottom_right = 14

	_hover_style.bg_color = Color("22304b")
	_hover_style.border_color = Color("76a6ff")
	_hover_style.border_width_left = 1
	_hover_style.border_width_top = 1
	_hover_style.border_width_right = 1
	_hover_style.border_width_bottom = 1
	_hover_style.corner_radius_top_left = 14
	_hover_style.corner_radius_top_right = 14
	_hover_style.corner_radius_bottom_left = 14
	_hover_style.corner_radius_bottom_right = 14


func _apply_style(style: StyleBoxFlat) -> void:
	add_theme_stylebox_override("panel", style)


func _on_mouse_entered() -> void:
	_apply_style(_hover_style)


func _on_mouse_exited() -> void:
	_apply_style(_normal_style)
