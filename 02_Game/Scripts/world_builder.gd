class_name WorldBuilder
extends RefCounted
## Baut einen Ortsteil aus den Kartendaten (03_World/Geographic_Data/<ortsteil>.json):
## Straßen, Bäche, Gebäude als 3D-Körper, Plattformen, Stationen und Federn.
## Gezeichnete Fassaden: liegt unter 03_World/Buildings/<id>/fassade.png ein Bild,
## wird es automatisch auf die Wände des Gebäudes gelegt.

const TOON := preload("res://02_Game/Shaders/ink_toon.gdshader")
const OUTLINE := preload("res://02_Game/Shaders/ink_outline.gdshader")
const INK := Color("#1E1E1C")

var terrain: Terrain
var root: Node3D
var _mats := {}
var stations: Array[Area3D] = []
var _fachwerk: Texture2D = null
var feathers: Array[Area3D] = []

func _init(t: Terrain, parent: Node3D) -> void:
	terrain = t
	root = parent

## Tusche-Material mit Kontur, je Farbe nur einmal erzeugt.
func mat(color: Color, outline := true, tex: Texture2D = null) -> ShaderMaterial:
	var key := "%s|%s|%s" % [color.to_html(), outline, tex.get_instance_id() if tex else 0]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", color)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("use_texture", true)
	if outline:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("ink", INK)
		m.next_pass = o
	_mats[key] = m
	return m

## Dreieck so einfügen, dass die Vorderseite nach außen zeigt (Godot: Vorderseite im Uhrzeigersinn).
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, uv := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]) -> void:
	var n := (b - a).cross(c - a)
	var ua: Vector2 = uv[0]
	var ub: Vector2 = uv[1]
	var uc: Vector2 = uv[2]
	if n.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	var nn := outward.normalized()
	st.set_normal(nn); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(nn); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(nn); st.set_uv(uc); st.add_vertex(c)

## Variante des Tusche-Materials mit Zusatz-Parametern (Ziegelreihen, Gras)
func mat_ex(color: Color, params: Dictionary, outline := true) -> ShaderMaterial:
	var key := "ex|%s|%s|%s" % [color.to_html(), str(params), outline]
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = mat(color, false).duplicate()
	if outline:
		m.next_pass = mat(color, true).next_pass
	for k in params:
		m.set_shader_parameter(k, params[k])
	_mats[key] = m
	return m

var _window_tex: Texture2D = null
## Gezeichnetes Fenster: weißer Rahmen, Sprossenkreuz, blau-graues Glas mit Spiegelung
func window_texture() -> Texture2D:
	if _window_tex:
		return _window_tex
	var img := Image.create(64, 80, false, Image.FORMAT_RGB8)
	img.fill(Color("#1E1E1C"))
	img.fill_rect(Rect2i(3, 3, 58, 74), Color("#FAF9F6"))
	img.fill_rect(Rect2i(9, 9, 46, 62), Color("#8FA6B4"))
	img.fill_rect(Rect2i(9, 9, 46, 26), Color("#A9BCC6"))
	img.fill_rect(Rect2i(30, 9, 4, 62), Color("#FAF9F6"))
	img.fill_rect(Rect2i(9, 38, 46, 4), Color("#FAF9F6"))
	for k in range(10):
		img.set_pixel(13 + k, 13 + k, Color("#DCE6EA"))
		img.set_pixel(14 + k, 13 + k, Color("#DCE6EA"))
	img.fill_rect(Rect2i(0, 74, 64, 6), Color("#C9C3B5"))
	_window_tex = ImageTexture.create_from_image(img)
	return _window_tex

