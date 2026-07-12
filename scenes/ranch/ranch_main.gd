class_name RanchMain
extends Node3D
## Root of the True House scene — introduces the builder, player, director,
## and HUD to each other once they've all built themselves.

@onready var _house: HouseBase = $House
@onready var _player: Player = $Player
@onready var _director: HauntDirector = $Director
@onready var _hud: BodycamHUD = $HUD
@onready var _world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	_player.spawn_point = _house.player_spawn
	_player.global_position = _player.spawn_point
	_player.reset_physics_interpolation()
	_director.setup(_house, _player, _world_environment.environment)
	_hud.attach(_player, _house)
	_player.respawned.connect(_house.release_loop)
