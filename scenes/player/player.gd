class_name Player
extends CharacterBody3D
## First-person officer. Now a full survivor kit: revolver with scarce ammo,
## health, bodycam evidence tagging, head bob with synthesized footsteps,
## and a possession state the HauntDirector can inflict.
##
## Look: yaw rotates the body, pitch rotates only the camera — the standard
## Godot FPS split. Head bob and recoil are layered on the camera's local
## transform so they never contaminate the aim direction.

signal health_changed(value: int)
signal ammo_changed(loaded: int, reserve: int)
signal tag_progress_changed(progress: float)
signal possession_changed(active: bool)
signal static_flash
signal died
signal respawned

const WALK_SPEED := 3.0
const SPRINT_SPEED := 5.2
const ACCELERATION := 14.0
const GRAVITY := 14.0
const MOUSE_SENSITIVITY := 0.0022

const GUN_DAMAGE := 34
const CYLINDER_SIZE := 6
const TAG_RANGE := 3.5

var health := 100
var ammo_loaded := 6
var ammo_reserve := 12
var spawn_point := Vector3.ZERO

var _bob_time := 0.0
var _bob_was_high := false
var _recoil := 0.0
var _possessed_for := 0.0
var _dead := false
var _tagged_evidence: Evidence

var _footstep_player: AudioStreamPlayer
var _gunshot_player: AudioStreamPlayer
var _static_player: AudioStreamPlayer
var _voices_player: AudioStreamPlayer
var _blip_player: AudioStreamPlayer
var _muzzle_flash: OmniLight3D
var _rng := RandomNumberGenerator.new()

@onready var camera: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Flashlight


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_rng.randomize()
	add_to_group("player")

	_footstep_player = _make_audio(AudioBank.footstep, -14.0)
	_gunshot_player = _make_audio(AudioBank.gunshot, -2.0)
	_static_player = _make_audio(AudioBank.static_burst, -8.0)
	_voices_player = _make_audio(AudioBank.voices, -12.0)
	_blip_player = _make_audio(AudioBank.blip, -10.0)

	_build_viewmodel()


func _make_audio(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


## A revolver silhouette in the lower-right of view, plus the muzzle light.
func _build_viewmodel() -> void:
	var gun_root := Node3D.new()
	gun_root.name = "Gun"
	gun_root.position = Vector3(0.22, -0.18, -0.4)
	camera.add_child(gun_root)
	var steel := BuildUtil.material(Color(0.12, 0.12, 0.13), 0.35)
	var grip := BuildUtil.material(Color(0.25, 0.16, 0.1), 0.8)
	BuildUtil.box(gun_root, Vector3(0, 0.02, -0.1), Vector3(0.035, 0.05, 0.22), steel)
	BuildUtil.box(gun_root, Vector3(0, -0.05, 0.04), Vector3(0.032, 0.09, 0.05), grip)
	_muzzle_flash = OmniLight3D.new()
	_muzzle_flash.position = Vector3(0, 0.02, -0.25)
	_muzzle_flash.light_color = Color(1.0, 0.8, 0.4)
	_muzzle_flash.light_energy = 0.0
	_muzzle_flash.omni_range = 7.0
	_muzzle_flash.shadow_enabled = true
	gun_root.add_child(_muzzle_flash)


func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# The compiler still sees `event` as plain InputEvent here, so cast
		# before touching InputEventMouseMotion-only properties.
		var mouse := event as InputEventMouseMotion
		var motion := mouse.relative * MOUSE_SENSITIVITY
		if _possessed_for > 0.0:
			# The hands aren't fully yours: inverted, sluggish.
			motion *= -0.55
		rotate_y(-motion.x)
		camera.rotate_x(-motion.y)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)
	elif event.is_action_pressed("shoot"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_shoot()
	elif event.is_action_pressed("reload"):
		_reload()
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if _possessed_for > 0.0:
		speed *= 0.55

	velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
	move_and_slide()
	_update_bob(delta, speed)


func _process(delta: float) -> void:
	if _possessed_for > 0.0:
		_possessed_for -= delta
		# Slow involuntary head drift.
		camera.rotation.z = sin(Time.get_ticks_msec() / 300.0) * 0.05
		if _possessed_for <= 0.0:
			camera.rotation.z = 0.0
			_voices_player.stop()
			possession_changed.emit(false)
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	_update_tagging(delta)


func _update_bob(delta: float, speed: float) -> void:
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and ground_speed > 0.5:
		_bob_time += delta * ground_speed * 1.6
	var bob := sin(_bob_time)
	camera.position.y = 1.6 + bob * 0.035
	camera.position.x = cos(_bob_time * 0.5) * 0.02
	camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)
	camera.rotation.x += _recoil * delta * 10.0
	# Footstep on each downward crossing of the bob cycle.
	var is_high := bob > 0.0
	if _bob_was_high and not is_high and is_on_floor() and ground_speed > 0.5:
		_footstep_player.pitch_scale = _rng.randf_range(0.85, 1.15)
		_footstep_player.volume_db = -18.0 + (speed - WALK_SPEED)
		_footstep_player.play()
	_bob_was_high = is_high


