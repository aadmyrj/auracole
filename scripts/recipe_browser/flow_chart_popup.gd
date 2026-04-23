extends PopupPanel

const STEP_NODE_SCENE: PackedScene = preload("res://scenes/recipe_browser/step_node.tscn")
const POPUP_SIZE: Vector2i = Vector2i(1080, 720)
const SURFACE_SIZE: Vector2 = Vector2(1240, 720)
const FLOW_CHARTS_JSON_PATH: String = "res://data/recipe_browser/flow_charts.json"
const NARROW_POPUP_WIDTH: float = 900.0
const COMPACT_POPUP_WIDTH: float = 640.0

@onready var root_margin: MarginContainer = %MarginContainer
@onready var popup_layout: VBoxContainer = %VBoxContainer
@onready var header_container: BoxContainer = %Header
@onready var title_block: VBoxContainer = %TitleBlock
@onready var title_label: Label = %DeviceName
@onready var info_label: Label = %RecipeInfo
@onready var close_button: Button = %CloseButton
@onready var flow_panel: PanelContainer = %FlowPanel
@onready var flow_surface: Control = %FlowSurface
@onready var connection_layer: FlowChartConnectionLayer = %ConnectionLayer
@onready var nodes_layer: Control = %NodesLayer

var _current_recipe: RecipeData
var _step_nodes: Dictionary = {}
var _custom_flow_charts: Dictionary = {}


func _ready() -> void:
	close_button.pressed.connect(hide)
	exclusive = true
	flow_surface.custom_minimum_size = SURFACE_SIZE
	_load_flow_charts()
	_apply_styles()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)


func show_recipe(recipe: RecipeData) -> void:
	_current_recipe = recipe
	title_label.text = recipe.device_name
	info_label.text = "输入：%s\n输出：%s" % [
		_format_field(recipe.input_items),
		_format_field(recipe.output_items),
	]
	_display_flow_chart(_build_flow_chart(recipe))
	_apply_responsive_layout()
	popup_centered(_get_popup_size())


func _display_flow_chart(flow_data: Dictionary) -> void:
	_clear_flow_chart()

	for step in flow_data.get("steps", []):
		_create_step_node(step)

	call_deferred("_apply_connections", flow_data.get("connections", []))


func _create_step_node(step_data: Dictionary) -> void:
	var step_node: StepNode = STEP_NODE_SCENE.instantiate() as StepNode
	nodes_layer.add_child(step_node)
	step_node.setup_step(step_data)
	_step_nodes[String(step_data.get("id", ""))] = step_node


func _apply_connections(connection_defs: Array) -> void:
	var resolved: Array[Dictionary] = []

	for connection in connection_defs:
		var from_id: String = String(connection.get("from", ""))
		var to_id: String = String(connection.get("to", ""))
		if _step_nodes.has(from_id) and _step_nodes.has(to_id):
			resolved.append({
				"from": _step_nodes[from_id],
				"to": _step_nodes[to_id],
			})

	connection_layer.set_connections(resolved)


func _clear_flow_chart() -> void:
	connection_layer.clear_connections()

	for child in nodes_layer.get_children():
		child.free()

	_step_nodes.clear()


func _build_flow_chart(recipe: RecipeData) -> Dictionary:
	if _custom_flow_charts.has(recipe.recipe_id):
		var raw_flow: Dictionary = _custom_flow_charts.get(recipe.recipe_id, {})
		return _normalize_flow_chart(raw_flow)

	return _build_default_flow_chart(recipe)


func _build_default_flow_chart(recipe: RecipeData) -> Dictionary:
	var steps: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	var input_items: PackedStringArray = recipe.get_input_items()
	var output_items: PackedStringArray = recipe.get_output_items()
	var device_id: String = "device"

	var input_positions: Array[float] = _build_vertical_positions(max(input_items.size(), 1), 120.0, 540.0)
	var output_positions: Array[float] = _build_vertical_positions(max(output_items.size(), 1), 120.0, 540.0)

	if input_items.is_empty():
		input_items = PackedStringArray(["无输入"])
	if output_items.is_empty():
		output_items = PackedStringArray(["无输出"])

	for i in input_items.size():
		var step_id: String = "input_%d" % i
		steps.append({
			"id": step_id,
			"name": input_items[i],
			"kind": "input",
			"duration": 2.0,
			"pos": Vector2(90, input_positions[i]),
		})
		connections.append({"from": step_id, "to": device_id})

	steps.append({
		"id": device_id,
		"name": recipe.device_name,
		"kind": "device",
		"duration": 2.0,
		"pos": Vector2(420, 250),
		"size": Vector2(200, 104),
	})

	for i in output_items.size():
		var step_id: String = "output_%d" % i
		steps.append({
			"id": step_id,
			"name": output_items[i],
			"kind": "output",
			"duration": 2.0,
			"pos": Vector2(820, output_positions[i]),
		})
		connections.append({"from": device_id, "to": step_id})

	return {
		"steps": steps,
		"connections": connections,
	}


func _build_vertical_positions(count: int, min_y: float, max_y: float) -> Array[float]:
	var positions: Array[float] = []

	if count <= 1:
		positions.append((min_y + max_y) * 0.5)
		return positions

	var step: float = (max_y - min_y) / float(count - 1)
	for index in count:
		positions.append(min_y + step * index)

	return positions


