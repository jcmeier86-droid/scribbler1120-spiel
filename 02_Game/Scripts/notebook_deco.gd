class_name NotebookDeco
extends Control
## Verzierung der Notizbuch-Karte: zweite Tuschekontur und Wappenschild (weiße Feder auf Türrot).

func _draw() -> void:
	var ink := Color("#1E1E1C")
	# Wappenschild
	var o := Vector2(2, 2)
	var shield := PackedVector2Array([o, o + Vector2(52, 0), o + Vector2(52, 34), o + Vector2(26, 62), o + Vector2(0, 34)])
	draw_colored_polygon(shield, Color("#7A2B30"))
	draw_polyline(shield + PackedVector2Array([shield[0]]), ink, 2.5, true)
	var quill := PackedVector2Array([o + Vector2(14, 50), o + Vector2(20, 30), o + Vector2(34, 12), o + Vector2(42, 8), o + Vector2(38, 22), o + Vector2(24, 42)])
	draw_colored_polygon(quill, Color("#FAF9F6"))
	draw_polyline(quill + PackedVector2Array([quill[0]]), ink, 1.5, true)
	draw_line(o + Vector2(12, 54), o + Vector2(40, 12), ink, 1.5, true)
