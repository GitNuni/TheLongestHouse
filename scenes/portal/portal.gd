class_name Portal
extends Node3D
## A one-way "magic window": renders a live view through to another part of
## the world, and teleports the player — with matching orientation — the
## instant they cross it. The visual and the physical teleport share the
## exact same coordinate-frame math (`_remap`), which is what makes the two
## agree: what you see through the portal is genuinely where you land.
##
## Setup: `Mouth`'s local -Z should point the direction the player is
## walking when they reach this portal (Godot's own forward convention).
## Point `other_mouth_path` at a Marker3D wherever this portal should open
## onto; that marker's local -Z should point the direction the player should
## be facing after arriving.
##
## How the live view works: the portal's SubViewport does NOT get its own
## World3D, so it renders the same scene (same geometry, same lights) as the
## main camera — just from a second camera we reposition every frame to
## "look out" from the other mouth as if the player were standing there.
##
## Known limitation: the render matches field of view but not the off-axis
## ("oblique frustum") projection real portal renderers use, so the live
## view won't pixel-perfectly window-align at extreme viewing angles — a
## fair trade for a first pass.

@export var other_mouth_path: NodePath
## Visual resolution of the portal window. Lower = cheaper, since this is a
## whole extra scene render happening every single frame.
@export var viewport_size := Vector2i(512, 288)
@export var surface_size := Vector2(0.9, 2.0)

var _other_mouth: Node3D

@onready var _mouth: Marker3D = $Mouth
@onready var _viewport: SubViewport = $Mouth/SubViewport
@onready var _viewport_camera: Camera3D = $Mouth/SubViewport/Camera3D
@onready var _surface: MeshInstance3D = $Mouth/Surface
@onready var _trigger: Area3D = $Mouth/Trigger


func _ready() -> void:
	_other_mouth = get_node(other_mouth_path)
	_trigger.body_entered.connect(_on_trigger_body_entered)
	_viewport.size = viewport_size

	# Built at runtime rather than authored in the .tscn so each Portal
	# instance always gets its own private mesh/material — if two portals
	# shared one, the second to load would steal the first one's window.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()

	var mesh := QuadMesh.new()
	mesh.size = surface_size
	mesh.material = material
	_surface.mesh = mesh


func _process(_delta: float) -> void:
	var main_camera := get_viewport().get_camera_3d()
	if main_camera == null:
		return
	_viewport_camera.global_transform = _remap(main_camera.global_transform)
	_viewport_camera.fov = main_camera.fov


func _on_trigger_body_entered(body: Node3D) -> void:
	if not (body is Player):
		return
	body.global_transform = _remap(body.global_transform)
	body.reset_physics_interpolation()


## Re-expresses a transform relative to this portal's mouth as the same
## relative transform from the other mouth — a pure coordinate-frame change,
## no artificial flip. That's what makes walking (or looking) straight
## through feel like a continuous hallway rather than a mirror.
func _remap(t: Transform3D) -> Transform3D:
	var local := _mouth.global_transform.affine_inverse() * t
	return _other_mouth.global_transform * local