# ---------------------------------------------------------------- Straßen und Wasser
func _strip(points: Array, width: float, lift: float, color: Color, parent: Node3D, dash := false, material: Material = null) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	for i in range(points.size() - 1):
		var a := Vector2(points[i][0], points[i][1])
		var b := Vector2(points[i + 1][0], points[i + 1][1])
		var steps := maxi(1, int(a.distance_to(b) / 2.0))
		for s in range(steps):
			pts.append(a.lerp(b, float(s) / steps))
	pts.append(Vector2(points[-1][0], points[-1][1]))
	for i in range(pts.size() - 1):
		if dash and i % 3 != 0:
			continue
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x) * width * 0.5
		var q := [a + nrm, a - nrm, b - nrm, b + nrm]
		var v: Array[Vector3] = []
		for p in q:
			v.append(Vector3(p.x, terrain.surface(p.x, p.y) + lift, p.y))
		tri(st, v[0], v[1], v[2], Vector3.UP)
		tri(st, v[0], v[2], v[3], Vector3.UP)
	# runde Kappen an den Knicken
	if not dash:
		for p in pts:
			for k in range(8):
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				var y: float = terrain.surface(p.x, p.y) + lift - 0.005
				tri(st, Vector3(p.x, y, p.y), Vector3(p.x + cos(a1) * width * 0.5, y, p.y + sin(a1) * width * 0.5), Vector3(p.x + cos(a0) * width * 0.5, y, p.y + sin(a0) * width * 0.5), Vector3.UP)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material if material else mat(color, false)
	parent.add_child(mi)

func build_roads(roads: Array, water: Array) -> void:
	var node := Node3D.new()
	node.name = "Strassen"
	root.add_child(node)
	for w in water:
		_strip(w["points"], 3.6, 0.08, INK, node)
		_strip(w["points"], 2.8, 0.3, Color("#7E97A8"), node)
	for r in roads:
		var wd: float = r["width"]
		_strip(r["points"], wd + 1.6, 0.12, INK, node)
		_strip(r["points"], wd + 1.2, 0.3, Color("#E7E5DF"), node, false, mat_ex(Color("#C9C6BD"), {"cobble": true, "watercolor": 0.12}, false))  # Randsteine
		_strip(r["points"], wd, 0.5, Color("#9A9992"), node, false, mat_ex(Color("#A9A79F"), {"cobble": true}, false))  # Kopfsteinpflaster

# ---------------------------------------------------------------- Gebäude
## Gezeichnete Fachwerk-Textur (4 x 4 m je Kachel), bis echte Fassaden aus der Bildwerkstatt vorliegen.
func fachwerk_texture() -> Texture2D:
	if _fachwerk:
		return _fachwerk
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color("#F3EFE6"))
	var beam := Color("#1E1E1C")
	var line := func(a: Vector2, b: Vector2, w: int) -> void:
		var steps := int(a.distance_to(b))
		for s in range(steps + 1):
			var p := a.lerp(b, float(s) / maxf(steps, 1))
			for dx in range(-w, w + 1):
				for dy in range(-w, w + 1):
					var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
					if q.x >= 0 and q.y >= 0 and q.x < 256 and q.y < 256:
						img.set_pixelv(q, beam)
	for x in [0, 128, 255]:
		line.call(Vector2(x, 0), Vector2(x, 255), 5)
	for y in [0, 128, 255]:
		line.call(Vector2(0, y), Vector2(255, y), 5)
	line.call(Vector2(0, 128), Vector2(128, 0), 4)
	line.call(Vector2(255, 128), Vector2(128, 255), 4)
	line.call(Vector2(64, 0), Vector2(64, 128), 3)
	line.call(Vector2(192, 128), Vector2(192, 255), 3)
	_fachwerk = ImageTexture.create_from_image(img)
	return _fachwerk

func build_buildings(list: Array) -> void:
	var node := Node3D.new()
	node.name = "Gebaeude"
	root.add_child(node)
	for b in list:
		_building(b, node)

