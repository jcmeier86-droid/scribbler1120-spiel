extends Node3D
## Hauptszene: lädt einen Ortsteil aus den Kartendaten, baut die Welt und steuert Federn, Stationen und Oberfläche.

const AREA_FILE := "res://03_World/Geographic_Data/dorfmitte.json"
const PAPER := preload("res://02_Game/Shaders/paper.gdshader")
const TOON := preload("res://02_Game/Shaders/ink_toon.gdshader")
const F_HEAD := preload("res://02_Game/UI/fonts/Fraunces-600.woff2")
const F_TEXT := preload("res://02_Game/UI/fonts/Inter-400.woff2")
const F_BOLD := preload("res://02_Game/UI/fonts/Inter-600.woff2")

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
var joy_index := -1
var cam_index := -1
var joystick: Joystick
var read_btn: Button
var inkwell: Inkwell

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(AREA_FILE))
	_environment()
	terrain = Terrain.new(data["water"], data.get("valley_extra", []))
	var ground := ShaderMaterial.new()
	ground.shader = TOON
	ground.set_shader_parameter("albedo", Color("#7C8F62"))
	ground.set_shader_parameter("grass", true)
	ground.set_shader_parameter("watercolor", 0.32)
	terrain.build(self, ground)
	builder = WorldBuilder.new(terrain, self)
	builder.build_roads(data["roads"], data["water"])
	builder.build_buildings(data["buildings"])
	builder.build_platforms(data.get("platforms", []))
	var free_spots: Array = [data["start"]]
	for st in data["stations"]:
		free_spots.append(st["pos"])
	var reserve: Array = free_spots.duplicate()
	for b in data["buildings"]:
		if b["id"] == "herrenhaus":
			var mz := -1e9
			var cx := 0.0
			for q in b["footprint"]:
				mz = maxf(mz, q[1])
				cx += q[0] / b["footprint"].size()
			reserve.append([cx, mz + 11.0, 18.0])
	for st in data["stations"]:
		if st["id"] == "platz":
			reserve.append([st["pos"][0] + 5.0, st["pos"][1] - 8.0, 14.0])
	var extra: Array = builder.infill_houses(data["roads"], data["buildings"], reserve)
	builder.build_buildings(extra)
	builder.build_trees(data["roads"], data["water"], data["buildings"] + extra, 90, 95.0, free_spots)
	for b in data["buildings"]:
		if b["id"] == "herrenhaus":
			builder.domaene(b, self)
	for st in data["stations"]:
		if st["id"] == "platz":
			builder.fountain(Vector2(st["pos"][0] + 5.0, st["pos"][1] - 8.0), self)
	builder.scatter_props(data["roads"], free_spots, 26)
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
	_spawn_passanten(14)
	_ui()
	_update_hud()
	_debug_args()

## Testhilfe: godot -- --at=kirche --shot=bild.png  (setzt die Figur an eine Station und speichert ein Bild)
func _debug_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			for s in builder.stations:
				if s.get_meta("station")["id"] == a.substr(5):
					player.global_position = s.global_position + Vector3(0, 0.5, 3)
					player.cam_pivot.global_position = player.global_position + Vector3(0, 2.2, 0)
		if a.begins_with("--pos="):
			var xz := a.substr(6).split(",")
			var px := float(xz[0])
			var pz := float(xz[1])
			player.global_position = Vector3(px, terrain.surface(px, pz) + 0.5, pz)
			player.cam_pivot.global_position = player.global_position + Vector3(0, 2.2, 0)
		if a == "--read":
			await get_tree().create_timer(0.5).timeout
			_interact()
		if a.begins_with("--yaw="):
			player.cam_yaw = deg_to_rad(float(a.substr(6)))
		if a.begins_with("--shot="):
			var path := a.substr(7)
			await get_tree().create_timer(2.5).timeout
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#E9E3D4")
	sky_mat.sky_horizon_color = Color("#F6F2E8")
	sky_mat.ground_horizon_color = Color("#F6F2E8")
	sky_mat.ground_bottom_color = Color("#9DAE78")
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FAF9F6")
	env.ambient_light_energy = 0.3
	env.fog_enabled = false
	env.fog_light_color = Color("#E7E5DF")
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_color = Color("#FFE6BC")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

