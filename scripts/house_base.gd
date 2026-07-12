class_name HouseBase
extends Node3D
## Common contract every playable house implements — the procgen maze, the
## canonical ranch, and whatever comes later. The HauntDirector and HUD talk
## to this interface, never to a specific generator.

signal evidence_logged(count: int, total: int)

var player_spawn := Vector3.ZERO
var evidence_total := 0
var evidence_found := 0


## A position the director can use for spawns and positional sound events,
## `min_m`..`max_m` meters from `origin`.
func random_corridor_position_near(origin: Vector3, _min_m: float, _max_m: float) -> Vector3:
	return origin


## Unlock any one-occupant set-pieces (called on player respawn).
func release_loop() -> void:
	pass
