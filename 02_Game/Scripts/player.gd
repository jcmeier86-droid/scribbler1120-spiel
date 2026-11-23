class_name Player
extends CharacterBody3D
## Der Schreiberling: freie 360°-Bewegung relativ zur Kamera, Springen, Kamera über der Schulter.
## Liegt unter 01_Character/Schreiberling/Export/schreiberling.glb ein animiertes 3D-Modell,
## wird es automatisch statt des gezeichneten Platzhalters verwendet
## (erwartete Animationen: "Idle", "Walk", "Jump" – z. B. aus Mixamo).

const MODEL_PATH := "res://01_Character/Schreiberling/Export/schreiberling.glb"
const SPRITE_PATH := "res://01_Character/Schreiberling/Reference/rueckansicht_freigestellt.png"

@export var speed := 6.5
@export var accel := 14.0
@export var jump_velocity := 9.0
@export var gravity := 24.0
@export var cam_distance := 11.0
@export var cam_pitch_deg := -24.0

var touch_move := Vector2.ZERO        # von der Touch-Steuerung gesetzt
var input_locked := false
var cam_yaw := 0.0
var _jump_request := false
var _visual: Node3D
var _sprite: Sprite3D
var _anim: AnimationPlayer
var _walk_t := 0.0
var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_setup_visual()
	_setup_camera()

func _setup_visual() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var scene: PackedScene = load(MODEL_PATH)
		_visual = scene.instantiate()
		add_child(_visual)
		_anim = _visual.find_child("AnimationPlayer", true, false)
	else:
		# Platzhalter: freigestellte Rückansicht aus dem Charakterbogen
		_sprite = Sprite3D.new()
		_sprite.texture = load(SPRITE_PATH)
		_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_sprite.pixel_size = 1.95 / float(_sprite.texture.get_height())
		_sprite.position.y = 0.975
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_sprite.shaded = false
		add_child(_sprite)
		_visual = _sprite

func _setup_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.name = "KameraDrehpunkt"
	cam_pivot.top_level = true
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = cam_distance
	spring.margin = 0.3
	spring.rotation.x = deg_to_rad(cam_pitch_deg)
	spring.add_excluded_object(get_rid())
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 44.0
	camera.far = 900.0
	camera.near = 0.3
	camera.current = true
	spring.add_child(camera)
	cam_pivot.global_position = global_position + Vector3(0, 2.2, 0)

func request_jump() -> void:
	_jump_request = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam_yaw -= event.relative.x * 0.006
	# Mausrad: Zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring.spring_length = clampf(spring.spring_length - 0.8, 3.5, 18.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring.spring_length = clampf(spring.spring_length + 0.8, 3.5, 18.0)

func _physics_process(delta: float) -> void:
	cam_yaw += (Input.get_action_strength("cam_left") - Input.get_action_strength("cam_right")) * 2.2 * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length() > 0.05:
		input = touch_move.limit_length(1.0)
	if input_locked:
		input = Vector2.ZERO
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw)
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	if (_jump_request or Input.is_action_just_pressed("jump")) and is_on_floor() and not input_locked:
		velocity.y = jump_velocity
	_jump_request = false
	move_and_slide()
	_animate(delta, dir)
	# Kamera folgt weich
	cam_pivot.global_position = cam_pivot.global_position.lerp(global_position + Vector3(0, 2.2, 0), minf(1.0, delta * 8.0))
	cam_pivot.rotation.y = lerp_angle(cam_pivot.rotation.y, cam_yaw, minf(1.0, delta * 6.0))

func _animate(delta: float, dir: Vector3) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	if _sprite:
		# Platzhalter: Wippen beim Gehen, Hochziehen beim Sprung
		if moving and is_on_floor():
			_walk_t += delta * 11.0
		_sprite.position.y = 0.975 + (absf(sin(_walk_t)) * 0.06 if moving and is_on_floor() else 0.0)
		_sprite.rotation.z = sin(_walk_t) * 0.04 if moving else 0.0
	elif _visual:
		if dir.length() > 0.1:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 10.0))
		if _anim:
			var want := "Jump" if not is_on_floor() else ("Walk" if moving else "Idle")
			if _anim.has_animation(want) and _anim.current_animation != want:
				_anim.play(want, 0.2)