## Passanten auf den Gehwegen verteilen
func _spawn_passanten(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1120
	var roads: Array = data["roads"]
	for i in range(count):
		var r: Dictionary = roads[i % roads.size()]
		if r["points"].size() < 2:
			continue
		var p := Passant.new()
		p.name = "Passant_%d" % i
		add_child(p)
		p.setup(r, 1.0 if i % 2 == 0 else -1.0, builder, player, rng)
	# Plätze: gepflasterte Fläche und Leute, die dort ihre Runden drehen
	for st in data["stations"]:
		if not st["id"] in ["platz", "amt"]:
			continue
		var c := Vector2(st["pos"][0], st["pos"][1] - 8.0)
		var rad := 12.0 if st["id"] == "platz" else 8.0
		var pave := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = rad + 3.0
		cyl.bottom_radius = rad + 3.0
		cyl.height = 0.6
		cyl.radial_segments = 24
		pave.mesh = cyl
		pave.position = Vector3(c.x, terrain.surface(c.x, c.y) - 0.05, c.y)
		pave.material_override = builder.mat_ex(Color("#B4B2AA"), {"cobble": true}, false)
		add_child(pave)
		for k in range(3):
			var loop := []
			for a in range(9):
				var ang := TAU * a / 8.0 + k
				var r2 := rad * (0.45 + 0.25 * k)
				loop.append([c.x + cos(ang) * r2, c.y + sin(ang) * r2])
			var walker := Passant.new()
			add_child(walker)
			walker.setup({"points": loop, "width": 0.0}, 0.0, builder, player, rng)

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
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = F_TEXT
	ui.theme = th
	layer.add_child(ui)
	_ui_in(ui)

func _ui_in(layer: Control) -> void:
	inkwell = Inkwell.new()
	layer.add_child(inkwell)
	place = _label(layer, Vector2(24, 92), 26)
	place.add_theme_font_override("font", F_HEAD)
	place.text = data.get("name", "")
	hud = _label(layer, Vector2(24, 128), 17)
	hint = _label(layer, Vector2(16, 0), 20)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -262
	hint.offset_left = 24
	hint.visible = false
	dialog = PanelContainer.new()
	dialog.anchor_left = 0.5
	dialog.anchor_right = 0.5
	dialog.offset_left = -320
	dialog.offset_right = 320
	dialog.offset_top = 70
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FAF9F6")
	sb.border_color = Color("#1E1E1C")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(5)
	sb.shadow_color = Color(0.12, 0.12, 0.11, 0.35)
	sb.shadow_offset = Vector2(0, 6)
	sb.shadow_size = 4
	dialog.add_theme_stylebox_override("panel", sb)
	var inner := PanelContainer.new()
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color("#FAF9F6")
	sb2.border_color = Color("#1E1E1C")
	sb2.set_border_width_all(1)
	sb2.set_content_margin_all(16)
	inner.add_theme_stylebox_override("panel", sb2)
	dialog.add_child(inner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	inner.add_child(row)
	var deco := NotebookDeco.new()
	deco.custom_minimum_size = Vector2(56, 70)
	row.add_child(deco)
	dialog_text = RichTextLabel.new()
	dialog_text.add_theme_font_override("normal_font", F_TEXT)
	dialog_text.add_theme_font_override("bold_font", F_HEAD)
	dialog_text.add_theme_font_override("italics_font", F_TEXT)
	dialog_text.bbcode_enabled = true
	dialog_text.fit_content = true
	dialog_text.custom_minimum_size = Vector2(500, 0)
	dialog_text.add_theme_color_override("default_color", Color("#1E1E1C"))
	dialog_text.add_theme_font_size_override("normal_font_size", 20)
	dialog_text.add_theme_font_size_override("bold_font_size", 26)
	row.add_child(dialog_text)
	dialog.visible = false
	layer.add_child(dialog)
	joystick = Joystick.new()
	layer.add_child(joystick)
	var jump := _round_button("Hopp!", Color("#7A2B30"), Color("#FAF9F6"), 130)
	jump.offset_left = -154
	jump.offset_top = -154
	jump.offset_right = -24
	jump.offset_bottom = -24
	jump.button_down.connect(func(): player.request_jump())
	layer.add_child(jump)
	read_btn = _round_button("Lesen", Color("#FAF9F6"), Color("#1E1E1C"), 100)
	read_btn.offset_left = -270
	read_btn.offset_top = -124
	read_btn.offset_right = -170
	read_btn.offset_bottom = -24
	read_btn.visible = false
	read_btn.pressed.connect(_interact)
	layer.add_child(read_btn)

func _round_button(text: String, bg: Color, fg: Color, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", F_HEAD)
	b.add_theme_font_size_override("font_size", 28 if size > 110 else 22)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.darkened(0.15) if state == "pressed" else bg
		sb.border_color = Color("#1E1E1C")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(size)
		sb.shadow_color = Color(0.12, 0.12, 0.11, 0.5)
		sb.shadow_offset = Vector2(0, 5)
		b.add_theme_stylebox_override(state, sb)
	return b

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
	hud.text = "Federn %d / %d  ·  Geschichten %d / %d" % [feathers_got, builder.feathers.size(), found_pages.size(), builder.stations.size()]
	if inkwell:
		var total := builder.feathers.size() + builder.stations.size()
		inkwell.set_progress(float(feathers_got + found_pages.size()) / maxf(total, 1.0))

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
		hint.text = s.get_meta("station")["title"] + " – Enter / F / Lesen"
		hint.visible = true
		read_btn.visible = true

func _on_station_exit(body: Node, s: Area3D) -> void:
	if body == player and near_station == s:
		near_station = null
		hint.visible = false
		read_btn.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
	_touch(event)

func _interact() -> void:
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


## Touch: Joystick unten links, Wischen in der rechten Hälfte dreht die Kamera, Tippen auf die Blase blättert weiter
func _touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var w := get_viewport().get_visible_rect().size.x
		if event.pressed:
			if dialog.visible:
				_next_line()
			elif joy_index == -1 and joystick.hit(event.position):
				joy_index = event.index
				_joy(event.position)
			elif cam_index == -1 and event.position.x > w * 0.45:
				cam_index = event.index
		else:
			if event.index == joy_index:
				joy_index = -1
				joystick.set_knob(Vector2.ZERO)
				player.touch_move = Vector2.ZERO
			if event.index == cam_index:
				cam_index = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_index:
			_joy(event.position)
		elif event.index == cam_index:
			player.cam_yaw -= event.relative.x * 0.008

func _joy(pos: Vector2) -> void:
	var v := ((pos - joystick.center()) / joystick.radius()).limit_length(1.0)
	joystick.set_knob(v)
	player.touch_move = v

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
