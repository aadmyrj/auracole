extends Node2D
class_name GameManager

const BUILDING_SCENE: PackedScene = preload("res://scenes/placement_logic/building.tscn")
const RECIPE_BROWSER_SCENE: PackedScene = preload("res://scenes/recipe_browser/recipe_browser.tscn")
const DIRECTED_CONVEYOR_PLANNER_V2_SCRIPT: GDScript = preload("res://scripts/placement_logic/directed_conveyor_planner_v2.gd")
const CONVEYOR_DELETION_MENU_V2_SCRIPT: GDScript = preload("res://scripts/placement_logic/conveyor_deletion_menu_v2.gd")
const BLUEPRINT_SAVE_PATH: String = "user://blueprints.save"

const BAR_HEIGHT: float = 150.0
const MIN_BAR_HEIGHT: float = 110.0
const LONG_PRESS_DURATION: float = 1.0

enum BuildingAction {
	MOVE,
	DELETE,
	ROTATE
}

enum OperationType {
	PLACE_BUILDING,
	ADD_CONVEYOR
}

@onready var map_manager: MapManager = $MapManager
@onready var camera_rig: CameraRig = $CameraRig
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var ui_bar: UI_Bar = $CanvasLayer/UI_Bar
@onready var top_actions: HBoxContainer = $CanvasLayer/TopActions
@onready var undo_button: Button = $CanvasLayer/TopActions/UndoButton
@onready var clear_button: Button = $CanvasLayer/TopActions/ClearButton
@onready var recipe_button: Button = $CanvasLayer/TopActions/RecipeButton
@onready var blueprint_sidebar: BlueprintSidebar = $CanvasLayer/BlueprintSidebar
@onready var interaction_menu: PopupMenu = $CanvasLayer/InteractionMenu

var item_database: Dictionary = {}
var inventory: Dictionary = {}
var selected_item_id: String = ""
var is_conveyor_mode: bool = false
var _blueprints: Array[Dictionary] = []
var _operation_history: Array[Dictionary] = []

var _last_mouse_position: Vector2 = Vector2.ZERO
var _pressed_building: Building = null
var _pressed_duration: float = 0.0
var _context_building: Building = null
var _moving_building: Building = null
var _moving_origin_cell: Vector2i = Vector2i.ZERO
var _skip_left_release_action: bool = false
var _directed_conveyor_planner: DirectedConveyorPlannerV2 = null
var _conveyor_deletion_menu: ConveyorDeletionMenuV2 = null
var _recipe_browser: RecipeBrowser = null


