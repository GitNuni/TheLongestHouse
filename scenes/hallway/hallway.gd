class_name Hallway
extends Node3D
## The endless hallway — Milestone 1's "bigger on the inside" proof.
##
## How the illusion works: the hallway is 12 identical 4 m segments (48 m).
## Two invisible triggers sit inside it. Crossing the deep one silently moves
## the player 16 m back toward the entrance; crossing the entrance-side one
## moves them 16 m deeper. Because every segment is identical, the jump lands
## in geometry that looks exactly like where the player just was — so the
## hallway never ends, in either direction. This is the P.T. trick in its
## simplest form.
##
## Each forward loop also advances an escalation stage: the lights get dimmer,
## colder, and less reliable. The house is reacting to how deep you are.

signal looped(count: int)

## Must be a whole number of segments (4 m each) or the teleport seam shows.
const LOOP_SHIFT := 16.0

## One entry per escalation stage; the last stage repeats forever after.
const STAGES: Array[Dictionary] = [
	{"flicker": 0.0, "energy": 1.2, "color": Color(1.0, 0.85, 0.65)},
	{"flicker": 0.15, "energy": 1.1, "color": Color(1.0, 0.85, 0.65)},
	{"flicker": 0.35, "energy": 0.9, "color": Color(1.0, 0.8, 0.6)},
	{"flicker": 0.6, "energy": 0.65, "color": Color(0.95, 0.82, 0.62)},
	{"flicker": 0.85, "energy": 0.45, "color": Color(0.78, 0.8, 0.68)},
]

var loop_count := 0


func _ready() -> void:
	_apply_stage(0)


func _on_deep_trigger_body_entered(body: Node3D) -> void:
	if body is Player:
		_shift_player(body, LOOP_SHIFT)
		loop_count += 1
		_apply_stage(mini(loop_count, STAGES.size() - 1))
		looped.emit(loop_count)


func _on_entrance_trigger_body_entered(body: Node3D) -> void:
	# Walking back toward the entrance also never ends — but retreating
	# doesn't escalate the house. Only going deeper does.
	if body is Player:
		_shift_player(body, -LOOP_SHIFT)


func _shift_player(player: Node3D, shift_z: float) -> void:
	player.global_position.z += shift_z
	# Physics interpolation smooths motion between physics ticks; without this
	# reset a teleport would render as a one-frame smear across 16 m.
	player.reset_physics_interpolation()


func _apply_stage(index: int) -> void:
	var stage := STAGES[index]
	for node in get_tree().get_nodes_in_group("hallway_lights"):
		var light := node as FlickerLight
		light.flicker_amount = stage["flicker"]
		light.set_base_energy(stage["energy"])
		light.light_color = stage["color"]
