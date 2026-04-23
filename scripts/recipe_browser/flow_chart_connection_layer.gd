class_name FlowChartConnectionLayer
extends Control

const LINE_COLOR: Color = Color("cfe1ff")
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.22)
const LINE_WIDTH: float = 3.0
const ARROW_SIZE: float = 10.0
const HORIZONTAL_OFFSET: float = 42.0

var _connections: Array[Dictionary] = []


func set_connections(connections: Array[Dictionary]) -> void:
	_connections = connections
	queue_redraw()


func clear_connections() -> void:
	_connections.clear()
	queue_redraw()


func _draw() -> void:
	for connection in _connections:
		var from_node: Control = connection.get("from")
		var to_node: Control = connection.get("to")

		if not is_instance_valid(from_node) or not is_instance_valid(to_node):
			continue

		var from_pos: Vector2 = from_node.position + Vector2(from_node.size.x, from_node.size.y * 0.5)
		var to_pos: Vector2 = to_node.position + Vector2(0.0, to_node.size.y * 0.5)
		var middle_x: float = lerpf(from_pos.x, to_pos.x, 0.5)
		var bend_in: float = minf(HORIZONTAL_OFFSET, absf(to_pos.x - from_pos.x) * 0.25)
		var point_a: Vector2 = from_pos
		var point_b: Vector2 = Vector2(from_pos.x + bend_in, from_pos.y)
		var point_c: Vector2 = Vector2(middle_x, from_pos.y)
		var point_d: Vector2 = Vector2(middle_x, to_pos.y)
		var point_e: Vector2 = Vector2(to_pos.x - bend_in, to_pos.y)
		var point_f: Vector2 = to_pos

		_draw_segment(point_a, point_b)
		_draw_segment(point_b, point_c)
		_draw_segment(point_c, point_d)
		_draw_segment(point_d, point_e)
		_draw_segment(point_e, point_f)
		_draw_arrow(point_e, point_f)


func _draw_segment(from_pos: Vector2, to_pos: Vector2) -> void:
	draw_line(from_pos + Vector2(1, 1), to_pos + Vector2(1, 1), SHADOW_COLOR, LINE_WIDTH + 1.0)
	draw_line(from_pos, to_pos, LINE_COLOR, LINE_WIDTH)


func _draw_arrow(from_pos: Vector2, to_pos: Vector2) -> void:
	var direction: Vector2 = (to_pos - from_pos).normalized()
	if direction == Vector2.ZERO:
		return

	var side: Vector2 = Vector2(-direction.y, direction.x)
	var back: Vector2 = to_pos - direction * ARROW_SIZE
	var left: Vector2 = back + side * (ARROW_SIZE * 0.6)
	var right: Vector2 = back - side * (ARROW_SIZE * 0.6)

	draw_colored_polygon(PackedVector2Array([to_pos, left, right]), LINE_COLOR)
