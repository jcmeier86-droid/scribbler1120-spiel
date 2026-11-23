extends Node3D
## Hauptszene: lädt einen Ortsteil aus den Kartendaten, baut die Welt und steuert Federn, Stationen und Oberfläche.

const AREA_FILE := "res://03_World/Geographic_Data/dorfmitte.json"
const PAPER := preload("res://02_Game/Shaders/paper.gdshader")
const TOON := preload("res://02_Game/Shaders/ink_toon.gdshader")

var data: Dictionary
var terrain: Terrain
var builder: WorldBuilder
var player: Player
var found_pages := {}
var feathers_got := 0
var near_station: Area3D = null
var dialog_lines: Array = []

var hud: Label
var hint: Label
var place: Label
var dialog: PanelContainer
var dialog_text: RichTextLabel
var joy_origin := Vector2.ZERO
var joy_index := -1

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(AREA_FILE))
	_environment()
	terrain = Terrain.new(data["water"], data.get("valley_extra", []))
	var ground := ShaderMaterial.new()
	ground.shader = TOON
	ground.set_shader_parameter("albedo", Color("#A2AC86"))
	terrain.build(self, ground)
	builder = WorldBuilder.new(terrain, self)
	builder.build_roads(data["roads"], data["water"])
	builder.build_buildings(data["buildings"])
	builder.build_platforms(data.get("platforms", []))
	builder.build_stations(data["stations"])
	builder.build_feathers(data["roads"], data.get("platforms", []))
	for f in builder.feathers:
		f.body_entered.connect(_on_feather.bind(f))
	for s in builder.stations:
		s.body_entered.connect(_on_station_enter.bind(s))
		s.body_exited.connect(_on_station_exit.bind(s))
	player = Player.new()
	player.name = "Schreiberling"
	var st: Array = data["start"]
	player.position = Vector3(st[0], terrain.surface(st[0], st[1]) + 0.5, st[1])
	add_child(player)
	_ui()
	_update_hud()
	_debug_args()

## Testhilfe: godot -- --at=kirche --shot=bild.png  (setzt die Figur an eine Station und speichert ein Bild)
func _debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			for s in builder.stations:
				if s.get_meta("station")["id"] == a.substr(5):
					player.global_position = s.global_position + Vector3(0, 0.5, 6)
					player.cam_pivot.global_position = player.global_position + Vector3(0, 2.2, 0)
		if a.begins_with("--yaw="):
			player.cam_yaw = deg_to_rad(float(a.substr(6)))
		if a.begins_with("--shot="):
			var path := a.substr(7)
			await get_tree().create_timer(2.5).timeout
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#BFD0D8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#E7E5DF")
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color("#E7E5DF")
	env.fog_density = 0.0018
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_color = Color("#FFF4E0")
	sun.light_energy = 1.05
	add_child(sun)

# ---------------------------------------------------------------- Oberfläche
func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var paper := ColorRect.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = PAPER
	paper.material = pm
	layer.add_child(paper)
	hud = _label(layer, Vector2(16, 12), 22)
	place = _label(layer, Vector2(16, 44), 18)
	place.text = data.get("name", "")
	hint = _label(layer, Vector2(16, 0), 20)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -150
	hint.visible = false
	dialog = PanelContainer.new()
	dialog.anchor_left = 0.5
	dialog.anchor_right = 0.5
	dialog.offset_left = -300
	dialog.offset_right = 300
	dialog.offset_top = 70
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FAF9F6")
	sb.border_color = Color("#1E1E1C")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(18)
	dialog.add_theme_stylebox_override("panel", sb)
	dialog_text = RichTextLabel.new()
	dialog_text.bbcode_enabled = true
	dialog_text.fit_content = true
	dialog_text.custom_minimum_size = Vector2(560, 0)
	dialog_text.add_theme_color_override("default_color", Color("#1E1E1C"))
	dialog_text.add_theme_font_size_override("normal_font_size", 20)
	dialog_text.add_theme_font_size_override("bold_font_size", 26)
	dialog.add_child(dialog_text)
	dialog.visible = false
	layer.add_child(dialog)
	var jump := Button.new()
	jump.text = "Hopp!"
	jump.anchor_left = 1.0
	jump.anchor_right = 1.0
	jump.anchor_top = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -130
	jump.offset_top = -130
	jump.offset_right = -24
	jump.offset_bottom = -24
	jump.add_theme_font_size_override("font_size", 26)
	jump.pressed.connect(func(): player.request_jump())
	layer.add_child(jump)

func _label(parent: Node, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#1E1E1C"))
	l.add_theme_color_override("font_outline_color", Color("#FAF9F6"))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l

func _update_hud() -> void:
	hud.text = "Federn %d / %d     Geschichten %d / %d" % [feathers_got, builder.feathers.size(), found_pages.size(), builder.stations.size()]

# ---------------------------------------------------------------- Spiel
func _on_feather(body: Node, f: Area3D) -> void:
	if body != player or not f.visible:
		return
	f.visible = false
	f.set_deferred("monitoring", false)
	feathers_got += 1
	_update_hud()

func _on_station_enter(body: Node, s: Area3D) -> void:
	if body == player:
		near_station = s
		hint.text = "Enter / F: Geschichte lesen – " + s.get_meta("station")["title"]
		hint.visible = true

func _on_station_exit(body: Node, s: Area3D) -> void:
	if body == player and near_station == s:
		near_station = null
		hint.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if dialog.visible:
			_next_line()
		elif near_station:
			var st: Dictionary = near_station.get_meta("station")
			found_pages[st["id"]] = true
			_update_hud()
			dialog_lines = st["text"].duplicate()
			if st.get("sample_text", false):
				dialog_lines.append("[i]Teilweise Beispieltext – die echten Inhalte folgen.[/i]")
			dialog_text.set_meta("title", st["title"])
			player.input_locked = true
			_next_line()
	# Touch: linke Bildschirmhälfte = Joystick
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and joy_index == -1:
			joy_index = event.index
			joy_origin = event.position
		elif not event.pressed and event.index == joy_index:
			joy_index = -1
			player.touch_move = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == joy_index:
		player.touch_move = ((event.position - joy_origin) / 70.0).limit_length(1.0)

func _next_line() -> void:
	if dialog_lines.is_empty():
		dialog.visible = false
		player.input_locked = false
		return
	var line: String = dialog_lines.pop_front()
	dialog_text.text = "[b]%s[/b]\n%s" % [dialog_text.get_meta("title"), line]
	dialog.visible = true

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in builder.feathers:
		if f.visible:
			f.rotation.y += delta * 2.0
	for s in builder.stations:
		var m: Node3D = s.get_node("Marker")
		m.position.y = 3.4 + sin(t * 2.0 + s.position.x) * 0.2
		m.modulate.a = 0.45 if found_pages.has(s.get_meta("station")["id"]) else 1.0
