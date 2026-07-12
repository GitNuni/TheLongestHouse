class_name ProcgenMain
extends Node3D
## Root of the procedural game scene. All the heavy lifting happens in the
## children (HouseGenerator builds the world in its own _ready); this script
## just introduces everyone to each other once they exist.

@onready var _generator: HouseGenerator = $Generator
@onready var _player: Player = $Player
@onready var _director: HauntDirector = $Director
@onready var _hud: BodycamHUD = $HUD
@onready var _world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	_player.spawn_point = _generator.player_spawn + Vector3(0, 0.1, 0)
	_player.global_position = _player.spawn_point
	_player.reset_physics_interpolation()
	_director.setup(_generator, _player, _world_environment.environment)
	_hud.attach(_player, _generator)
	# Dying anywhere (including inside the loop hall) respawns at the front
	# door — make sure the hall unlocks for the next visitor.
	_player.respawned.connect(_generator.release_loop)
