class_name Ghost
extends Node3D
## An apparition. Unkillable, mostly unexplainable, and — per the GDD's
## "asymmetric horror, symmetric world" pillar — designed to be client-side:
## nothing here touches shared game state except through the HauntDirector,
## so in co-op each player can meet their own private ghost.
##
## Ghosts ignore walls entirely. This is not a shortcut, it's the point:
## watching a figure glide THROUGH a wall your own body respects is a
## violation of the house's one remaining rule.
##
## Modes:
## - WANDERER: drifts on its own errand, ignores you. Often scarier than the
##   stalker, because it implies the house has business that isn't you.
## - STALKER: approaches only while you are NOT looking at it. Staring at it
##   holds it still — and burning it away with sustained attention is the
##   only defense. Bullets pass through (the gun is for the living).

signal expired(ghost: Ghost)

enum Mode {WANDERER, STALKER}

const DRIFT_SPEED := 0.9
const STALK_SPEED := 1.45
const GAZE_DOT := 0.94
const GAZE_BURN_SECONDS := 1.6
const TOUCH_DISTANCE := 1.1

var mode := Mode.WANDERER
var player: Player

var _drift_target: Vector3
var _gaze_burn := 0.0
var _lifetime := 0.0
var _max_lifetime := 45.0
var _body_material: StandardMaterial3D
var _hum: AudioStreamPlayer3D
var _visible_flicker_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_body_material = BuildUtil.material(
			Color(0.85, 0.88, 0.95, 0.16), 1.0, Color(0.7, 0.8, 1.0), 0.35)
	_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# A tall veiled figure: narrow shoulders, no face, feet lost in the hem.
	BuildUtil.box(self, Vector3(0, 0.9, 0), Vector3(0.42, 1.8, 0.3), _body_material)
	BuildUtil.box(self, Vector3(0, 1.86, 0), Vector3(0.24, 0.34, 0.24), _body_material)
	BuildUtil.box(self, Vector3(0, 1.35, 0.05), Vector3(0.56, 0.5, 0.3), _body_material)

	_hum = BuildUtil.speaker(self, Vector3(0, 1.4, 0), AudioBank.ghost_hum, -14.0, 16.0)
	_hum.play()
	_pick_drift_target()


func _process(delta: float) -> void:
	if player == null:
		return
	_lifetime += delta
	if _lifetime > _max_lifetime:
		_vanish(false)
		return

	# Presence flicker: the ghost's visibility stutters like a bad signal.
	_visible_flicker_timer -= delta
	if _visible_flicker_timer <= 0.0:
		visible = _rng.randf() > 0.12
		_visible_flicker_timer = _rng.randf_range(0.06, 0.5)

	var to_player := player.global_position - global_position
	var distance := to_player.length()

	match mode:
		Mode.WANDERER:
			var step := (_drift_target - global_position)
			if step.length() < 0.5:
				_pick_drift_target()
			else:
				global_position += step.normalized() * DRIFT_SPEED * delta
			# Getting close to a wanderer dismisses it — with a jolt.
			if distance < TOUCH_DISTANCE + 0.6:
				_vanish(true)
		Mode.STALKER:
			var watched := _is_watched()
			if watched:
				_gaze_burn += delta
				if _gaze_burn >= GAZE_BURN_SECONDS:
					_vanish(true)
					return
			else:
				_gaze_burn = maxf(0.0, _gaze_burn - delta * 0.5)
				var flat := Vector3(to_player.x, 0, to_player.z).normalized()
				global_position += flat * STALK_SPEED * delta
			# Reaching the player is the ghost's win: possession.
			if distance < TOUCH_DISTANCE:
				player.possess(4.0)
				player.take_damage(15)
				_vanish(true)
				return
	# Face the player, always. Even the wanderer keeps its head turned.
	if distance > 0.5:
		look_at(Vector3(player.global_position.x, global_position.y,
				player.global_position.z), Vector3.UP)

	# The hum sharpens as it closes in; player hears their heartbeat rise via
	# the HauntDirector proximity check.
	_hum.pitch_scale = clampf(1.0 + (8.0 - distance) * 0.03, 1.0, 1.3)


## True while the player's camera is pointed at the ghost with clear line of
## sight. Uses layer-1 geometry only, so walls hide the ghost from the gaze
## check the same way they hide it from the eye.
func _is_watched() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var eye := camera.global_position
	var head := global_position + Vector3(0, 1.5, 0)
	var to_ghost := (head - eye)
	if to_ghost.length() > 26.0:
		return false
	var facing := -camera.global_transform.basis.z
	if facing.dot(to_ghost.normalized()) < GAZE_DOT:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, head, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _pick_drift_target() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var span := _rng.randf_range(6.0, 18.0)
	_drift_target = global_position + Vector3(cos(angle), 0, sin(angle)) * span


func _vanish(loud: bool) -> void:
	if loud:
		var burst := AudioStreamPlayer.new()
		burst.stream = AudioBank.static_burst
		burst.volume_db = -4.0
		# Parented to the tree root so the sound outlives this node.
		get_tree().root.add_child(burst)
		burst.play()
		burst.finished.connect(burst.queue_free)
	expired.emit(self)
	queue_free()
