class_name FlickerLight
extends OmniLight3D
## A ceiling light that can misbehave.
##
## Flicker is driven by smooth noise rather than pure randomness so dips have
## a shape (a stutter, a brown-out, a recovery) instead of white-noise strobe.
## Each light gets its own noise seed so the hallway never flickers in unison.

## 0.0 = steady, 1.0 = barely holding on. Set by the Hallway escalation stages.
@export_range(0.0, 1.0) var flicker_amount := 0.0

var _base_energy: float
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_base_energy = light_energy
	_noise.seed = randi()


func _process(delta: float) -> void:
	if flicker_amount <= 0.0:
		light_energy = _base_energy
		return
	_time += delta
	# Noise in 0..1; when it dips below the cutoff the light browns out.
	# Higher flicker_amount raises the cutoff, so dips happen more often.
	var n := (_noise.get_noise_1d(_time * 40.0) + 1.0) * 0.5
	var cutoff := 0.2 + 0.4 * flicker_amount
	if n < cutoff:
		light_energy = _base_energy * n * 0.4
	else:
		light_energy = _base_energy


## The Hallway changes brightness per escalation stage through this instead of
## light_energy directly, because _process would overwrite light_energy on the
## next frame.
func set_base_energy(value: float) -> void:
	_base_energy = value
