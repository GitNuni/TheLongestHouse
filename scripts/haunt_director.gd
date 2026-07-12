class_name HauntDirector
extends Node
## The conductor of dread. Nothing in the house is haunted on its own — this
## node decides when the house misbehaves, how badly, and whether anything
## actually follows through.
##
## Two principles drive the design (borrowed from the horror games that do
## this best):
##
## 1. ESCALATION IS A ONE-WAY CLOCK. The house gets worse with time, not
##    with player mistakes. You cannot play well enough to keep it calm —
##    and logging evidence (your job!) actively angers it.
##
## 2. MOST EVENTS ARE BLUFFS. A knock with nothing behind it. A swell of
##    sound that resolves into silence. Real threats (ghost spawns,
##    possession) are rare, so the player's fear does the heavy lifting.
##    Dread lives in the gap between signal and consequence.

const POSSESSION_DURATION := 5.0

var escalation := 0.0
## Seconds to reach full escalation (10 minutes, per the GDD's 10–20 minute
## run target).
var full_escalation_seconds := 600.0

var _generator: HouseBase
var _player: Player
var _environment: Environment
var _event_timer := 0.0
var _active_ghosts := 0
var _drone: AudioStreamPlayer
var _heartbeat: AudioStreamPlayer
var _whisper: AudioStreamPlayer
var _swell: AudioStreamPlayer
var _base_fog := 0.045
var _base_saturation := 0.82
var _silenced := false
var _rng := RandomNumberGenerator.new()


func setup(generator: HouseBase, player: Player, environment: Environment) -> void:
	_generator = generator
	_player = player
	_environment = environment
	# Read the scene's authored mood as the calm baseline; escalation
	# darkens from wherever the artist set it, not from hardcoded values.
	if environment != null:
		_base_fog = environment.fog_density
		_base_saturation = environment.adjustment_saturation
	_rng.randomize()

	_drone = _make_player(AudioBank.room_drone, -18.0, true)
	_heartbeat = _make_player(AudioBank.heartbeat, -60.0, true)
	_whisper = _make_player(AudioBank.whisper, -60.0, true)
	_swell = _make_player(AudioBank.dread_swell, -10.0, false)
	_event_timer = 12.0

	generator.evidence_logged.connect(_on_evidence_logged)


func _make_player(stream: AudioStream, volume_db: float, autoplay: bool) -> AudioStreamPlayer:
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	add_child(audio_player)
	if autoplay:
		audio_player.play()
	return audio_player


func _process(delta: float) -> void:
	if _generator == null or _player == null:
		return
	escalation = clampf(escalation + delta / full_escalation_seconds, 0.0, 1.0)

	_update_ambience(delta)
	_update_heartbeat()

	_event_timer -= delta
	if _event_timer <= 0.0:
		_roll_event()
		# Events come faster as the house wakes up: ~45 s apart early,
		# ~9 s at full escalation.
		_event_timer = lerpf(45.0, 9.0, escalation) * _rng.randf_range(0.7, 1.3)


func _update_ambience(delta: float) -> void:
	if _silenced:
		return
	# The drone thickens with escalation; fog closes in — but stays "moody",
	# never pitch black. The worst it gets is about double the calm baseline.
	_drone.volume_db = lerpf(-18.0, -9.0, escalation)
	if _environment != null:
		var target_fog := lerpf(_base_fog, _base_fog * 2.0, escalation)
		_environment.fog_density = lerpf(_environment.fog_density, target_fog, delta * 0.2)
		_environment.adjustment_saturation = lerpf(_base_saturation,
				_base_saturation * 0.72, escalation)


func _update_heartbeat() -> void:
	# The heartbeat isn't yours. It rises when a ghost is near, wherever the
	# ghost is hiding.
	var nearest := INF
	for ghost in get_tree().get_nodes_in_group("ghosts"):
		var g := ghost as Node3D
		nearest = minf(nearest, g.global_position.distance_to(_player.global_position))
	if nearest < 12.0:
		_heartbeat.volume_db = lerpf(-8.0, -26.0, nearest / 12.0)
		_heartbeat.pitch_scale = lerpf(1.25, 1.0, nearest / 12.0)
	else:
		_heartbeat.volume_db = -60.0


func _on_evidence_logged(count: int, total: int) -> void:
	# Doing your job provokes the house: instant escalation bump plus an
	# immediate reaction beat a few seconds later.
	escalation = clampf(escalation + 0.06, 0.0, 1.0)
	_event_timer = minf(_event_timer, _rng.randf_range(2.0, 5.0))
	if count >= total:
		# All evidence logged — the scaffold's win state, for now. The house
		# does not congratulate you.
		escalation = 1.0