func _building(b: Dictionary, parent: Node3D) -> void:
	var fp: Array[Vector2] = []
	for p in b["footprint"]:
		fp.append(Vector2(p[0], p[1]))
	var base := 1e9
	for p in fp:
		base = minf(base, terrain.surface(p.x, p.y))
	base -= 0.6
	var h: float = b["height"] + 0.6
	var top := base + h
	var wall_c := Color(b.get("wall", "#EEE8DC"))
	var roof_c := Color(b.get("roof_color", "#7A2B30"))
	var tex: Texture2D = null
	var tex_path := "res://03_World/Buildings/%s/fassade.png" % b["id"]
	var world_uv := false
	if ResourceLoader.exists(tex_path):
		tex = load(tex_path)
	elif b.get("style", "") == "fachwerk":
		tex = fachwerk_texture()
		world_uv = true
	var body := StaticBody3D.new()
	body.name = b["id"]
	parent.add_child(body)
	# Wände
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cen := Vector2.ZERO
	for p in fp:
		cen += p
	cen /= fp.size()
	for i in range(fp.size()):
		var a := fp[i]
		var c := fp[(i + 1) % fp.size()]
		var mid := (a + c) * 0.5 - cen
		var out := Vector3(mid.x, 0, mid.y)
		var v := [Vector3(a.x, base, a.y), Vector3(c.x, base, c.y), Vector3(c.x, top, c.y), Vector3(a.x, top, a.y)]
		var u1 := a.distance_to(c) / 4.0 if world_uv else 1.0
		var v1 := h / 4.0 if world_uv else 1.0
		tri(st, v[0], v[1], v[2], out, [Vector2(0, v1), Vector2(u1, v1), Vector2(u1, 0)])
		tri(st, v[0], v[2], v[3], out, [Vector2(0, v1), Vector2(u1, 0), Vector2(0, 0)])
	var walls := MeshInstance3D.new()
	walls.mesh = st.commit()
	if b.get("style", "") == "masonry":
		walls.material_override = mat_ex(wall_c, {"masonry": true})
	else:
		walls.material_override = mat(wall_c if (tex == null or world_uv) else Color.WHITE, true, tex)
	body.add_child(walls)
	# Fenster (nur solange keine gezeichnete Fassade vorliegt)
	if tex == null or world_uv:
		_windows(fp, base + 0.6, top, body, b.get("landmark", false))
	if b.get("solar", false) and fp.size() == 4:
		_solar(fp, top, body)
	# Dach
	if fp.size() == 4:
		_roof(fp, top, b.get("roof", "gable"), roof_c, body)
	# Turm (z. B. Kirche)
	if b.get("tower") != null:
		_tower(fp, base, b["tower"], body)
	# Romanische Basilika: niedrige Seitenschiffe und runde Apsis im Osten (nach Luftbildern)
	if b["id"] == "kirche" and fp.size() == 4:
		_basilica(fp, base, h, body)
	# Kollision als gedrehter Quader
	if fp.size() == 4:
		var center := (fp[0] + fp[2]) * 0.5
		var ex := fp[0].distance_to(fp[1])
		var ez := fp[1].distance_to(fp[2])
		var ang := atan2(fp[1].y - fp[0].y, fp[1].x - fp[0].x)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(ex, h + 4.0, ez)
		cs.shape = box
		cs.position = Vector3(center.x, base + (h + 4.0) * 0.5, center.y)
		cs.rotation.y = -ang
		body.add_child(cs)

