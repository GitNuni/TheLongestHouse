class_name BuildUtil
extends RefCounted
## Helpers for constructing geometry from code. The procedural house builds
## thousands of boxes; these keep that from being thousands of lines.
##
## MeshInstance3D + BoxMesh is used instead of CSG: CSG recomputes geometry
## and is meant for hand-prototyping, while plain meshes are cheap enough to
## spawn by the roomful at runtime.

const FLICKER_SCRIPT := preload("res://scenes/hallway/flicker_light.gd")


static func material(albedo: Color, rough := 0.9, emission := Color.BLACK,
		emission_energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = rough
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


## A visual box. Optionally solid (adds StaticBody3D + BoxShape3D).
## collision_layer 1 = world; other layers noted where used.
static func box(parent: Node3D, pos: Vector3, size: Vector3,
		mat: StandardMaterial3D, solid := false, layer := 1) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		mi.add_child(body)
	return mi


## An invisible trigger volume that reports player entry to `callable`.
static func trigger(parent: Node3D, pos: Vector3, size: Vector3,
		callable: Callable) -> Area3D:
	var area := Area3D.new()
	area.position = pos
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	area.add_child(shape)
	parent.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			callable.call(body))
	return area


## A positional sound source, ready to play() on demand.
static func speaker(parent: Node3D, pos: Vector3, stream: AudioStream,
		volume_db := 0.0, max_distance := 24.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = pos
	player.volume_db = volume_db
	player.max_distance = max_distance
	parent.add_child(player)
	return player


## A ceiling light with the house's standard misbehavior wiring.
## FlickerLight extends the abstract Light3D (so the same script also fits
## the player's SpotLight3D flashlight), which means it can't be .new()ed
## directly — instead we make a concrete OmniLight3D and graft the script on.
static func haunt_light(parent: Node3D, pos: Vector3, color: Color, energy: float,
		range_m: float, flicker: float, blackout_interval: float,
		shadows := true) -> FlickerLight:
	var node := OmniLight3D.new()
	node.set_script(FLICKER_SCRIPT)
	node.position = pos
	node.light_color = color
	node.light_energy = energy
	node.omni_range = range_m
	node.light_size = 0.06
	node.shadow_enabled = shadows
	node.distance_fade_enabled = true
	node.distance_fade_begin = 22.0
	node.distance_fade_length = 8.0
	node.distance_fade_shadow = 18.0
	var light := node as FlickerLight
	light.flicker_amount = flicker
	light.blackout_interval = blackout_interval
	light.add_to_group("haunt_lights")
	parent.add_child(light)
	return light
