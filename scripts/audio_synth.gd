class_name AudioSynth
extends RefCounted
## Synthesizes every sound in the game from raw math — no audio files.
## Each function fills a PCM buffer sample-by-sample and wraps it in an
## AudioStreamWAV. Generated once at load, then reused.
##
## The horror philosophy here: most of these sounds are for when NOTHING is
## happening. A room tone that is slightly too low. A knock from a corridor
## you already cleared. A heartbeat that is not yours. Silence used as a
## weapon (see HauntDirector.silence_drop). Loud sounds (gunshot, slam) exist
## so the quiet ones have something to be quieter than.

const MIX_RATE := 22050


static func _to_wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Short fade at both ends so loops and one-shots never click.
static func _fade_ends(samples: PackedFloat32Array, fade_seconds := 0.04) -> void:
	var n := mini(int(fade_seconds * MIX_RATE), samples.size() / 2)
	for i in n:
		var f := float(i) / float(n)
		samples[i] *= f
		samples[samples.size() - 1 - i] *= f


## Deep room tone: three detuned low sines with a slow breathing swell.
## Frequencies chosen with whole cycles over the loop so it loops seamlessly.
static func room_drone() -> AudioStreamWAV:
	var seconds := 8.0
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var swell := 0.6 + 0.4 * sin(TAU * t / seconds)
		var v := 0.5 * sin(TAU * 55.0 * t)
		v += 0.3 * sin(TAU * 82.5 * t)
		v += 0.25 * sin(TAU * 110.25 * t + 1.7)
		samples[i] = v * 0.22 * swell
	return _to_wav(samples, true)


## Two dissonant tones a rough minor second apart — the beating between them
## is physically unsettling. Used as the ghost's presence hum.
static func ghost_hum() -> AudioStreamWAV:
	var seconds := 6.0
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var v := 0.5 * sin(TAU * 220.0 * t) + 0.5 * sin(TAU * 233.0 * t)
		v += 0.2 * sin(TAU * 110.0 * t)
		samples[i] = v * 0.14
	return _to_wav(samples, true)


## Lub-dub. Played when something unseen is close, at a rate slightly faster
## than a calm human heart, so the player's own pulse tries to match it.
static func heartbeat() -> AudioStreamWAV:
	var seconds := 0.95
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var v := 0.0
		for beat_start: float in [0.0, 0.22]:
			if t >= beat_start:
				var bt := t - beat_start
				v += sin(TAU * 52.0 * bt) * exp(-bt * 28.0)
		samples[i] = v * 0.8
	_fade_ends(samples, 0.01)
	return _to_wav(samples, true)


## Filtered noise with a slowly wandering amplitude — reads as wind through
## a place that should not have wind.
static func wind() -> AudioStreamWAV:
	var seconds := 9.0
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 133742
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		# One-pole lowpass over white noise = brown-ish rumble.
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		var gust := 0.55 + 0.45 * sin(TAU * t / seconds) * sin(TAU * 3.0 * t / seconds + 1.3)
		samples[i] = lp * gust * 0.5
	_fade_ends(samples)
	return _to_wav(samples, true)


## Two dry knocks against wood, from inside a wall. Vary pitch_scale on the
## player for variety.
static func knock() -> AudioStreamWAV:
	var seconds := 0.75
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	for i in n:
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k_start: float in [0.0, 0.28]:
			if t >= k_start:
				var kt := t - k_start
				v += sin(TAU * 95.0 * kt) * exp(-kt * 40.0)
				v += rng.randf_range(-1.0, 1.0) * exp(-kt * 90.0) * 0.4
		samples[i] = v * 0.7
	_fade_ends(samples, 0.01)
	return _to_wav(samples, false)


## A door slamming: sharp noise attack over a heavy low body, with a small
## secondary rattle as the frame settles.
static func slam() -> AudioStreamWAV:
	var seconds := 0.9
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in n:
		var t := float(i) / MIX_RATE
		var v := sin(TAU * 48.0 * t) * exp(-t * 14.0) * 1.1
		v += rng.randf_range(-1.0, 1.0) * exp(-t * 55.0) * 0.9
		if t >= 0.16:
			var rt := t - 0.16
			v += rng.randf_range(-1.0, 1.0) * exp(-rt * 120.0) * 0.25
		samples[i] = v * 0.85
	_fade_ends(samples, 0.01)
	return _to_wav(samples, false)


## Revolver shot: brutal noise transient, low pressure thump, short ring.
static func gunshot() -> AudioStreamWAV:
	var seconds := 0.7
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in n:
		var t := float(i) / MIX_RATE
		var v := rng.randf_range(-1.0, 1.0) * exp(-t * 40.0) * 1.4
		v += sin(TAU * 60.0 * t) * exp(-t * 12.0) * 0.9
		v += sin(TAU * 1150.0 * t) * exp(-t * 30.0) * 0.12
		samples[i] = clampf(v, -1.0, 1.0) * 0.95
	_fade_ends(samples, 0.005)
	return _to_wav(samples, false)