func _windows(fp: Array[Vector2], y0: float, top: float, parent: Node3D, landmark: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floors := maxi(1, int((top - y0) / 2.8))
	for i in range(fp.size()):
		var a := fp[i]
		var c := fp[(i + 1) % fp.size()]
		var len := a.distance_to(c)
		var dir := (c - a) / len
		var out := Vector2(dir.y, -dir.x)
		var count := int(len / 3.2)
		for f in range(floors):
			var y := y0 + 0.9 + f * 2.8
			if y + 1.4 > top:
				continue
			for k in range(count):
				var t := (k + 0.5) / count * len
				var p := a + dir * t + out * 0.03
				var w := 1.1 if not landmark else 0.9
				var hh := 1.3 if not landmark else 2.0
				var q := [p - dir * w * 0.5, p + dir * w * 0.5]
				var v := [Vector3(q[0].x, y, q[0].y), Vector3(q[1].x, y, q[1].y), Vector3(q[1].x, y + hh, q[1].y), Vector3(q[0].x, y + hh, q[0].y)]
				tri(st, v[0], v[1], v[2], Vector3(out.x, 0, out.y), [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)])
				tri(st, v[0], v[2], v[3], Vector3(out.x, 0, out.y), [Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat(Color.WHITE, false, window_texture())
	parent.add_child(mi)

func _roof(fp: Array[Vector2], top: float, kind: String, color: Color, parent: Node3D) -> void:
	# Satteldach über der längeren Seite, Walmdach mit verkürztem First
	var l0 := fp[0].distance_to(fp[1])
	var l1 := fp[1].distance_to(fp[2])
	var o: Array[Vector2] = fp.duplicate()
	if l1 > l0:
		o = [fp[1], fp[2], fp[3], fp[0]] as Array[Vector2]
	var short := minf(l0, l1)
	var rh := short * 0.48
	var over := 0.5
	var m01: Vector2 = (o[0] + o[3]) * 0.5
	var m12: Vector2 = (o[1] + o[2]) * 0.5
	var along: Vector2 = (m12 - m01).normalized()
	var r0: Vector2 = m01 - along * over
	var r1: Vector2 = m12 + along * over
	if kind == "hip":
		r0 = m01 + along * short * 0.45
		r1 = m12 - along * short * 0.45
	var e: Array[Vector2] = []
	for p in o:
		var c: Vector2 = (o[0] + o[2]) * 0.5
		e.append(p + (p - c).normalized() * over)
	var A := Vector3(e[0].x, top, e[0].y)
	var B := Vector3(e[1].x, top, e[1].y)
	var C := Vector3(e[2].x, top, e[2].y)
	var D := Vector3(e[3].x, top, e[3].y)
	var R0 := Vector3(r0.x, top + rh, r0.y)
	var R1 := Vector3(r1.x, top + rh, r1.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid3 := (A + B + C + D) * 0.25
	for t3 in [[A, B, R1], [A, R1, R0], [C, D, R0], [C, R0, R1], [B, C, R1], [D, A, R0]]:
		var f: Vector3 = (t3[0] + t3[1] + t3[2]) / 3.0
		var out: Vector3 = (t3[1] - t3[0]).cross(t3[2] - t3[0])
		if out.dot(f - mid3) < 0.0:
			out = -out
		tri(st, t3[0], t3[1], t3[2], out)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat_ex(color, {"stripes": 0.42 if color.r > 0.5 else 0.6})
	parent.add_child(mi)

func _basilica(fp: Array[Vector2], base: float, h: float, parent: Node3D) -> void:
	var minx := 1e9
	var maxx := -1e9
	var minz := 1e9
	var maxz := -1e9
	for p in fp:
		minx = minf(minx, p.x); maxx = maxf(maxx, p.x); minz = minf(minz, p.y); maxz = maxf(maxz, p.y)
	var len := maxx - minx
	var stone := mat_ex(Color("#6B6A65"), {"masonry": true})
	var slate := mat_ex(Color("#3A3B40"), {"stripes": 0.5})
	for side in [-1.0, 1.0]:
		var zc: float = (minz + maxz) * 0.5 + side * ((maxz - minz) * 0.5 + 1.6)
		var aisle := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(len * 0.8, h * 0.55, 3.2)
		aisle.mesh = bm
		aisle.position = Vector3((minx + maxx) * 0.5 + len * 0.05, base + h * 0.275, zc)
		aisle.material_override = stone
		parent.add_child(aisle)
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.left_to_right = 1.0 if side > 0 else 0.0
		pm.size = Vector3(3.8, 1.8, len * 0.82)
		roof.mesh = pm
		roof.rotation.y = PI / 2.0
		roof.position = Vector3(aisle.position.x, base + h * 0.55 + 0.9, zc)
		roof.material_override = slate
		parent.add_child(roof)
	var apse := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = (maxz - minz) * 0.36
	cm.bottom_radius = cm.top_radius
	cm.height = h * 0.7
	apse.mesh = cm
	apse.position = Vector3(maxx, base + cm.height * 0.5, (minz + maxz) * 0.5)
	apse.material_override = stone
	parent.add_child(apse)
	var cone := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.0
	cc.bottom_radius = cm.top_radius + 0.4
	cc.height = 2.6
	cone.mesh = cc
	cone.position = apse.position + Vector3(0, cm.height * 0.5 + 1.3, 0)
	cone.material_override = slate
	parent.add_child(cone)

func _solar(fp: Array[Vector2], top: float, parent: Node3D) -> void:
	var c := (fp[0] + fp[2]) * 0.5
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(fp[0].distance_to(fp[1]) * 0.55, 0.12, fp[1].distance_to(fp[2]) * 0.3)
	mi.mesh = bm
	mi.position = Vector3(c.x, top + 1.6, c.y)
	mi.rotation.y = -atan2(fp[1].y - fp[0].y, fp[1].x - fp[0].x)
	mi.material_override = mat(Color("#2B3550"), true)
	parent.add_child(mi)

func _tower(fp: Array[Vector2], base: float, t: Dictionary, parent: Node3D) -> void:
	var c := (fp[0] + fp[2]) * 0.5
	var w: float = t.get("w", 7.0)
	var hh: float = t.get("h", 22.0)
	var minx := 1e9
	for p in fp:
		minx = minf(minx, p.x)
	var pos := Vector2(minx - w * 0.3, c.y) if t.get("side", "west") == "west" else c
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, hh, w)
	box.mesh = bm
	box.position = Vector3(pos.x, base + hh * 0.5, pos.y)
	box.material_override = mat_ex(Color("#6B6A65"), {"masonry": true})
	parent.add_child(box)
	var spire := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = w * 0.78
	cm.height = w * 1.3
	cm.radial_segments = 4
	spire.mesh = cm
	spire.position = Vector3(pos.x, base + hh + cm.height * 0.5, pos.y)
	spire.rotation.y = PI / 4.0
	spire.material_override = mat_ex(Color("#33343A"), {"stripes": 0.5})
	parent.add_child(spire)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, hh, w)
	cs.shape = shape
	cs.position = box.position
	parent.add_child(cs)

# ---------------------------------------------------------------- Plattformen
func build_platforms(list: Array) -> void:
	for p in list:
		var c := Vector2(p["center"][0], p["center"][1])
		var size := Vector2(p["size"][0], p["size"][1])
		var h: float = p["height"]
		var g: float = terrain.surface(c.x, c.y)
		var body := StaticBody3D.new()
		body.name = p["name"]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x, h + 1.0, size.y)
		mi.mesh = bm
		mi.material_override = mat(Color("#C9C6BD"), true)
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bm.size
		cs.shape = shape
		body.add_child(cs)
		body.position = Vector3(c.x, g + h * 0.5 - 0.5, c.y)
		root.add_child(body)

