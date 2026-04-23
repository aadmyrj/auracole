class_name StepNode
extends PanelContainer

@onready var kind_label: Label = %KindLabel
@onready var name_label: Label = %StepName
@onready var time_label: Label = %StepTime

var _styles: Dictionary = {
	"input": _build_style("18314a", "55a7ff"),
	"device": _build_style("2f2b4a", "ac8fff"),
	"output": _build_style("173640", "56d5c0"),
	"default": _build_style("1d2436", "8ea3c9"),
}


func setup_step(step_data: Dictionary) -> void:
	var kind: String = String(step_data.get("kind", "default"))
	var style: StyleBoxFlat = _styles.get(kind, _styles["default"])

	name_label.text = String(step_data.get("name", "未命名步骤"))
	kind_label.text = _get_kind_name(kind)
	time_label.text = _get_time_text(step_data)
	time_label.visible = not time_label.text.is_empty()

	position = step_data.get("pos", Vector2.ZERO)
	size = step_data.get("size", Vector2(180, 92))

	add_theme_stylebox_override("panel", style)


func _get_kind_name(kind: String) -> String:
	match kind:
		"input":
			return "输入"
		"device":
			return "设备"
		"output":
			return "输出"
		_:
			return "步骤"


func _get_time_text(step_data: Dictionary) -> String:
	if not step_data.has("duration"):
		return ""

	var duration: float = float(step_data["duration"])
	if duration <= 0.0:
		return ""

	return "%.1f 秒" % duration


static func _build_style(background: String, border: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(background)
	style.border_color = Color(border)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style
