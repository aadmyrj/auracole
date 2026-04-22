extends VBoxContainer
class_name BlueprintSidebar

signal save_requested(blueprint_name: String)
signal load_requested(blueprint_name: String)
signal delete_requested(blueprint_name: String)
signal rename_requested(old_name: String, new_name: String)

const MENU_LOAD_BLUEPRINT: int = 0
const MENU_RENAME_BLUEPRINT: int = 1
const MENU_DELETE_BLUEPRINT: int = 2
const SIDEBAR_WIDTH: float = 280.0
const OUTER_MARGIN: float = 16.0

enum NameDialogMode {
	SAVE,
	RENAME
}

@onready var save_button: Button = $SaveBlueprintButton
@onready var blueprint_scroll: ScrollContainer = $BlueprintScroll
@onready var blueprint_list: VBoxContainer = $BlueprintScroll/BlueprintList
@onready var name_dialog: AcceptDialog = $BlueprintNameDialog
@onready var name_input: LineEdit = $BlueprintNameDialog/BlueprintNameInput
@onready var context_menu: PopupMenu = $BlueprintContextMenu

var _selected_blueprint_name: String = ""
var _known_blueprint_names: Array[String] = []
var _name_dialog_mode: int = NameDialogMode.SAVE
var _renaming_blueprint_name: String = ""
var _duplicate_warning_dialog: AcceptDialog = AcceptDialog.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_style()
	_configure_layout()
	_configure_name_dialog()
	_configure_warning_dialog()

	save_button.text = "保存蓝图"
	save_button.pressed.connect(_on_save_button_pressed)

	name_dialog.title = "保存蓝图"
	name_dialog.dialog_text = "请输入蓝图名称"
	name_dialog.confirmed.connect(_on_name_dialog_confirmed)
	name_input.placeholder_text = ""
	name_input.text_submitted.connect(_on_name_input_submitted)

	context_menu.clear()
	context_menu.add_item("加载蓝图", MENU_LOAD_BLUEPRINT)
	context_menu.add_item("重命名", MENU_RENAME_BLUEPRINT)
	context_menu.add_item("删除蓝图", MENU_DELETE_BLUEPRINT)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)


func apply_sidebar_layout(viewport_size: Vector2, bottom_reserved_height: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -SIDEBAR_WIDTH - OUTER_MARGIN
	offset_top = OUTER_MARGIN
	offset_right = -OUTER_MARGIN
	offset_bottom = -bottom_reserved_height - OUTER_MARGIN
	custom_minimum_size = Vector2(SIDEBAR_WIDTH, 0.0)
	size = Vector2(SIDEBAR_WIDTH, maxf(0.0, viewport_size.y - bottom_reserved_height - OUTER_MARGIN * 2.0))


func get_layout_reserved_width() -> float:
	return SIDEBAR_WIDTH + OUTER_MARGIN * 2.0


func refresh_blueprints(blueprint_names: Array[String]) -> void:
	_known_blueprint_names = blueprint_names.duplicate()

	for child in blueprint_list.get_children():
		child.queue_free()

	for blueprint_name in blueprint_names:
		blueprint_list.add_child(_build_blueprint_button(blueprint_name))


func confirm_save_success() -> void:
	_reset_name_dialog_state()
	name_dialog.hide()


func show_duplicate_name_warning(warning_text: String = "不可以重命名，请重新命名") -> void:
	_duplicate_warning_dialog.dialog_text = warning_text
	_duplicate_warning_dialog.popup_centered(Vector2i(340, 0))
	await get_tree().process_frame
	name_input.grab_focus()


func _apply_style() -> void:
	add_theme_constant_override("separation", 12)

	var save_button_style := StyleBoxFlat.new()
	save_button_style.bg_color = Color(0.12, 0.29, 0.55, 0.94)
	save_button_style.border_width_left = 2
	save_button_style.border_width_top = 2
	save_button_style.border_width_right = 2
	save_button_style.border_width_bottom = 2
	save_button_style.border_color = Color(0.58, 0.78, 1.0, 1.0)
	save_button_style.corner_radius_top_left = 10
	save_button_style.corner_radius_top_right = 10
	save_button_style.corner_radius_bottom_left = 10
	save_button_style.corner_radius_bottom_right = 10
	save_button_style.content_margin_left = 12
	save_button_style.content_margin_right = 12
	save_button_style.content_margin_top = 10
	save_button_style.content_margin_bottom = 10

	var hover_style: StyleBoxFlat = save_button_style.duplicate()
	hover_style.bg_color = Color(0.16, 0.37, 0.69, 0.97)

	var pressed_style: StyleBoxFlat = save_button_style.duplicate()
	pressed_style.bg_color = Color(0.09, 0.22, 0.42, 0.98)

	save_button.add_theme_stylebox_override("normal", save_button_style)
	save_button.add_theme_stylebox_override("hover", hover_style)
	save_button.add_theme_stylebox_override("pressed", pressed_style)
	save_button.add_theme_color_override("font_color", Color.WHITE)


func _configure_layout() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.custom_minimum_size = Vector2(0.0, 44.0)

	blueprint_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blueprint_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blueprint_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	blueprint_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	blueprint_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blueprint_list.add_theme_constant_override("separation", 8)


func _configure_name_dialog() -> void:
	name_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_input.offset_left = 12.0
	name_input.offset_top = 48.0
	name_input.offset_right = -12.0
	name_input.offset_bottom = -56.0
	name_input.custom_minimum_size = Vector2(0.0, 34.0)


func _configure_warning_dialog() -> void:
	_duplicate_warning_dialog.title = "提示"
	_duplicate_warning_dialog.dialog_text = "不可以重命名，请重新命名"
	_duplicate_warning_dialog.exclusive = false
	_duplicate_warning_dialog.confirmed.connect(_on_duplicate_warning_confirmed)
	add_child(_duplicate_warning_dialog)


func _build_blueprint_button(blueprint_name: String) -> Button:
	var button := Button.new()
	button.text = blueprint_name
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.clip_text = true
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _create_blueprint_item_style(Color(0.07, 0.07, 0.1, 0.88), Color(0.4, 0.63, 1.0, 0.95)))
	button.add_theme_stylebox_override("hover", _create_blueprint_item_style(Color(0.12, 0.16, 0.24, 0.92), Color(0.58, 0.8, 1.0, 1.0)))
	button.add_theme_stylebox_override("pressed", _create_blueprint_item_style(Color(0.08, 0.11, 0.18, 0.96), Color(0.72, 0.88, 1.0, 1.0)))
	button.gui_input.connect(_on_blueprint_button_gui_input.bind(blueprint_name))
	return button