# ---------------------------------------------------------------- Bäume und Büsche
func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func build_trees(roads: Array, water: Array, buildings: Array, count: int, area := 95.0, keep_free: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var segs: Array = []
	for r in roads + water:
		var pts: Array = r["points"]
		for i in range(pts.size() - 1):
			segs.append([Vector2(pts[i][0], pts[i][1]), Vector2(pts[i + 1][0], pts[i + 1][1]), r.get("width", 3.0) * 0.5 + 2.5])
	var centers: Array[Vector2] = []
	for b in buildings:
		var c := Vector2.ZERO
		for p in b["footprint"]:
			c += Vector2(p[0], p[1])
		centers.append(c / b["footprint"].size())
	var node := Node3D.new()
	node.name = "Baeume"
	root.add_child(node)
	var greens := ["#4F7D52", "#2E6B3E", "#6E8F5E", "#5E8A4A"]
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 30:
		tries += 1
		var p := Vector2(rng.randf_range(-area, area), rng.randf_range(-area * 1.4, area * 1.4))
		var ok := true
		for s in segs:
			if _dist_seg(p, s[0], s[1]) < s[2]:
				ok = false
				break
		if ok:
			for f in keep_free:
				if p.distance_to(Vector2(f[0], f[1])) < 13.0:
					ok = false
		if ok:
			for c in centers:
				if p.distance_to(c) < 8.0:
					ok = false
					break
		if not ok:
			continue
		placed += 1
		var y := terrain.surface(p.x, p.y)
		var big := rng.randf() < 0.7
		var s := rng.randf_range(0.8, 1.35)
		var tree := StaticBody3D.new()
		tree.position = Vector3(p.x, y, p.y)
		node.add_child(tree)
		var green: String = greens[rng.randi() % greens.size()]
		if big:
			var trunk := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.18 * s
			cm.bottom_radius = 0.28 * s
			cm.height = 3.0 * s
			trunk.mesh = cm
			trunk.position.y = 1.5 * s
			trunk.material_override = mat(Color("#6E4A33"), true)
			tree.add_child(trunk)
			for k in range(4):
				var blob := MeshInstance3D.new()
				var sm := SphereMesh.new()
				var r := rng.randf_range(1.2, 1.9) * s
				sm.radius = r
				sm.height = r * 1.8
				sm.radial_segments = 10
				sm.rings = 6
				blob.mesh = sm
				blob.position = Vector3(rng.randf_range(-1, 1) * s, (3.4 + rng.randf_range(0, 1.6)) * s, rng.randf_range(-1, 1) * s)
				blob.material_override = mat(Color(green), true)
				tree.add_child(blob)
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.35 * s
			cyl.height = 3.0 * s
			cs.shape = cyl
			cs.position.y = 1.5 * s
			tree.add_child(cs)
		else:
			for k in range(3):
				var blob := MeshInstance3D.new()
				var sm := SphereMesh.new()
				var r := rng.randf_range(0.55, 0.9) * s
				sm.radius = r
				sm.height = r * 1.6
				sm.radial_segments = 8
				sm.rings = 5
				blob.mesh = sm
				blob.position = Vector3(k * 0.7 * s - 0.7 * s, r * 0.6, rng.randf_range(-0.3, 0.3))
				blob.material_override = mat(Color(green), true)
				tree.add_child(blob)

# ---------------------------------------------------------------- Requisiten im Tusche-Stil
func _solid(mesh: Mesh, color: Color, pos: Vector3, parent: Node3D, shape: Shape3D = null, rot := 0.0, m: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = rot
	mi.material_override = m if m else mat(color, true)
	parent.add_child(mi)
	if shape:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation.y = rot
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)
	return mi

func barrel(p: Vector3, parent: Node3D) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.38
	cm.bottom_radius = 0.38
	cm.height = 0.95
	cm.radial_segments = 12
	var sh := CylinderShape3D.new()
	sh.radius = 0.4
	sh.height = 0.95
	_solid(cm, Color("#8A6446"), p + Vector3(0, 0.475, 0), parent, sh)
	for y in [0.2, 0.75]:
		var band := CylinderMesh.new()
		band.top_radius = 0.4
		band.bottom_radius = 0.4
		band.height = 0.06
		band.radial_segments = 12
		_solid(band, Color("#1E1E1C"), p + Vector3(0, y, 0), parent)

func crate(p: Vector3, parent: Node3D, size := 0.8, rot := 0.0) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size, size)
	var sh := BoxShape3D.new()
	sh.size = bm.size
	_solid(bm, Color("#A07A52"), p + Vector3(0, size * 0.5, 0), parent, sh, rot, mat_ex(Color("#A07A52"), {"stripes": size / 3.0}))