func _apply_styles() -> void:
	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	popup_style.bg_color = Color("0d1524")
	popup_style.border_color = Color("3f5f8d")
	popup_style.border_width_left = 1
	popup_style.border_width_top = 1
	popup_style.border_width_right = 1
	popup_style.border_width_bottom = 1
	popup_style.corner_radius_top_left = 18
	popup_style.corner_radius_top_right = 18
	popup_style.corner_radius_bottom_left = 18
	popup_style.corner_radius_bottom_right = 18
	add_theme_stylebox_override("panel", popup_style)

	var flow_style: StyleBoxFlat = StyleBoxFlat.new()
	flow_style.bg_color = Color("101b2d")
	flow_style.border_color = Color("2c4468")
	flow_style.border_width_left = 1
	flow_style.border_width_top = 1
	flow_style.border_width_right = 1
	flow_style.border_width_bottom = 1
	flow_style.corner_radius_top_left = 16
	flow_style.corner_radius_top_right = 16
	flow_style.corner_radius_bottom_left = 16
	flow_style.corner_radius_bottom_right = 16
	flow_panel.add_theme_stylebox_override("panel", flow_style)


func _format_field(value: String) -> String:
	var trimmed: String = value.strip_edges()
	if trimmed.is_empty():
		return "无"
	return trimmed


func _load_flow_charts() -> void:
	_custom_flow_charts = JsonFileLoader.load_json_dictionary(FLOW_CHARTS_JSON_PATH)


func _normalize_flow_chart(raw_flow: Dictionary) -> Dictionary:
	var steps: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	var raw_steps: Array = raw_flow.get("steps", [])
	var raw_connections: Array = raw_flow.get("connections", [])

	for raw_step_entry in raw_steps:
		if not (raw_step_entry is Dictionary):
			continue

		var raw_step: Dictionary = raw_step_entry
		var step: Dictionary = {
			"id": String(raw_step.get("id", "")),
			"name": String(raw_step.get("name", "")),
			"kind": String(raw_step.get("kind", "default")),
			"duration": float(raw_step.get("duration", 0.0)),
			"pos": _parse_vector2(raw_step.get("pos", [0, 0]), Vector2.ZERO),
		}

		if raw_step.has("size"):
			step["size"] = _parse_vector2(raw_step.get("size", [180, 92]), Vector2(180, 92))

		steps.append(step)

	for raw_connection_entry in raw_connections:
		if not (raw_connection_entry is Dictionary):
			continue

		var raw_connection: Dictionary = raw_connection_entry
		connections.append({
			"from": String(raw_connection.get("from", "")),
			"to": String(raw_connection.get("to", "")),
		})

	return {
		"steps": steps,
		"connections": connections,
	}


func _parse_vector2(raw_value: Variant, default_value: Vector2) -> Vector2:
	if raw_value is Array:
		var values: Array = raw_value
		if values.size() >= 2:
			return Vector2(float(values[0]), float(values[1]))

	if raw_value is Dictionary:
		var values_dict: Dictionary = raw_value
		return Vector2(
			float(values_dict.get("x", default_value.x)),
			float(values_dict.get("y", default_value.y))
		)

	return default_value


func _on_viewport_resized() -> void:
	_apply_responsive_layout()
	if visible:
		popup_centered(_get_popup_size())


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = _get_viewport_size()
	var viewport_width: float = viewport_size.x
	var viewport_height: float = viewport_size.y
	var is_narrow: bool = viewport_width < NARROW_POPUP_WIDTH
	var is_compact: bool = viewport_width < COMPACT_POPUP_WIDTH

	header_container.vertical = is_narrow
	header_container.add_theme_constant_override("separation", 12 if is_compact else 16)
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_narrow else Control.SIZE_FILL
	close_button.custom_minimum_size = Vector2(0 if is_narrow else 112, 42 if is_compact else 46)

	root_margin.add_theme_constant_override("margin_left", 14 if is_compact else 22)
	root_margin.add_theme_constant_override("margin_right", 14 if is_compact else 22)
	root_margin.add_theme_constant_override("margin_top", 14 if is_compact else 22)
	root_margin.add_theme_constant_override("margin_bottom", 14 if is_compact else 22)
	popup_layout.add_theme_constant_override("separation", 14 if is_compact else 18)

	title_label.add_theme_font_size_override("font_size", 22 if is_compact else 28)
	info_label.add_theme_font_size_override("font_size", 14 if is_compact else 15)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var surface_width: float = clampf(viewport_width * 0.88, 760.0, SURFACE_SIZE.x)
	var surface_height: float = clampf(viewport_height * 0.62, 420.0, SURFACE_SIZE.y)
	flow_surface.custom_minimum_size = Vector2(surface_width, surface_height)


func _get_popup_size() -> Vector2i:
	var viewport_size: Vector2 = _get_viewport_size()
	var width: int = int(clampf(viewport_size.x * 0.92, 360.0, POPUP_SIZE.x))
	var height: int = int(clampf(viewport_size.y * 0.88, 320.0, POPUP_SIZE.y))
	return Vector2i(width, height)


func _get_viewport_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size