func _ready() -> void:
	canvas_layer.layer = 10
	ui_bar.visible = true
	ui_bar.mouse_filter = Control.MOUSE_FILTER_STOP

	item_database = ItemDatabase.create()
	_init_inventory()
	_setup_conveyor_tools()
	_setup_top_action_buttons()
	ui_bar.setup(item_database, inventory, ItemDatabase.ITEM_ORDER)
	ui_bar.item_selected.connect(_on_item_selected)
	undo_button.pressed.connect(_on_undo_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	recipe_button.pressed.connect(_on_recipe_button_pressed)
	blueprint_sidebar.save_requested.connect(_on_blueprint_save_requested)
	blueprint_sidebar.load_requested.connect(_on_blueprint_load_requested)
	blueprint_sidebar.delete_requested.connect(_on_blueprint_delete_requested)
	blueprint_sidebar.rename_requested.connect(_on_blueprint_rename_requested)
	interaction_menu.id_pressed.connect(_on_interaction_menu_id_pressed)
	interaction_menu.hide()
	_load_blueprints()
	_refresh_blueprint_list()
	call_deferred("_layout_ui_bar")
	_sync_camera_drag_enabled()
	_update_top_action_buttons()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _process(delta: float) -> void:
	if camera_rig.is_dragging():
		_clear_pressed_building_tracking()
		return

	if _pressed_building == null:
		return
	if not is_instance_valid(_pressed_building):
		_clear_pressed_building_tracking()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_clear_pressed_building_tracking()
		return

	_pressed_duration += delta
	if _pressed_duration >= LONG_PRESS_DURATION:
		_begin_move_mode(_pressed_building)


func _unhandled_input(event: InputEvent) -> void:
	if _is_recipe_browser_open():
		if event.is_action_pressed("ui_cancel"):
			_close_recipe_browser()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			_close_recipe_browser()
			get_viewport().set_input_as_handled()
			return
		return

	if event is InputEventMouse and _is_pointer_over_ui(event.position):
		return

	if event is InputEventKey and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_open_recipe_browser()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_Q:
			_toggle_conveyor_mode()
			get_viewport().set_input_as_handled()
			return
		if is_conveyor_mode and event.keycode == KEY_ESCAPE:
			_directed_conveyor_planner.cancel_current_segment()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		_last_mouse_position = get_global_mouse_position()
		if camera_rig.is_dragging():
			_clear_pressed_building_tracking()
			return

		if is_conveyor_mode:
			_directed_conveyor_planner.handle_mouse_move(_last_mouse_position)
			return

		_update_active_preview(_last_mouse_position)
		return

	if event is InputEventMouseButton:
		_last_mouse_position = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_conveyor_mode:
				_handle_conveyor_left_mouse(event)
				return
			if event.pressed:
				_handle_left_pressed(_last_mouse_position)
			else:
				_handle_left_released(_last_mouse_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_conveyor_mode:
				interaction_menu.hide()
				if _conveyor_deletion_menu != null:
					_conveyor_deletion_menu.hide()
				_clear_pressed_building_tracking()
				return
			_handle_right_pressed(_last_mouse_position, event.position)


func _handle_left_pressed(mouse_pos: Vector2) -> void:
	interaction_menu.hide()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()
	_skip_left_release_action = false

	if _moving_building != null:
		return

	var clicked_building: Building = map_manager.get_building_at_world(mouse_pos)
	if clicked_building != null:
		_pressed_building = clicked_building
		_pressed_duration = 0.0
		return

	_clear_pressed_building_tracking()


func _handle_left_released(mouse_pos: Vector2) -> void:
	if camera_rig.consume_drag_release():
		_clear_pressed_building_tracking()
		_update_active_preview(mouse_pos)
		return

	if _skip_left_release_action:
		_skip_left_release_action = false
		return

	if _moving_building != null:
		_try_place_moving_building(mouse_pos)
		return

	if _pressed_building != null:
		_clear_pressed_building_tracking()
		return

	_try_place(mouse_pos)


func _handle_right_pressed(mouse_pos: Vector2, screen_pos: Vector2) -> void:
	_clear_pressed_building_tracking()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()

	if _moving_building != null:
		_cancel_move_mode()
		return

	var conveyor_id := map_manager.get_conveyor_id_at_world(mouse_pos)
	if conveyor_id != -1:
		interaction_menu.hide()
		_conveyor_deletion_menu.show_at_position(screen_pos, conveyor_id)
		return

	var clicked_building: Building = map_manager.get_building_at_world(mouse_pos)
	if clicked_building != null:
		_show_building_menu(clicked_building, screen_pos)
		return

	interaction_menu.hide()
	_cancel_selection()


func _layout_ui_bar() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var bar_height := clampf(viewport_size.y * 0.22, MIN_BAR_HEIGHT, BAR_HEIGHT)
	_apply_top_actions_layout()
	blueprint_sidebar.apply_sidebar_layout(viewport_size, bar_height)
	ui_bar.apply_bottom_bar_layout(bar_height, blueprint_sidebar.get_layout_reserved_width())


func _init_inventory() -> void:
	inventory.clear()
	for item_id in ItemDatabase.ITEM_ORDER:
		if not item_database.has(item_id):
			continue
		var data: Dictionary = item_database[item_id]
		inventory[item_id] = int(data.get("stock", 0))


func _setup_conveyor_tools() -> void:
	_directed_conveyor_planner = DIRECTED_CONVEYOR_PLANNER_V2_SCRIPT.new() as DirectedConveyorPlannerV2
	_directed_conveyor_planner.name = "DirectedConveyorPlannerV2"
	_directed_conveyor_planner.setup(map_manager)
	_directed_conveyor_planner.conveyor_mode_changed.connect(_on_conveyor_mode_changed)
	_directed_conveyor_planner.conveyor_generated.connect(_on_conveyor_generated)
	add_child(_directed_conveyor_planner)

	_conveyor_deletion_menu = CONVEYOR_DELETION_MENU_V2_SCRIPT.new() as ConveyorDeletionMenuV2
	_conveyor_deletion_menu.name = "ConveyorDeletionMenuV2"
	_conveyor_deletion_menu.delete_conveyor.connect(_on_delete_conveyor_requested)
	canvas_layer.add_child(_conveyor_deletion_menu)


func _setup_top_action_buttons() -> void:
	top_actions.mouse_filter = Control.MOUSE_FILTER_STOP
	top_actions.add_theme_constant_override("separation", 8)

	_style_action_button(undo_button, "撤销", Color(0.16, 0.32, 0.58, 0.94), Color(0.55, 0.77, 1.0, 1.0))
	_style_action_button(clear_button, "清空", Color(0.55, 0.16, 0.16, 0.94), Color(1.0, 0.64, 0.64, 1.0))
	_style_action_button(recipe_button, "配方", Color(0.15, 0.42, 0.3, 0.94), Color(0.57, 0.94, 0.78, 1.0))


func _style_action_button(button: Button, text: String, bg_color: Color, border_color: Color) -> void:
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(88.0, 42.0)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = border_color
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = bg_color.lightened(0.12)

	var disabled_style: StyleBoxFlat = normal_style.duplicate()
	disabled_style.bg_color = bg_color.darkened(0.35)
	disabled_style.border_color = border_color.darkened(0.35)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", disabled_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.65))


func _apply_top_actions_layout() -> void:
	top_actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	top_actions.position = Vector2(16.0, 16.0)
	top_actions.size = top_actions.get_combined_minimum_size()


func _on_item_selected(item_id: String) -> void:
	if is_conveyor_mode:
		_exit_conveyor_mode()
	if _moving_building != null:
		_cancel_move_mode()

	selected_item_id = item_id
	ui_bar.set_selected(item_id)
	interaction_menu.hide()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()
	_update_preview(get_global_mouse_position())


func _cancel_selection() -> void:
	selected_item_id = ""
	ui_bar.set_selected("")
	map_manager.clear_preview()


func _handle_conveyor_left_mouse(event: InputEventMouseButton) -> void:
	interaction_menu.hide()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()
	_clear_pressed_building_tracking()

	if event.pressed:
		return

	if camera_rig.consume_drag_release():
		_directed_conveyor_planner.handle_mouse_move(_last_mouse_position)
		return

	_directed_conveyor_planner.handle_left_click(_last_mouse_position)


func _toggle_conveyor_mode() -> void:
	if is_conveyor_mode:
		_directed_conveyor_planner.generate_complete_conveyor()
		return

	_enter_conveyor_mode()


func _enter_conveyor_mode() -> void:
	interaction_menu.hide()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()
	_clear_pressed_building_tracking()
	if _moving_building != null:
		_cancel_move_mode()
	_cancel_selection()
	_directed_conveyor_planner.enter_mode()


func _exit_conveyor_mode() -> void:
	if _directed_conveyor_planner == null:
		return
	_directed_conveyor_planner.exit_mode()


func _on_conveyor_mode_changed(active: bool) -> void:
	is_conveyor_mode = active
	if active:
		map_manager.clear_preview()
		return

	map_manager.clear_directed_conveyor_preview()
	_update_active_preview(_last_mouse_position)


func _on_delete_conveyor_requested(conveyor_id: int) -> void:
	if conveyor_id == -1:
		return

	if not map_manager.remove_conveyor(conveyor_id):
		return

	_remove_conveyor_operations(conveyor_id)
	_update_top_action_buttons()
	_update_active_preview(_last_mouse_position)


func _update_active_preview(mouse_pos: Vector2) -> void:
	if _moving_building != null:
		_update_move_preview(mouse_pos)
	else:
		_update_preview(mouse_pos)


func _update_preview(mouse_pos: Vector2) -> void:
	if selected_item_id.is_empty():
		map_manager.clear_preview()
		return
	if not item_database.has(selected_item_id):
		map_manager.clear_preview()
		return

	var item_data: Dictionary = item_database[selected_item_id]
	var grid_dimensions: Vector2i = item_data["size"]
	var top_left_cell: Vector2i = map_manager.world_to_cell(mouse_pos)
	var has_stock: bool = int(inventory.get(selected_item_id, 0)) > 0
	var can_place_here: bool = has_stock and map_manager.can_place(top_left_cell, grid_dimensions)
	map_manager.set_preview(top_left_cell, grid_dimensions, can_place_here, true)


func _try_place(mouse_pos: Vector2) -> void:
	if selected_item_id.is_empty():
		return
	if int(inventory.get(selected_item_id, 0)) <= 0:
		return
	if not item_database.has(selected_item_id):
		return

	var item_data: Dictionary = item_database[selected_item_id]
	var footprint: Vector2i = item_data["size"]
	var top_left_cell: Vector2i = map_manager.world_to_cell(mouse_pos)
	if not map_manager.can_place(top_left_cell, footprint):
		_update_preview(mouse_pos)
		return

	var building := _spawn_building(selected_item_id, top_left_cell)
	if building == null:
		_update_preview(mouse_pos)
		return

	inventory[selected_item_id] = int(inventory[selected_item_id]) - 1
	_push_operation({
		"type": OperationType.PLACE_BUILDING,
		"building": building
	})
	ui_bar.update_inventory(inventory)
	_update_preview(mouse_pos)


func _show_building_menu(building: Building, screen_pos: Vector2) -> void:
	_context_building = building
	interaction_menu.clear()
	interaction_menu.add_item("移动", BuildingAction.MOVE)
	interaction_menu.add_item("删除", BuildingAction.DELETE)
	interaction_menu.add_item("旋转", BuildingAction.ROTATE)
	interaction_menu.reset_size()
	interaction_menu.popup(Rect2i(Vector2i(screen_pos), Vector2i.ONE))


func _on_interaction_menu_id_pressed(action_id: int) -> void:
	interaction_menu.hide()
	if not is_instance_valid(_context_building):
		_context_building = null
		return

	var target_building: Building = _context_building
	_context_building = null

	match action_id:
		BuildingAction.MOVE:
			_begin_move_mode(target_building)
		BuildingAction.DELETE:
			_delete_building(target_building)
		BuildingAction.ROTATE:
			_rotate_building(target_building)


func _delete_building(building: Building, prune_history: bool = true) -> void:
	if not is_instance_valid(building):
		return

	if _moving_building == building:
		_moving_building = null
		map_manager.clear_preview()
		_sync_camera_drag_enabled()

	if prune_history:
		_remove_building_operations(building)

	map_manager.free_area(building.top_left_cell, building.footprint)
	inventory[building.item_id] = int(inventory.get(building.item_id, 0)) + 1
	ui_bar.update_inventory(inventory)
	building.queue_free()
	_update_top_action_buttons()
	_update_active_preview(_last_mouse_position)


func _rotate_building(building: Building) -> void:
	if not is_instance_valid(building):
		return

	var old_cell: Vector2i = building.top_left_cell
	var old_footprint: Vector2i = building.footprint
	var rotated_footprint: Vector2i = Vector2i(old_footprint.y, old_footprint.x)

	map_manager.free_area(old_cell, old_footprint)
	if not map_manager.can_place(old_cell, rotated_footprint):
		map_manager.occupy(old_cell, old_footprint, building)
		return

	building.rotate_clockwise()
	building.position = map_manager.cell_to_world_center(old_cell, building.footprint)
	map_manager.occupy(old_cell, building.footprint, building)
	_update_active_preview(_last_mouse_position)


func _begin_move_mode(building: Building) -> void:
	if not is_instance_valid(building):
		_clear_pressed_building_tracking()
		return

	_clear_pressed_building_tracking()
	interaction_menu.hide()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()
	_context_building = null

	if is_conveyor_mode:
		_exit_conveyor_mode()
	if _moving_building != null and _moving_building != building:
		_cancel_move_mode()
	if _moving_building == building:
		return

	selected_item_id = ""
	ui_bar.set_selected("")

	_moving_building = building
	_moving_origin_cell = building.top_left_cell
	map_manager.free_area(building.top_left_cell, building.footprint)
	building.set_drag_preview(true)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_skip_left_release_action = true
	_sync_camera_drag_enabled()
	_update_move_preview(_last_mouse_position)


func _update_move_preview(mouse_pos: Vector2) -> void:
	if _moving_building == null:
		return

	var top_left_cell: Vector2i = map_manager.world_to_cell(mouse_pos)
	var footprint: Vector2i = _moving_building.footprint
	var can_place_here: bool = map_manager.can_place(top_left_cell, footprint)

	_moving_building.position = map_manager.cell_to_world_center(top_left_cell, footprint)
	map_manager.set_preview(top_left_cell, footprint, can_place_here, true)


func _try_place_moving_building(mouse_pos: Vector2) -> void:
	if _moving_building == null:
		return

	var top_left_cell: Vector2i = map_manager.world_to_cell(mouse_pos)
	var footprint: Vector2i = _moving_building.footprint
	if not map_manager.can_place(top_left_cell, footprint):
		_update_move_preview(mouse_pos)
		return

	_moving_building.set_top_left_cell(top_left_cell)
	_moving_building.position = map_manager.cell_to_world_center(top_left_cell, footprint)
	_moving_building.set_drag_preview(false)
	map_manager.occupy(top_left_cell, footprint, _moving_building)
	_moving_building = null
	map_manager.clear_preview()
	_sync_camera_drag_enabled()


func _cancel_move_mode() -> void:
	if _moving_building == null:
		return

	_moving_building.set_top_left_cell(_moving_origin_cell)
	_moving_building.position = map_manager.cell_to_world_center(_moving_origin_cell, _moving_building.footprint)
	_moving_building.set_drag_preview(false)
	map_manager.occupy(_moving_origin_cell, _moving_building.footprint, _moving_building)
	_moving_building = null
	map_manager.clear_preview()
	_sync_camera_drag_enabled()
	_update_active_preview(_last_mouse_position)


func _clear_pressed_building_tracking() -> void:
	_pressed_building = null
	_pressed_duration = 0.0


func _sync_camera_drag_enabled() -> void:
	camera_rig.set_drag_enabled(_moving_building == null)


func _on_viewport_size_changed() -> void:
	call_deferred("_layout_ui_bar")


func _is_pointer_over_ui(screen_position: Vector2) -> bool:
	if _is_recipe_browser_open() and _recipe_browser.get_global_rect().has_point(screen_position):
		return true
	if is_instance_valid(ui_bar) and ui_bar.visible and ui_bar.get_global_rect().has_point(screen_position):
		return true
	if is_instance_valid(top_actions) and top_actions.visible and top_actions.get_global_rect().has_point(screen_position):
		return true
	if is_instance_valid(blueprint_sidebar) and blueprint_sidebar.visible and blueprint_sidebar.get_global_rect().has_point(screen_position):
		return true
	return false


func _spawn_building(item_id: String, top_left_cell: Vector2i, rotation_steps: int = 0) -> Building:
	if not item_database.has(item_id):
		return null

	var item_data: Dictionary = item_database[item_id]
	var building: Building = BUILDING_SCENE.instantiate() as Building
	map_manager.add_child(building)
	building.setup(item_id, item_data["icon"], MapManager.CELL_SIZE, item_data["size"])

	var normalized_rotation := posmod(rotation_steps, 4)
	for _i in normalized_rotation:
		building.rotate_clockwise()

	if not map_manager.can_place(top_left_cell, building.footprint):
		building.queue_free()
		return null

	building.set_top_left_cell(top_left_cell)
	building.position = map_manager.cell_to_world_center(top_left_cell, building.footprint)
	map_manager.occupy(top_left_cell, building.footprint, building)
	return building


func _on_blueprint_save_requested(blueprint_name: String) -> void:
	var normalized_name: String = blueprint_name.strip_edges()
	if normalized_name.is_empty():
		return

	if _find_blueprint_index(normalized_name) != -1:
		blueprint_sidebar.show_duplicate_name_warning("蓝图名称已存在，请重新命名")
		return

	var blueprint_data := {
		"name": normalized_name,
		"items": _collect_blueprint_items(),
		"conveyors": map_manager.get_serialized_conveyors()
	}
	_blueprints.append(blueprint_data)
	_save_blueprints()
	_refresh_blueprint_list()
	blueprint_sidebar.confirm_save_success()


func _on_blueprint_rename_requested(old_name: String, new_name: String) -> void:
	var old_blueprint_name: String = old_name.strip_edges()
	var new_blueprint_name: String = new_name.strip_edges()
	if old_blueprint_name.is_empty() or new_blueprint_name.is_empty():
		return

	if new_blueprint_name == old_blueprint_name:
		blueprint_sidebar.confirm_save_success()
		return

	var old_blueprint_index: int = _find_blueprint_index(old_blueprint_name)
	if old_blueprint_index == -1:
		return

	if _find_blueprint_index(new_blueprint_name) != -1:
		blueprint_sidebar.show_duplicate_name_warning("不可以重命名，请重新命名")
		return

	var renamed_blueprint: Dictionary = (_blueprints[old_blueprint_index] as Dictionary).duplicate(true)
	renamed_blueprint["name"] = new_blueprint_name
	_blueprints[old_blueprint_index] = renamed_blueprint
	_save_blueprints()
	_refresh_blueprint_list()
	blueprint_sidebar.confirm_save_success()


func _on_blueprint_load_requested(blueprint_name: String) -> void:
	var blueprint_index := _find_blueprint_index(blueprint_name)
	if blueprint_index == -1:
		return

	_prepare_blueprint_edit_mode()
	_clear_current_map(true)

	var blueprint: Dictionary = _blueprints[blueprint_index]
	var blueprint_items: Array = blueprint.get("items", [])
	for item_variant in blueprint_items:
		var item_data := item_variant as Dictionary
		if item_data.is_empty():
			continue
		_restore_blueprint_item(item_data)

	map_manager.restore_serialized_conveyors(blueprint.get("conveyors", []))
	ui_bar.update_inventory(inventory)
	_update_active_preview(_last_mouse_position)


func _on_blueprint_delete_requested(blueprint_name: String) -> void:
	var blueprint_index := _find_blueprint_index(blueprint_name)
	if blueprint_index == -1:
		return

	_blueprints.remove_at(blueprint_index)
	_save_blueprints()
	_refresh_blueprint_list()


func _prepare_blueprint_edit_mode() -> void:
	interaction_menu.hide()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()
	_context_building = null
	_clear_pressed_building_tracking()
	if _moving_building != null:
		_cancel_move_mode()
	if is_conveyor_mode:
		_exit_conveyor_mode()
	_cancel_selection()


func _clear_current_map(reset_history: bool = false) -> void:
	for building in map_manager.get_buildings():
		if not is_instance_valid(building):
			continue
		map_manager.free_area(building.top_left_cell, building.footprint)
		inventory[building.item_id] = int(inventory.get(building.item_id, 0)) + 1
		building.queue_free()

	map_manager.clear_conveyors()
	map_manager.clear_preview()
	if reset_history:
		_clear_operation_history()
	ui_bar.update_inventory(inventory)
	_update_top_action_buttons()


func _collect_blueprint_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for building in map_manager.get_buildings():
		if not is_instance_valid(building):
			continue
		items.append({
			"item_id": building.item_id,
			"cell": {
				"x": building.top_left_cell.x,
				"y": building.top_left_cell.y
			},
			"rotation_steps": building.rotation_steps
		})
	return items


func _restore_blueprint_item(item_data: Dictionary) -> void:
	var item_id := str(item_data.get("item_id", ""))
	if item_id.is_empty():
		return
	if not item_database.has(item_id):
		push_warning("Skipping blueprint item with unknown item_id: %s" % item_id)
		return

	var building := _spawn_building(item_id, _parse_blueprint_cell(item_data.get("cell", {})), int(item_data.get("rotation_steps", 0)))
	if building == null:
		push_warning("Skipping blueprint item that can not be placed: %s" % item_id)
		return

	inventory[item_id] = int(inventory.get(item_id, 0)) - 1


func _parse_blueprint_cell(cell_data: Variant) -> Vector2i:
	if cell_data is Dictionary:
		var cell_dict := cell_data as Dictionary
		return Vector2i(int(cell_dict.get("x", 0)), int(cell_dict.get("y", 0)))
	if cell_data is Array:
		var cell_array := cell_data as Array
		if cell_array.size() >= 2:
			return Vector2i(int(cell_array[0]), int(cell_array[1]))
	return Vector2i.ZERO


func _refresh_blueprint_list() -> void:
	var blueprint_names: Array[String] = []
	for blueprint in _blueprints:
		blueprint_names.append(str(blueprint.get("name", "")))
	blueprint_sidebar.refresh_blueprints(blueprint_names)


func _find_blueprint_index(blueprint_name: String) -> int:
	for index in _blueprints.size():
		var blueprint: Dictionary = _blueprints[index]
		if str(blueprint.get("name", "")) == blueprint_name:
			return index
	return -1


func _load_blueprints() -> void:
	if not FileAccess.file_exists(BLUEPRINT_SAVE_PATH):
		_blueprints.clear()
		_save_blueprints()
		return

	var file := FileAccess.open(BLUEPRINT_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Failed to open blueprint save file for reading.")
		_blueprints.clear()
		return

	var raw_text := file.get_as_text().strip_edges()
	file.close()
	if raw_text.is_empty():
		_blueprints.clear()
		_save_blueprints()
		return

	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_warning("Blueprint save file is invalid. Resetting blueprint data.")
		_blueprints.clear()
		_save_blueprints()
		return

	_blueprints.clear()
	var parsed_blueprints: Array = (parsed as Dictionary).get("blueprints", [])
	for blueprint_variant in parsed_blueprints:
		var blueprint := blueprint_variant as Dictionary
		if blueprint.is_empty():
			continue
		if not blueprint.has("name"):
			continue
		blueprint["items"] = blueprint.get("items", [])
		blueprint["conveyors"] = blueprint.get("conveyors", [])
		_blueprints.append(blueprint)


func _save_blueprints() -> void:
	var file := FileAccess.open(BLUEPRINT_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open blueprint save file for writing.")
		return

	file.store_string(JSON.stringify({
		"blueprints": _blueprints
	}, "\t"))
	file.close()


func _on_conveyor_generated(conveyor_id: int) -> void:
	if conveyor_id == -1:
		return

	_push_operation({
		"type": OperationType.ADD_CONVEYOR,
		"conveyor_id": conveyor_id
	})


func _on_undo_pressed() -> void:
	if _operation_history.is_empty():
		return

	interaction_menu.hide()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()
	_clear_pressed_building_tracking()
	if _moving_building != null:
		_cancel_move_mode()
	if is_conveyor_mode:
		_exit_conveyor_mode()

	var operation: Dictionary = _operation_history.pop_back()
	match int(operation.get("type", -1)):
		OperationType.PLACE_BUILDING:
			var building: Building = operation.get("building") as Building
			if is_instance_valid(building):
				_delete_building(building, false)
		OperationType.ADD_CONVEYOR:
			var conveyor_id: int = int(operation.get("conveyor_id", -1))
			if conveyor_id != -1:
				map_manager.remove_conveyor(conveyor_id)
				_update_active_preview(_last_mouse_position)

	_update_top_action_buttons()


func _on_clear_pressed() -> void:
	_prepare_blueprint_edit_mode()
	_clear_current_map(true)


func _on_recipe_button_pressed() -> void:
	if _is_recipe_browser_open():
		_close_recipe_browser()
		return
	_open_recipe_browser()


func _push_operation(operation: Dictionary) -> void:
	_operation_history.append(operation)
	_update_top_action_buttons()


func _clear_operation_history() -> void:
	_operation_history.clear()


func _remove_building_operations(building: Building) -> void:
	for index in range(_operation_history.size() - 1, -1, -1):
		var operation: Dictionary = _operation_history[index]
		if int(operation.get("type", -1)) != OperationType.PLACE_BUILDING:
			continue
		if operation.get("building") == building:
			_operation_history.remove_at(index)


func _remove_conveyor_operations(conveyor_id: int) -> void:
	for index in range(_operation_history.size() - 1, -1, -1):
		var operation: Dictionary = _operation_history[index]
		if int(operation.get("type", -1)) != OperationType.ADD_CONVEYOR:
			continue
		if int(operation.get("conveyor_id", -1)) == conveyor_id:
			_operation_history.remove_at(index)


func _update_top_action_buttons() -> void:
	undo_button.disabled = _operation_history.is_empty()
	clear_button.disabled = map_manager.get_buildings().is_empty() and map_manager.directed_conveyors.is_empty()


func _is_recipe_browser_open() -> bool:
	return is_instance_valid(_recipe_browser) and _recipe_browser.is_inside_tree()


func _open_recipe_browser() -> void:
	if _is_recipe_browser_open():
		if not selected_item_id.is_empty():
			_recipe_browser.set_search_text(selected_item_id)
		return

	interaction_menu.hide()
	if _conveyor_deletion_menu != null:
		_conveyor_deletion_menu.hide()
	_clear_pressed_building_tracking()

	if is_conveyor_mode:
		_exit_conveyor_mode()
	if _moving_building != null:
		_cancel_move_mode()

	_recipe_browser = RECIPE_BROWSER_SCENE.instantiate() as RecipeBrowser
	if _recipe_browser == null:
		push_warning("Failed to create recipe browser.")
		return

	_recipe_browser.name = "RecipeBrowser"
	_recipe_browser.close_requested.connect(_on_recipe_browser_close_requested)
	_recipe_browser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recipe_browser.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_layer.add_child(_recipe_browser)

	if not selected_item_id.is_empty():
		_recipe_browser.set_search_text(selected_item_id)


func _close_recipe_browser() -> void:
	if not _is_recipe_browser_open():
		_recipe_browser = null
		return

	_recipe_browser.queue_free()
	_recipe_browser = null


func _on_recipe_browser_close_requested() -> void:
	_close_recipe_browser()