func cart(p: Vector3, rot: float, parent: Node3D) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = rot
	parent.add_child(n)
	var bed := BoxMesh.new()
	bed.size = Vector3(1.2, 0.5, 2.0)
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.2, 1.1, 2.0)
	_solid(bed, Color("#8A6446"), Vector3(0, 0.85, 0), n, sh, 0.0, mat_ex(Color("#8A6446"), {"stripes": 0.18}))
	for side in [-0.68, 0.68]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.55
		wheel.bottom_radius = 0.55
		wheel.height = 0.1
		wheel.radial_segments = 14
		var w := _solid(wheel, Color("#6E4A33"), Vector3(side, 0.55, -0.2), n)
		w.rotation.z = PI / 2.0
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.08, 0.08, 1.6)
	var s1 := _solid(shaft, Color("#6E4A33"), Vector3(-0.35, 0.55, 1.6), n)
	s1.rotation.x = 0.35
	var s2 := _solid(shaft, Color("#6E4A33"), Vector3(0.35, 0.55, 1.6), n)
	s2.rotation.x = 0.35

func fountain(c: Vector2, parent: Node3D) -> void:
	var y := terrain.surface(c.x, c.y)
	var basin := CylinderMesh.new()
	basin.top_radius = 2.0
	basin.bottom_radius = 2.1
	basin.height = 0.8
	basin.radial_segments = 8
	var sh := CylinderShape3D.new()
	sh.radius = 2.1
	sh.height = 0.8
	_solid(basin, Color("#9A9992"), Vector3(c.x, y + 0.4, c.y), parent, sh, 0.0, mat_ex(Color("#9A9992"), {"masonry": true}))
	var water := CylinderMesh.new()
	water.top_radius = 1.75
	water.bottom_radius = 1.75
	water.height = 0.05
	water.radial_segments = 8
	_solid(water, Color("#7E97A8"), Vector3(c.x, y + 0.79, c.y), parent, null, 0.0, mat(Color("#7E97A8"), false))
	var col := CylinderMesh.new()
	col.top_radius = 0.22
	col.bottom_radius = 0.3
	col.height = 1.8
	col.radial_segments = 8
	var csh := CylinderShape3D.new()
	csh.radius = 0.3
	csh.height = 1.8
	_solid(col, Color("#9A9992"), Vector3(c.x, y + 1.3, c.y), parent, csh)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.6
	bowl.bottom_radius = 0.25
	bowl.height = 0.3
	bowl.radial_segments = 8
	_solid(bowl, Color("#9A9992"), Vector3(c.x, y + 2.25, c.y), parent)

