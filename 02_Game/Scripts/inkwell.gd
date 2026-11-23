class_name Inkwell
extends Control
## Tintenfass-Anzeige: gezeichnetes Tintenfass mit Feder, daneben Fortschrittsbalken in Vereinsgrün.

var progress := 0.0
const INK := Color("#1E1E1C")
const GREEN := Color("#2E6B3E")
const PAPER := Color("#FAF9F6")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(18, 14)
	size = Vector2(320, 76)

func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	# Tintenfass
	var body := PackedVector2Array([Vector2(10, 70), Vector2(8, 44), Vector2(18, 34), Vector2(22, 26), Vector2(42, 26), Vector2(46, 34), Vector2(56, 44), Vector2(54, 70)])
	draw_colored_polygon(body, Color("#2B3550"))
	draw_polyline(body + PackedVector2Array([body[0]]), INK, 3.0, true)
	draw_rect(Rect2(20, 18, 24, 9), INK)
	draw_line(Vector2(16, 48), Vector2(22, 62), Color(1, 1, 1, 0.35), 3.0)
	# Feder
	var quill := PackedVector2Array([Vector2(34, 22), Vector2(52, -2), Vector2(70, -10), Vector2(64, 6), Vector2(40, 24)])
	draw_colored_polygon(quill, PAPER)
	draw_polyline(quill + PackedVector2Array([quill[0]]), INK, 2.0, true)
	draw_line(Vector2(32, 30), Vector2(66, -6), INK, 2.0, true)
	# Balken
	var r := Rect2(74, 40, 230, 16)
	draw_rect(r, PAPER)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2((r.size.x - 4) * progress, r.size.y - 4)), GREEN)
	draw_rect(r, INK, false, 2.5)
