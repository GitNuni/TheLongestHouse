class_name AtmosphereController
extends WorldEnvironment
## Thickens the dread as the player goes deeper into the house — a taste of
## the GDD's "Escalating Manifestation" pillar, expressed directly through
## fog/ambient/color instead of scripted events. Depth is approximated as
## how far past the front door the player has walked in -Z, since this
## house's rooms currently run in a single line deeper into the ground.
##
## This is a simplification for the exploration demo, not the real
## Milestone 4 system: it reacts to the player's *position*, not elapsed
## real time, so backing off toward the entrance calms things back down
## instead of the dread being persistent for the run.

@export var player_path: NodePath
## World Z at the front door — depth is how far past this the player has
## gone (in -Z), so it reads as 0 right at the start.
@export var origin_z := 2.0
## Depth, in meters past origin_z, at which the atmosphere hits its worst.
## Retune this against the house's actual length as rooms get added.
@export var max_depth := 46.0

@export var min_fog_density := 0.075
@export var max_fog_density := 0.16
@export var min_ambient_energy := 0.07
@export var max_ambient_energy := 0.015
@export var min_saturation := 0.72
@export var max_saturation := 0.4

var _player: Node3D


func _ready() -> void:
	_player = get_node(player_path)


func _process(_delta: float) -> void:
	if _player == null or environment == null or max_depth <= 0.0:
		return
	var depth := clampf(origin_z - _player.global_position.z, 0.0, max_depth)
	var t := depth / max_depth

	environment.fog_density = lerpf(min_fog_density, max_fog_density, t)
	environment.volumetric_fog_density = environment.fog_density * 0.6
	environment.ambient_light_energy = lerpf(min_ambient_energy, max_ambient_energy, t)
	environment.adjustment_saturation = lerpf(min_saturation, max_saturation, t)
