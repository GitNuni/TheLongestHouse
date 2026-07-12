class_name HauntedDoor
extends Node3D
## A hinged door that builds its own panel at runtime.
##
## Behavior is deliberately unsettling-by-default: doors creak themselves
## open as the player approaches (the house is inviting you in), and the
## HauntDirector can slam any open door shut behind you. The slam is an
## AnimatableBody3D swing, so it physically shoves the player if they're
## standing in the frame.
##
## Local frame: the hinge is this node's origin; the panel extends along +X
## when closed. angle 0 = closed, positive = open.

const PANEL_WIDTH := 0.85
const PANEL_HEIGHT := 1.95

var _hinge: Node3D
var _angle := 0.0
var _target_angle := 0.0
var _speed := 1.0
var _creak_player: AudioStreamPlayer3D
var _slam_player: AudioStreamPlayer3D
var _player_near := false


func _ready() -> void:
	_hinge = Node3D.new()
	add_child(_hinge)

	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	_hinge.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PANEL_WIDTH, PANEL_HEIGHT, 0.06)
	shape.shape = box
	shape.position = Vector3(PANEL_WIDTH / 2.0, PANEL_HEIGHT / 2.0, 0)
	body.add_child(shape)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(PANEL_WIDTH, PANEL_HEIGHT, 0.06)
	mesh.material = BuildUtil.material(Color(0.26, 0.2, 0.16))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(PANEL_WIDTH / 2.0, PANEL_HEIGHT / 2.0, 0)
	body.add_child(mi)

	var knob := MeshInstance3D.new()
	var knob_mesh := BoxMesh.new()
	knob_mesh.size = Vector3(0.06, 0.06, 0.1)
	knob_mesh.material = BuildUtil.material(Color(0.6, 0.58, 0.5), 0.3)
	knob.mesh = knob_mesh
	knob.position = Vector3(PANEL_WIDTH - 0.1, 1.0, 0)
	body.add_child(knob)

	_creak_player = BuildUtil.speaker(self, Vector3(0.4, 1.0, 0), AudioBank.creak, -8.0, 14.0)
	_slam_player = BuildUtil.speaker(self, Vector3(0.4, 1.0, 0), AudioBank.slam, 0.0, 30.0)

	BuildUtil.trigger(self, Vector3(PANEL_WIDTH / 2.0, 1.2, 0), Vector3(3.5, 2.4, 3.5),
			_on_player_near)
	add_to_group("doors")


func _process(delta: float) -> void:
	if absf(_angle - _target_angle) < 0.01:
		return
	_angle = move_toward(_angle, _target_angle, _speed * delta)
	_hinge.rotation.y = _angle


func _on_player_near(_player: Node3D) -> void:
	if _player_near:
		return
	_player_near = true
	creak_open()


## The invitation: slow, loud, unprompted.
func creak_open() -> void:
	if _target_angle > 1.0:
		return
	_target_angle = randf_range(1.5, 1.9)
	_speed = 0.5
	_creak_player.pitch_scale = randf_range(0.85, 1.1)
	_creak_player.play()


## The punctuation mark. Called by the HauntDirector.
func slam() -> void:
	if _angle < 0.4:
		return
	_target_angle = 0.0
	_speed = 14.0
	_slam_player.play()


func is_open() -> bool:
	return _angle > 0.4