## Domänenhof: gepflasterter Hof mit ovaler Raseninsel und Freitreppe vor dem Haupthaus
func domaene(house: Dictionary, parent: Node3D) -> void:
	var fp: Array = house["footprint"]
	var c := Vector2.ZERO
	var maxz := -1e9
	for p in fp:
		c += Vector2(p[0], p[1])
		maxz = maxf(maxz, p[1])
	c /= fp.size()
	var court := Vector2(c.x, maxz + 11.0)
	var y := -1e9
	for k in range(24):
		var ang := TAU * k / 24.0
		for rr in [0.0, 6.0, 12.0]:
			y = maxf(y, terrain.surface(court.x + cos(ang) * rr * 1.3, court.y + sin(ang) * rr * 0.85))
	y += 0.15
	var pave := CylinderMesh.new()
	pave.top_radius = 13.0
	pave.bottom_radius = 13.6
	pave.height = 3.0
	pave.radial_segments = 32
	var pm := _solid(pave, Color("#9A9992"), Vector3(court.x, y - 1.45, court.y), parent, null, 0.0, mat_ex(Color("#A9A79F"), {"cobble": true}, false))
	pm.scale = Vector3(1.3, 1, 0.85)
	pm.create_trimesh_collision()
	var lawn := CylinderMesh.new()
	lawn.top_radius = 6.0
	lawn.bottom_radius = 6.0
	lawn.height = 0.35
	lawn.radial_segments = 32
	var lm := _solid(lawn, Color("#2E6B3E"), Vector3(court.x, y + 0.08, court.y + 1.5), parent, null, 0.0, mat_ex(Color("#3E7A46"), {"grass": true}))
	lm.scale = Vector3(1.35, 1, 0.8)
	lm.create_trimesh_collision()
	var edge := CylinderMesh.new()
	edge.top_radius = 6.25
	edge.bottom_radius = 6.25
	edge.height = 0.25
	edge.radial_segments = 32
	var em := _solid(edge, Color("#E7E5DF"), Vector3(court.x, y + 0.02, court.y + 1.5), parent, null, 0.0, mat(Color("#E7E5DF"), true))
	em.scale = Vector3(1.35, 1, 0.8)
	# Freitreppe
	var base := terrain.surface(c.x, maxz)
	for i in range(4):
		var step := BoxMesh.new()
		step.size = Vector3(3.2 - i * 0.2, 0.35, 0.6)
		var sh := BoxShape3D.new()
		sh.size = step.size
		_solid(step, Color("#9A9992"), Vector3(c.x, base - 0.4 + 0.35 * i + 0.175, maxz + 2.0 - i * 0.55), parent, sh, 0.0, mat_ex(Color("#9A9992"), {"masonry": true}))
	var roof := PrismMesh.new()
	roof.size = Vector3(3.4, 0.9, 1.6)
	_solid(roof, Color("#7A2B30"), Vector3(c.x, base + 3.4, maxz + 0.6), parent, null, 0.0, mat_ex(Color("#7A2B30"), {"stripes": 0.3}))
	# Fässer und Kisten im Hof
	for k in range(3):
		barrel(Vector3(c.x + 4.0 + k * 0.85, base - 0.3, maxz + 1.3), parent)
	crate(Vector3(c.x - 4.2, base - 0.3, maxz + 1.4), parent)
	crate(Vector3(c.x - 5.1, base - 0.3, maxz + 1.6), parent, 0.8, 0.3)
	crate(Vector3(c.x - 4.6, base + 0.5, maxz + 1.5), parent, 0.7, 0.6)

