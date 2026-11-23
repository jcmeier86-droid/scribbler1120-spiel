class_name Joystick
extends Control
## Sichtbarer Joystick unten links im Scribbler-Stil (Papierkreis mit Tuschekontur, türroter Knauf).

var knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 24
	offset_right = 224
	offset_top = -224
	offset_bottom = -24

func center() -> Vector2:
	return global_position + size * 0.5

func radius() -> float:
	return size.x * 0.5 - 18.0

func hit(p: Vector2) -> bool:
	return p.distance_to(center()) < size.x * 0.75

func set_knob(v: Vector2) -> void:
	knob = v
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := size.x * 0.5 - 4.0
	draw_circle(c + Vector2(0, 5), r, Color(0.12, 0.12, 0.11, 0.25))
	draw_circle(c, r, Color(0.98, 0.976, 0.965, 0.72))
	draw_arc(c, r, 0, TAU, 64, Color("#1E1E1C"), 4.0, true)
	for a in [0.0, PI / 2, PI, PI * 1.5]:
		var d := Vector2.RIGHT.rotated(a)
		var tip := c + d * (r - 14)
		draw_colored_polygon(PackedVector2Array([tip, tip - d * 14 + d.orthogonal() * 9, tip - d * 14 - d.orthogonal() * 9]), Color("#6B6A65"))
	var k := c + knob * radius()
	draw_circle(k + Vector2(0, 4), 34, Color(0.12, 0.12, 0.11, 0.35))
	draw_circle(k, 34, Color("#7A2B30"))
	draw_arc(k, 34, 0, TAU, 48, Color("#1E1E1C"), 4.0, true)
	draw_circle(k + Vector2(-10, -10), 8, Color(1, 1, 1, 0.25))