## Breath-like modulated noise. Quiet. Meant to sit at the edge of hearing,
## where the player cannot decide if it is the ventilation or a voice.
static func whisper() -> AudioStreamWAV:
	var seconds := 6.0
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var lp := 0.0
	var syllable := 0.0
	var syllable_target := 0.0
	var syllable_timer := 0
	for i in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var hp := rng.randf_range(-1.0, 1.0) - lp
		syllable_timer -= 1
		if syllable_timer <= 0:
			syllable_timer = rng.randi_range(900, 3200)
			syllable_target = rng.randf_range(0.05, 1.0)
		syllable = lerpf(syllable, syllable_target, 0.002)
		samples[i] = hp * syllable * 0.16
	_fade_ends(samples)
	return _to_wav(samples, true)


## Many whisper layers at once, pitched apart — the possession chorus.
static func voices() -> AudioStreamWAV:
	var seconds := 5.0
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 66666
	var lps := [0.0, 0.0, 0.0]
	var rates := [0.18, 0.32, 0.5]
	for i in n:
		var t := float(i) / MIX_RATE
		var v := 0.0
		for layer in 3:
			lps[layer] += (rng.randf_range(-1.0, 1.0) - lps[layer]) * rates[layer]
			var mod := 0.5 + 0.5 * sin(TAU * (0.7 + layer * 0.43) * t + layer * 2.1)
			v += (rng.randf_range(-1.0, 1.0) - lps[layer]) * mod * 0.14
		v += sin(TAU * 66.0 * t) * 0.1
		samples[i] = v
	_fade_ends(samples)
	return _to_wav(samples, true)


## Harsh broadband interference — the bodycam objecting to something it saw.
static func static_burst() -> AudioStreamWAV:
	var seconds := 0.45
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12321
	for i in n:
		var t := float(i) / MIX_RATE
		var gate := 1.0 if fmod(t * 31.0, 1.0) > 0.2 else 0.35
		samples[i] = rng.randf_range(-1.0, 1.0) * gate * exp(-t * 4.0) * 0.5
	_fade_ends(samples, 0.01)
	return _to_wav(samples, false)


## Long tortured hinge creak: a slowly falling tone with vibrato and grit.
static func creak() -> AudioStreamWAV:
	var seconds := 1.6
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var freq := lerpf(340.0, 170.0, t / seconds)
		freq *= 1.0 + 0.06 * sin(TAU * 7.0 * t) + rng.randf_range(-0.02, 0.02)
		phase += TAU * freq / MIX_RATE
		var body := sin(phase) * 0.5 + sin(phase * 2.01) * 0.2
		var stick_slip := 0.7 + 0.3 * sin(TAU * 13.0 * t + sin(TAU * 2.0 * t) * 3.0)
		samples[i] = body * stick_slip * 0.22
	_fade_ends(samples)
	return _to_wav(samples, false)


## Soft footstep thud; vary pitch_scale per step.
static func footstep() -> AudioStreamWAV:
	var seconds := 0.14
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for i in n:
		var t := float(i) / MIX_RATE
		var v := sin(TAU * 70.0 * t) * exp(-t * 60.0)
		v += rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.3
		samples[i] = v * 0.5
	_fade_ends(samples, 0.005)
	return _to_wav(samples, false)


## Small confirmation blip for pickups/logging — deliberately mundane and
## radio-like, because the bodycam is the one normal thing the player has.
static func blip() -> AudioStreamWAV:
	var seconds := 0.18
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var f := 880.0 if t < 0.09 else 1174.0
		samples[i] = sin(TAU * f * t) * 0.25 * exp(-t * 8.0)
	_fade_ends(samples, 0.008)
	return _to_wav(samples, false)


## Night insects for the indoor forest: chirp trains you can hear clearly
## and will never, ever see. Several offset trains so it reads as a
## population, not a loop.
static func crickets() -> AudioStreamWAV:
	var seconds := 7.0
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24601
	for train in 4:
		var freq := rng.randf_range(3400.0, 4600.0)
		var interval := rng.randf_range(0.9, 1.4)
		var offset := rng.randf_range(0.0, interval)
		var t := offset
		while t < seconds - 0.2:
			# One chirp = three quick pulses.
			for pulse in 3:
				var start := int((t + pulse * 0.055) * MIX_RATE)
				var length := int(0.03 * MIX_RATE)
				for i in length:
					if start + i >= n:
						break
					var pt := float(i) / MIX_RATE
					samples[start + i] += sin(TAU * freq * pt) \
							* sin(PI * float(i) / float(length)) * 0.1
			t += interval
	_fade_ends(samples)
	return _to_wav(samples, true)


## Rising sub swell used just before something happens — or, crueller,
## before nothing happens at all.
static func dread_swell() -> AudioStreamWAV:
	var seconds := 4.0
	var n := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var p := t / seconds
		var v := sin(TAU * lerpf(38.0, 55.0, p) * t)
		v += 0.5 * sin(TAU * lerpf(57.0, 83.0, p) * t)
		samples[i] = v * 0.35 * pow(p, 1.6)
	_fade_ends(samples, 0.02)
	return _to_wav(samples, false)
