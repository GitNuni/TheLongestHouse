class_name Player
extends CharacterBody3D
## First-person officer controller.
##
## Yaw (looking left/right) rotates the whole body so movement follows the
## view; pitch (looking up/down) rotates only the camera so the body stays
## upright. This split is the standard FPS pattern in Godot.

const WALK_SPEED := 3.0
const SPRINT_SPEED := 5.2
## How quickly we reach target speed, in m/s per second. Low-ish on purpose:
## a slight ramp-up reads as body weight, which suits the grounded tone.
const ACCELERATION := 14.0
const GRAVITY := 14.0
const MOUSE_SENSITIVITY := 0.0022

@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		# Clamp pitch short of straight up/down to avoid gimbal flip.
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("ui_cancel"):
		# Esc releases the mouse (useful in windowed mode); click recaptures.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# get_vector gives a normalized 2D direction from the four move actions;
	# multiplying by the body's basis turns "forward" into wherever we face.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)

	move_and_slide()