func _roll_event() -> void:
	# Weighted grab-bag. Bluffs outnumber threats roughly 3:1 on purpose.
	var roll := _rng.randf()
	if roll < 0.22:
		_event_knock()
	elif roll < 0.38:
		_event_flicker_surge()
	elif roll < 0.52:
		_event_door_slam()
	elif roll < 0.64:
		_event_whisper()
	elif roll < 0.74:
		_event_silence_drop()
	elif roll < 0.82:
		_event_swell_bluff()
	elif roll < 0.90 + 0.08 * escalation:
		_event_ghost()
	elif escalation > 0.45:
		_event_blackout_and_possession()
	else:
		_event_knock()


## A knock from a specific direction, 8–16 m away, through at least one wall.
## Nothing is there. Nothing is ever there. Until it is.
func _event_knock() -> void:
	var pos := _generator.random_corridor_position_near(
			_player.global_position, 8.0, 16.0)
	var speaker := BuildUtil.speaker(_generator, pos + Vector3(0, 1.5, 0),
			AudioBank.knock, -2.0, 30.0)
	speaker.pitch_scale = _rng.randf_range(0.7, 1.1)
	speaker.play()
	speaker.finished.connect(speaker.queue_free)


func _event_flicker_surge() -> void:
	for node in get_tree().get_nodes_in_group("haunt_lights"):
		var light := node as FlickerLight
		if light == null:
			continue
		var light_3d := node as Node3D
		if light_3d.global_position.distance_to(_player.global_position) < 18.0:
			light.flicker_amount = clampf(light.flicker_amount + 0.5, 0.0, 1.0)
			get_tree().create_timer(_rng.randf_range(2.0, 4.0)).timeout.connect(
					func() -> void:
						if is_instance_valid(light):
							light.flicker_amount = maxf(0.0, light.flicker_amount - 0.5))


func _event_door_slam() -> void:
	var best: HauntedDoor = null
	var best_distance := 20.0
	for node in get_tree().get_nodes_in_group("doors"):
		var door := node as HauntedDoor
		if door == null or not door.is_open():
			continue
		var d := door.global_position.distance_to(_player.global_position)
		if d < best_distance:
			best_distance = d
			best = door
	if best != null:
		best.slam()


func _event_whisper() -> void:
	# Fades in over your shoulder, holds, evaporates.
	_whisper.volume_db = -60.0
	_whisper.play()
	var tween := create_tween()
	tween.tween_property(_whisper, "volume_db", lerpf(-30.0, -18.0, escalation), 2.5)
	tween.tween_interval(_rng.randf_range(3.0, 7.0))
	tween.tween_property(_whisper, "volume_db", -60.0, 1.5)
	tween.tween_callback(_whisper.stop)


## The cruellest trick in the kit: kill ALL ambient sound for a few seconds.
## Players report silence in horror games as louder than any scream — the
## brain flags the missing room tone as "something is about to happen."
## Usually, nothing does. One knock, at most.
func _event_silence_drop() -> void:
	_silenced = true
	var tween := create_tween()
	tween.tween_property(_drone, "volume_db", -60.0, 0.4)
	tween.tween_interval(_rng.randf_range(4.0, 7.0))
	tween.tween_callback(func() -> void:
		if _rng.randf() < 0.5:
			_event_knock())
	tween.tween_interval(1.5)
	tween.tween_property(_drone, "volume_db", lerpf(-18.0, -9.0, escalation), 3.0)
	tween.tween_callback(func() -> void: _silenced = false)


## Sound builds like something is coming... and resolves to nothing at all.
func _event_swell_bluff() -> void:
	_swell.play()


func _event_ghost() -> void:
	if _active_ghosts >= 2:
		_event_knock()
		return
	var ghost := Ghost.new()
	ghost.player = _player
	# Early ghosts wander on private errands; late ghosts hunt.
	ghost.mode = Ghost.Mode.STALKER if _rng.randf() < escalation else Ghost.Mode.WANDERER
	ghost.position = _generator.random_corridor_position_near(
			_player.global_position, 10.0, 22.0)
	ghost.add_to_group("ghosts")
	ghost.expired.connect(func(_g: Ghost) -> void: _active_ghosts -= 1)
	_generator.add_child(ghost)
	_active_ghosts += 1


## The heavyweight: local blackout, voices, and the player is not entirely
## their own for a few seconds.
func _event_blackout_and_possession() -> void:
	var affected: Array[FlickerLight] = []
	for node in get_tree().get_nodes_in_group("haunt_lights"):
		var light := node as FlickerLight
		if light == null:
			continue
		if (node as Node3D).global_position.distance_to(_player.global_position) < 22.0:
			light.forced_off = true
			affected.append(light)
	_player.possess(POSSESSION_DURATION)
	get_tree().create_timer(_rng.randf_range(4.0, 7.0)).timeout.connect(
			func() -> void:
				for light in affected:
					if is_instance_valid(light):
						light.forced_off = false)
