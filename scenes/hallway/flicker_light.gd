class_name FlickerLight
extends Light3D
## A light that can misbehave. Extends Light3D (not OmniLight3D) so the same
## script works on ceiling fixtures (OmniLight3D), the player's flashlight
## (SpotLight3D), or anything else that's a light.
##
## Two layered effects, meant to be felt differently:
## - Continuous flicker: smooth per-light noise, so dips have a shape (a
##   stutter, a brown-out, a recovery) instead of a white-noise strobe. Each
##   light gets its own noise seed so a room never flickers in unison — it
##   reads as bad wiring, not a screen effect.
## - Blackout pulses: rarer, deeper, full dark-then-recover beats layered on
##   top, for punctuation. Continuous flicker alone reads as "old lightbulb";
##   adding occasional blackouts reads as "something is doing this on purpose."
##
## Set `inverted` for a light that should normally sit near-dark and only
## flare up occasionally — used for "something was just revealed for a
## second" beats rather than a light dying.

## 0.0 = perfectly steady, 1.0 = barely holding on.
@export_range(0.0, 1.0) var flicker_amount := 0.0
## How often, roughly, a full blackout pulse happens (average seconds).
## 0 disables blackout pulses entirely — continuous flicker only.
@export var blackout_interval := 9.0
## How long a blackout pulse lasts, in seconds.
@export var blackout_duration := 0.35
## Light color to bleed toward during a dip — a sickly counterpoint to the
## fixture's normal color. Keep desaturated; this is meant to read as
## "wrong," not as a color effect.
@export var distress_color := Color(0.75, 0.82, 0.7)
## When true, the light sits near-dark and briefly flares bright instead of
## sitting bright and dipping dark.
@export var inverted := false

## Hard override used by the HauntDirector for regional blackouts — while
## true the light is dead regardless of flicker state.
var forced_off := false

var _base_energy: float
var _base_color: Color
var _time := 0.0
var _next_blackout_at := 0.0
var _blackout_until := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_base_energy = light_energy
	_base_color = light_color
	_noise.seed = randi()
	_schedule_next_blackout()


func _process(delta: float) -> void:
	if forced_off:
		light_energy = 0.0
		return
	if flicker_amount <= 0.0:
		light_energy = _base_energy
		light_color = _base_color
		return

	_time += delta
	if _time >= _next_blackout_at:
		_blackout_until = _time + blackout_duration
		_schedule_next_blackout()

	if _time < _blackout_until:
		light_energy = _base_energy * 0.03
		light_color = _base_color.lerp(distress_color, 0.8)
		return

	# Noise in 0..1; when it dips below the cutoff the light dims. Higher
	# flicker_amount raises the cutoff, so dips happen more often.
	var n := (_noise.get_noise_1d(_time * 40.0) + 1.0) * 0.5
	var cutoff := 0.2 + 0.4 * flicker_amount
	if inverted:
		if n > 1.0 - cutoff:
			light_energy = _base_energy * n
			light_color = _base_color
		else:
			light_energy = 0.0
			light_color = _base_color
	elif n < cutoff:
		light_energy = _base_energy * n * 0.4
		light_color = _base_color.lerp(distress_color, 0.4)
	else:
		light_energy = _base_energy
		light_color = _base_color


func _schedule_next_blackout() -> void:
	if blackout_interval <= 0.0:
		_next_blackout_at = INF
		return
	# Randomized around the average interval so multiple lights in a room
	# never blackout in lockstep.
	_next_blackout_at = _time + blackout_interval * randf_range(0.6, 1.4)


## The room controller (e.g. Hallway) changes brightness per escalation
## stage through this instead of light_energy directly, because _process
## would overwrite light_energy on the next frame.
func set_base_energy(value: float) -> void:
	_base_energy = value


## Same reasoning as set_base_energy: _process drives light_color itself
## once flicker_amount > 0, so a direct assignment would be overwritten
## on the next frame.
func set_base_color(value: Color) -> void:
	_base_color = value
