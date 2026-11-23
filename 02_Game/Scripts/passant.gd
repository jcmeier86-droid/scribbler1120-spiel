class_name Passant
extends Node3D
## Passant: spaziert auf dem Gehweg einer Straße hin und her und grüßt den Schreiberling.
## Figur aus einfachen Formen im Tusche-Stil, bis gezeichnete Figuren aus der Bildwerkstatt vorliegen.

const GRUESSE := ["Hallo Schreiberling!", "Moin!", "Schönen Tag noch!", "Na, wieder unterwegs?", "Grüß dich!", "Was schreibst du heute?", "Schönes Wetter, oder?"]
const JACKEN := ["#2E6B3E", "#7A2B30", "#1A2E61", "#6B6A65", "#B9572F", "#4F7D52", "#3E4A5C"]
const HOSEN := ["#3E4A5C", "#2B2B30", "#55606E", "#6B5A48"]
const HAUT := ["#EFC3A0", "#E3AE8A", "#C98F6A", "#8E5E3B"]
const HAARE := ["#3B2A20", "#6B4A32", "#B8B0A0", "#1E1E1C", "#A0703A"]

var terrain: Terrain
var builder: WorldBuilder
var player: Node3D
var path: Array[Vector2] = []
var seg := 0
var t := 0.0
var dir := 1
var speed := 1.3
var walk := 0.0
var cooldown := 0.0
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var bubble: Label3D
var pause := 0.0

func setup(road: Dictionary, side: float, b: WorldBuilder, p: Node3D, rng: RandomNumberGenerator) -> void:
	builder = b
	terrain = b.terrain
	player = p
	speed = rng.randf_range(1.0, 1.6)
	# Gehweg: Straßenlinie seitlich versetzt
	var pts: Array = road["points"]
	var off: float = road["width"] * 0.5 + 1.0
	for i in range(pts.size()):
		var a := Vector2(pts[maxi(i - 1, 0)][0], pts[maxi(i - 1, 0)][1])
		var c := Vector2(pts[mini(i + 1, pts.size() - 1)][0], pts[mini(i + 1, pts.size() - 1)][1])
		var d := (c - a).normalized()
		path.append(Vector2(pts[i][0], pts[i][1]) + Vector2(-d.y, d.x) * off * side)
	seg = rng.randi_range(0, path.size() - 2)
	t = rng.randf()
	dir = 1 if rng.randf() < 0.5 else -1
	_build_body(rng)

func _part(mesh: Mesh, color: String, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = builder.mat(Color(color), true)
	parent.add_child(mi)
	return mi

func _limb(color: String, pivot: Vector3, length: float, radius: float) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	add_child(n)
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = length
	_part(c, color, Vector3(0, -length * 0.5, 0), n)
	return n

func _build_body(rng: RandomNumberGenerator) -> void:
	var jacke: String = JACKEN[rng.randi() % JACKEN.size()]
	var hose: String = HOSEN[rng.randi() % HOSEN.size()]
	var haut: String = HAUT[rng.randi() % HAUT.size()]
	var haar: String = HAARE[rng.randi() % HAARE.size()]
	var s := rng.randf_range(0.9, 1.05)
	scale = Vector3(s, s, s)
	leg_l = _limb(hose, Vector3(-0.12, 0.9, 0), 0.9, 0.09)
	leg_r = _limb(hose, Vector3(0.12, 0.9, 0), 0.9, 0.09)
	var torso := CapsuleMesh.new()
	torso.radius = 0.24
	torso.height = 0.8
	_part(torso, jacke, Vector3(0, 1.25, 0), self)
	arm_l = _limb(jacke, Vector3(-0.3, 1.52, 0), 0.62, 0.07)
	arm_r = _limb(jacke, Vector3(0.3, 1.52, 0), 0.62, 0.07)
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.4
	_part(head, haut, Vector3(0, 1.82, 0), self)
	var hair := SphereMesh.new()
	hair.radius = 0.2
	hair.height = 0.22
	hair.is_hemisphere = true
	_part(hair, haar, Vector3(0, 1.86, 0.02), self)
	if rng.randf() < 0.25:
		var tasche := BoxMesh.new()
		tasche.size = Vector3(0.12, 0.3, 0.35)
		_part(tasche, "#6E4A33", Vector3(0.36, 1.0, 0), self)
	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 48
	bubble.outline_size = 14
	bubble.modulate = Color("#1E1E1C")
	bubble.outline_modulate = Color("#FAF9F6")
	bubble.position = Vector3(0, 2.35, 0)
	bubble.visible = false
	add_child(bubble)

func _process(delta: float) -> void:
	if path.size() < 2:
		return
	cooldown = maxf(0.0, cooldown - delta)
	var near := player and global_position.distance_to(player.global_position) < 3.2
	if near and cooldown <= 0.0:
		bubble.text = GRUESSE[randi() % GRUESSE.size()]
		bubble.visible = true
		cooldown = 12.0
		pause = 2.5
	if bubble.visible and cooldown < 9.0:
		bubble.visible = false
	var moving := pause <= 0.0
	if not moving:
		pause -= delta
		if player:
			var to := player.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 6.0))
	else:
		var a := path[seg]
		var b := path[seg + 1]
		var len := maxf(a.distance_to(b), 0.01)
		t += dir * speed * delta / len
		if t > 1.0:
			if seg < path.size() - 2:
				seg += 1
				t = 0.0
			else:
				t = 1.0
				dir = -1
		elif t < 0.0:
			if seg > 0:
				seg -= 1
				t = 1.0
			else:
				t = 0.0
				dir = 1
		a = path[seg]
		b = path[seg + 1]
		var p := a.lerp(b, t)
		position = Vector3(p.x, terrain.surface(p.x, p.y) + 0.3, p.y)
		var d := (b - a) * dir
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.y), minf(1.0, delta * 5.0))
		walk += delta * speed * 4.0
	var sw := sin(walk) * 0.5 if moving else 0.0
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	arm_l.rotation.x = -sw * 0.8
	arm_r.rotation.x = sw * 0.8