func _create_blueprint_item_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _on_save_button_pressed() -> void:
	_name_dialog_mode = NameDialogMode.SAVE
	_renaming_blueprint_name = ""
	await _popup_name_dialog("", false)


func _on_name_dialog_confirmed() -> void:
	_submit_blueprint_name()


func _on_name_input_submitted(_submitted_text: String) -> void:
	_submit_blueprint_name()


func _submit_blueprint_name() -> void:
	var new_blueprint_name: String = name_input.text.strip_edges()
	if new_blueprint_name.is_empty():
		return

	match _name_dialog_mode:
		NameDialogMode.SAVE:
			if _has_duplicate_blueprint_name(new_blueprint_name):
				show_duplicate_name_warning("蓝图名称已存在，请重新命名")
				return
			save_requested.emit(new_blueprint_name)
		NameDialogMode.RENAME:
			var old_blueprint_name: String = _renaming_blueprint_name.strip_edges()
			if new_blueprint_name == old_blueprint_name:
				confirm_save_success()
				return
			if _has_duplicate_blueprint_name(new_blueprint_name):
				show_duplicate_name_warning("不可以重命名，请重新命名")
				return
			rename_requested.emit(old_blueprint_name, new_blueprint_name)


func _on_blueprint_button_gui_input(event: InputEvent, blueprint_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_selected_blueprint_name = blueprint_name
		context_menu.reset_size()
		context_menu.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ONE))


func _on_context_menu_id_pressed(id: int) -> void:
	if _selected_blueprint_name.is_empty():
		return

	match id:
		MENU_LOAD_BLUEPRINT:
			load_requested.emit(_selected_blueprint_name)
		MENU_RENAME_BLUEPRINT:
			_name_dialog_mode = NameDialogMode.RENAME
			_renaming_blueprint_name = _selected_blueprint_name
			await _popup_name_dialog(_selected_blueprint_name, true)
		MENU_DELETE_BLUEPRINT:
			delete_requested.emit(_selected_blueprint_name)


func _on_duplicate_warning_confirmed() -> void:
	await get_tree().process_frame
	name_input.grab_focus()


func _has_duplicate_blueprint_name(blueprint_name: String) -> bool:
	return _known_blueprint_names.has(blueprint_name)


func _popup_name_dialog(initial_text: String, should_select_all: bool) -> void:
	name_input.text = initial_text
	name_dialog.popup_centered(Vector2i(340, 0))
	await get_tree().process_frame
	name_input.grab_focus()
	if should_select_all:
		name_input.select_all()
	else:
		name_input.caret_column = name_input.text.length()


func _reset_name_dialog_state() -> void:
	_name_dialog_mode = NameDialogMode.SAVE
	_renaming_blueprint_name = ""
