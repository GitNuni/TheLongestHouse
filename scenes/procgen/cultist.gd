class_name Cultist
extends CharacterBody3D
## A human threat — fightable, killable, per the GDD's Condemned-style
## combat. Robed figure that patrols the maze via grid pathfinding (the
## house generator hands each cultist its cell-level A* navigator), chases
## on line of sight, and swings a knife with a readable windup.
##
## Deliberately slightly SLOWER than the player's sprint: cultists menace
## by cornering you in the maze's dead ends, not by outrunning you.

signal died(cultist: Cultist)

enum State {PATROL, CHASE, WINDUP, DEAD}

const PATROL_SPEED := 1.6
const CHASE_SPEED := 3.4
const ATTACK_RANGE := 1.7
const WINDUP_SECONDS := 0.65
const ATTACK_DAMAGE := 25
const SIGHT_RANGE := 14.0

var max_health := 70
var health := 70
var player: Player
## Callable(from_world: Vector3, to_world: Vector3) -> PackedVector3Array
## provided by the HouseGenerator; returns world-space waypoints.
var find_path: Callable

var _state := State.PATROL
var _waypoints: PackedVector3Array = []
var _waypoint_index := 0
var _repath_timer := 0.0
var _sight_timer := 0.0
var _windup_timer := 0.0
var _sway_time := 0.0
var _body_root: Node3D
var _eyes_material: StandardMaterial3D
var _grunt: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	collision_layer = 1
	collision_mask = 1

	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7
	capsule.shape = shape
	capsule.position = Vector3(0, 0.85, 0)
	add_child(capsule)

	_body_root = Node3D.new()
	add_child(_body_root)
	var robe := BuildUtil.material(Color(0.16, 0.07, 0.08), 1.0)
	BuildUtil.box(_body_root, Vector3(0, 0.8, 0), Vector3(0.5, 1.6, 0.38), robe)
	BuildUtil.box(_body_root, Vector3(0, 1.72, 0), Vector3(0.3, 0.32, 0.3), robe)
	BuildUtil.box(_body_root, Vector3(0.3, 1.05, -0.18), Vector3(0.08, 0.5, 0.08), robe)
	# The knife: small, grey, honest about its purpose.
	BuildUtil.box(_body_root, Vector3(0.3, 0.85, -0.32), Vector3(0.03, 0.05, 0.26),
			BuildUtil.material(Color(0.7, 0.72, 0.75), 0.2))
	_eyes_material = BuildUtil.material(
			Color(0.1, 0.05, 0.05), 1.0, Color(0.9, 0.6, 0.2), 0.0)
	BuildUtil.box(_body_root, Vector3(-0.06, 1.74, -0.14), Vector3(0.04, 0.03, 0.02),
			_eyes_material)
	BuildUtil.box(_body_root, Vector3(0.06, 1.74, -0.14), Vector3(0.04, 0.03, 0.02),
			_eyes_material)

	_grunt = BuildUtil.speaker(self, Vector3(0, 1.5, 0), AudioBank.knock, -6.0, 18.0)
	add_to_group("cultists")


func _physics_process(delta: float) -> void:
	if _state == State.DEAD or player == null:
		return
	if not is_on_floor():
		velocity.y -= 14.0 * delta

	match _state:
		State.PATROL:
			_walk_waypoints(PATROL_SPEED, delta)
			_sight_timer -= delta
			if _sight_timer <= 0.0:
				_sight_timer = 0.3
				if _can_see_player():
					_enter_chase()
		State.CHASE:
			_repath_timer -= delta
			if _repath_timer <= 0.0:
				_repath_timer = 0.7
				_set_path_to(player.global_position)
			_walk_waypoints(CHASE_SPEED, delta)
			var distance := global_position.distance_to(player.global_position)
			if distance < ATTACK_RANGE:
				_state = State.WINDUP
				_windup_timer = WINDUP_SECONDS
				velocity.x = 0.0
				velocity.z = 0.0
			elif distance > SIGHT_RANGE * 1.8:
				_state = State.PATROL
				_waypoints = []
		State.WINDUP:
			# The tell: it rears back. Readable, dodgeable, then it commits.
			_body_root.rotation.x = lerpf(_body_root.rotation.x, -0.35, 8.0 * delta)
			_windup_timer -= delta
			if _windup_timer <= 0.0:
				_body_root.rotation.x = 0.0
				if global_position.distance_to(player.global_position) < ATTACK_RANGE + 0.4:
					player.take_damage(ATTACK_DAMAGE)
				_grunt.pitch_scale = _rng.randf_range(0.5, 0.7)
				_grunt.play()
				_state = State.CHASE

	# Lurch: the walk should look wrong at a distance.
	if velocity.length() > 0.5:
		_sway_time += delta * velocity.length() * 1.4
		_body_root.rotation.z = sin(_sway_time) * 0.06
		var flat := Vector3(velocity.x, 0, velocity.z)
		if flat.length() > 0.3:
			var yaw := atan2(-flat.x, -flat.z)
			rotation.y = lerp_angle(rotation.y, yaw, 6.0 * delta)
	move_and_slide()


func take_damage(amount: int) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_grunt.pitch_scale = _rng.randf_range(0.8, 1.0)
	_grunt.play()
	if health <= 0:
		_die()
	elif _state == State.PATROL:
		# Getting shot is an excellent way to learn where the player is.
		_enter_chase()


func _die() -> void:
	_state = State.DEAD
	died.emit(self)
	collision_layer = 0
	velocity = Vector3.ZERO
	var fall := create_tween()
	fall.tween_property(_body_root, "rotation:x", -PI / 2.0, 0.4)
	fall.tween_interval(6.0)
	fall.tween_callback(queue_free)


func _enter_chase() -> void:
	_state = State.CHASE
	_repath_timer = 0.0
	_eyes_material.emission_energy_multiplier = 2.0


func _can_see_player() -> bool:
	var to_player := player.global_position - global_position
	if to_player.length() > SIGHT_RANGE:
		return false
	var from := global_position + Vector3(0, 1.6, 0)
	var to := player.global_position + Vector3(0, 1.4, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] is Player


func _set_path_to(target: Vector3) -> void:
	if find_path.is_valid():
		_waypoints = find_path.call(global_position, target)
		_waypoint_index = 0


func _walk_waypoints(speed: float, _delta: float) -> void:
	if _waypoint_index >= _waypoints.size():
		velocity.x = 0.0
		velocity.z = 0.0
		if _state == State.PATROL and find_path.is_valid():
			# Idle at a corner for a moment, then pick a new errand.
			if _rng.randf() < 0.02:
				_set_path_to(Vector3.ZERO)  # generator interprets ZERO as "random cell"
		return
	var target := _waypoints[_waypoint_index]
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length() < 0.4:
		_waypoint_index += 1
		return
	var dir := flat.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