## Requisiten an den Hauswänden entlang der Straßen verteilen
func scatter_props(roads: Array, keep_free: Array, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var node := Node3D.new()
	node.name = "Requisiten"
	root.add_child(node)
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 20:
		tries += 1
		var r: Dictionary = roads[rng.randi() % roads.size()]
		var pts: Array = r["points"]
		var i := rng.randi() % (pts.size() - 1)
		var a := Vector2(pts[i][0], pts[i][1])
		var b := Vector2(pts[i + 1][0], pts[i + 1][1])
		var d := (b - a).normalized()
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p: Vector2 = a.lerp(b, rng.randf()) + Vector2(-d.y, d.x) * side * (float(r["width"]) * 0.5 + 1.6)
		var ok := true
		for f in keep_free:
			if p.distance_to(Vector2(f[0], f[1])) < 7.0:
				ok = false
		if not ok:
			continue
		placed += 1
		var y := terrain.surface(p.x, p.y)
		var kind := rng.randi() % 4
		if kind == 0:
			cart(Vector3(p.x, y, p.y), atan2(d.x, d.y) + rng.randf_range(-0.4, 0.4), node)
		elif kind == 1:
			barrel(Vector3(p.x, y, p.y), node)
			barrel(Vector3(p.x + d.x * 0.85, y, p.y + d.y * 0.85), node)
		else:
			crate(Vector3(p.x, y, p.y), node, 0.8, rng.randf())
			if rng.randf() < 0.6:
				crate(Vector3(p.x + d.x * 0.9, y, p.y + d.y * 0.9), node, 0.8, rng.randf())
			if rng.randf() < 0.4:
				crate(Vector3(p.x, y + 0.8, p.y), node, 0.7, rng.randf())

# ---------------------------------------------------------------- Stationen und Federn
func build_stations(list: Array) -> void:
	for s in list:
		var p := Vector2(s["pos"][0], s["pos"][1])
		var area := Area3D.new()
		area.name = "Station_" + s["id"]
		area.position = Vector3(p.x, terrain.surface(p.x, p.y), p.y)
		area.set_meta("station", s)
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 5.0
		cs.shape = sph
		area.add_child(cs)
		var mark := Label3D.new()
		mark.name = "Marker"
		mark.text = "!"
		mark.font_size = 180
		mark.outline_size = 36
		mark.modulate = Color("#7A2B30")
		mark.outline_modulate = Color("#FAF9F6")
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.position = Vector3(0, 3.4, 0)
		area.add_child(mark)
		root.add_child(area)
		stations.append(area)

func build_feathers(roads: Array, platforms: Array) -> void:
	var spots: Array[Vector3] = []
	for r in roads.slice(0, 6):
		var pts: Array = r["points"]
		for i in range(0, pts.size() - 1, 2):
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var m := a.lerp(b, 0.5)
			spots.append(Vector3(m.x, terrain.surface(m.x, m.y) + 1.0, m.y))
	for p in platforms:
		var c := Vector2(p["center"][0], p["center"][1])
		for k in range(5):
			var x: float = c.x - p["size"][0] * 0.4 + k * p["size"][0] * 0.2
			spots.append(Vector3(x, terrain.surface(c.x, c.y) + p["height"] + 1.0, c.y))
	for s in spots:
		var area := Area3D.new()
		area.name = "Feder"
		area.position = s
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.8
		cs.shape = sph
		area.add_child(cs)
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.45, 1.1, 0.12)
		mi.mesh = pm
		mi.rotation.z = 0.4
		mi.material_override = mat(Color("#C9A24A"), true)
		area.add_child(mi)
		root.add_child(area)
		feathers.append(area)
