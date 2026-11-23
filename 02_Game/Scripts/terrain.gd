class_name Terrain
extends RefCounted
## Gelände für Adorf: Talkessel entlang Rhene und Bicke, Anstieg nach Nordosten und Süden.
## Solange keine echten Höhendaten importiert sind, wird die Höhe aus der Entfernung zu den
## Tallinien geschätzt (nach der Topo-Karte). Später ersetzt ein Höhenraster (SRTM/DGM) diese Funktion.

var valleys: Array[PackedVector2Array] = []
var heightmap: Image = null          # optional: echtes Höhenraster
var hm_origin := Vector2.ZERO
var hm_cell := 1.0
var _cache := {}
var _grid := PackedFloat32Array()
var _n := 0
var _step := 4.0
var _half := 300.0

func _init(water: Array, extra: Array) -> void:
	for w in water:
		valleys.append(_to_pts(w["points"]))
	for e in extra:
		valleys.append(_to_pts(e))

static func _to_pts(arr: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for q in arr:
		p.append(Vector2(q[0], q[1]))
	return p

func dist_valley(x: float, z: float) -> float:
	var best := 1e9
	var pt := Vector2(x, z)
	for line in valleys:
		for i in range(line.size() - 1):
			var a := line[i]
			var b := line[i + 1]
			var ab := b - a
			var t := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, pt.distance_to(a + ab * t))
	return best

func height(x: float, z: float) -> float:
	var key := Vector2i(roundi(x * 2.0), roundi(z * 2.0))
	if _cache.has(key):
		return _cache[key]
	var d := maxf(0.0, dist_valley(x, z) - 3.0)
	var s := 0.07 + 0.06 * clampf(x / 90.0, 0.0, 1.0) + 0.035 * clampf(-z / 140.0, 0.0, 1.0) + 0.03 * clampf(z / 140.0, 0.0, 1.0)
	var v := 34.0 * (1.0 - exp(-d * s / 34.0))
	if absf(x) > 100.0 or absf(z) > 155.0:
		v += minf(40.0, (maxf(0.0, absf(x) - 100.0) + maxf(0.0, absf(z) - 155.0)) * 0.18)
	_cache[key] = v
	return v

## Höhe genau auf der gebauten Geländeoberfläche (gleiche Dreiecke wie das Gitter),
## damit Straßen, Häuser und Figuren nicht einsinken oder schweben.
func surface(x: float, z: float) -> float:
	if _n == 0:
		return height(x, z)
	var gx := (x + _half) / _step
	var gz := (z + _half) / _step
	var ix := int(floor(gx))
	var iz := int(floor(gz))
	if ix < 0 or iz < 0 or ix >= _n - 1 or iz >= _n - 1:
		return height(x, z)
	var fx := gx - ix
	var fz := gz - iz
	var h00 := _grid[iz * _n + ix]
	var h10 := _grid[iz * _n + ix + 1]
	var h01 := _grid[(iz + 1) * _n + ix]
	var h11 := _grid[(iz + 1) * _n + ix + 1]
	if fx >= fz:
		return h00 + fx * (h10 - h00) + fz * (h11 - h10)
	return h00 + fz * (h01 - h00) + fx * (h11 - h01)

## Baut sichtbares Gelände und Kollision. size = Kantenlänge in Metern, step = Rasterweite.
func build(parent: Node3D, material: Material, size := 600.0, step := 4.0) -> void:
	var n := int(size / step) + 1
	var half := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for iz in range(n):
		for ix in range(n):
			hs[iz * n + ix] = height(-half + ix * step, -half + iz * step)
	_grid = hs
	_n = n
	_step = step
	_half = half
	for iz in range(n - 1):
		for ix in range(n - 1):
			var x0 := -half + ix * step
			var z0 := -half + iz * step
			var p00 := Vector3(x0, hs[iz * n + ix], z0)
			var p10 := Vector3(x0 + step, hs[iz * n + ix + 1], z0)
			var p01 := Vector3(x0, hs[(iz + 1) * n + ix], z0 + step)
			var p11 := Vector3(x0 + step, hs[(iz + 1) * n + ix + 1], z0 + step)
			for t in [[p00, p10, p11], [p00, p11, p01]]:
				var nrm: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
				if nrm.y < 0.0:
					nrm = -nrm
				WorldBuilder.tri(st, t[0], t[1], t[2], nrm, [Vector2(t[0].x, t[0].z) / 8.0, Vector2(t[1].x, t[1].z) / 8.0, Vector2(t[2].x, t[2].z) / 8.0])
	var mi := MeshInstance3D.new()
	mi.name = "Gelaende"
	mi.mesh = st.commit()
	mi.material_override = material
	parent.add_child(mi)
	# Kollision: HeightMapShape3D hat 1 m Raster, daher Höhen durch step teilen und gleichmäßig skalieren.
	var body := StaticBody3D.new()
	body.name = "GelaendeKollision"
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	var scaled := PackedFloat32Array()
	scaled.resize(n * n)
	for i in range(n * n):
		scaled[i] = hs[i] / step
	shape.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, step, step)
	body.add_child(cs)
	parent.add_child(body)
