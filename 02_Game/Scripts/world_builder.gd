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
	var key := "%s|%s|%s" % [color.to_html(), outline, tex.resource_path if tex else ""]
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

# ---------------------------------------------------------------- Straßen und Wasser
func _strip(points: Array, width: float, lift: float, color: Color, parent: Node3D, dash := false) -> void:
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
	mi.material_override = mat(color, false)
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
		_strip(r["points"], wd + 2.4, 0.12, INK, node)
		_strip(r["points"], wd + 2.0, 0.3, Color("#D3CFC6"), node)   # Gehweg
		_strip(r["points"], wd, 0.5, Color("#8F8D87"), node)         # Asphalt
		if r.get("main", false):
			_strip(r["points"], 0.18, 0.62, Color("#F2F0EA"), node, true)

# ---------------------------------------------------------------- Gebäude
## Gezeichnete Fachwerk-Textur (4 x 4 m je Kachel), bis echte Fassaden aus der Bildwerkstatt vorliegen.
func fachwerk_texture() -> Texture2D:
	if _fachwerk:
		return _fachwerk
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color("#F3EFE6"))
	var beam := Color("#4E3424")
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
				tri(st, v[0], v[1], v[2], Vector3(out.x, 0, out.y))
				tri(st, v[0], v[2], v[3], Vector3(out.x, 0, out.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat(Color("#CBD5D8"), true)
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
	mi.material_override = mat(color, true)
	parent.add_child(mi)

func _basilica(fp: Array[Vector2], base: float, h: float, parent: Node3D) -> void:
	var minx := 1e9
	var maxx := -1e9
	var minz := 1e9
	var maxz := -1e9
	for p in fp:
		minx = minf(minx, p.x); maxx = maxf(maxx, p.x); minz = minf(minz, p.y); maxz = maxf(maxz, p.y)
	var len := maxx - minx
	var stone := mat(Color("#D9D2C2"), true)
	var slate := mat(Color("#5C5B57"), true)
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
	box.material_override = mat(Color("#E7E5DF"), true)
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
	spire.material_override = mat(Color("#5C5B57"), true)
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