## ----- Gun ------------------------------------------------------------------


func _shoot() -> void:
	if ammo_loaded <= 0:
		_blip_player.pitch_scale = 0.5
		_blip_player.play()
		return
	ammo_loaded -= 1
	ammo_changed.emit(ammo_loaded, ammo_reserve)
	_gunshot_player.pitch_scale = _rng.randf_range(0.95, 1.05)
	_gunshot_player.play()
	_recoil = 0.7
	_muzzle_flash.light_energy = 3.5
	get_tree().create_timer(0.06).timeout.connect(
			func() -> void: _muzzle_flash.light_energy = 0.0)

	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	# The cultist's capsule is the CharacterBody3D itself.
	if collider is Cultist:
		(collider as Cultist).take_damage(GUN_DAMAGE)


func _reload() -> void:
	if ammo_reserve <= 0 or ammo_loaded >= CYLINDER_SIZE:
		return
	var need := CYLINDER_SIZE - ammo_loaded
	var take := mini(need, ammo_reserve)
	ammo_loaded += take
	ammo_reserve -= take
	ammo_changed.emit(ammo_loaded, ammo_reserve)
	_blip_player.pitch_scale = 0.8
	_blip_player.play()


func add_ammo(amount: int) -> void:
	ammo_reserve += amount
	ammo_changed.emit(ammo_loaded, ammo_reserve)
	_blip_player.pitch_scale = 1.0
	_blip_player.play()


## ----- Evidence tagging ------------------------------------------------------


func _update_tagging(delta: float) -> void:
	var target := _tag_target()
	if target != null and Input.is_action_pressed("tag"):
		if _tagged_evidence != null and _tagged_evidence != target:
			_tagged_evidence.decay_tag(delta)
		_tagged_evidence = target
		var progress := target.advance_tag(delta)
		tag_progress_changed.emit(progress)
		if target.is_logged:
			_blip_player.pitch_scale = 1.2
			_blip_player.play()
			_tagged_evidence = null
			tag_progress_changed.emit(0.0)
	else:
		if _tagged_evidence != null:
			_tagged_evidence.decay_tag(delta)
			if _tagged_evidence.tag_progress <= 0.0:
				_tagged_evidence = null
		tag_progress_changed.emit(0.0)


## Whatever evidence sits under the camera center within range — mask 5 is
## world (1) + evidence (4), so walls still block the view.
func _tag_target() -> Evidence:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * TAG_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 5, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider: Object = hit["collider"]
	if collider is Node:
		var parent := (collider as Node).get_parent()
		if parent is Evidence:
			return parent as Evidence
	return null


## ----- Damage / possession / death -------------------------------------------


func take_damage(amount: int) -> void:
	if _dead:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health)
	_static_player.play()
	static_flash.emit()
	if health <= 0:
		_die()


func possess(duration: float) -> void:
	if _dead:
		return
	_possessed_for = duration
	_voices_player.play()
	possession_changed.emit(true)


## Bodycam glitch used by teleports — the camera "loses signal" for a frame.
func play_static_blip() -> void:
	_static_player.play()
	static_flash.emit()


func _die() -> void:
	_dead = true
	died.emit()
	velocity = Vector3.ZERO
	# SIGNAL LOST beat, then the next shift begins at the front door.
	get_tree().create_timer(3.0).timeout.connect(_respawn)


func _respawn() -> void:
	global_position = spawn_point
	reset_physics_interpolation()
	health = 100
	ammo_loaded = CYLINDER_SIZE
	ammo_reserve = maxi(6, ammo_reserve / 2)
	_possessed_for = 0.0
	_dead = false
	health_changed.emit(health)
	ammo_changed.emit(ammo_loaded, ammo_reserve)
	respawned.emit()
