class_name AudioBank
extends RefCounted
## One shared copy of every synthesized sound. Static vars are initialized
## once when the class loads, so the whole soundscape is generated a single
## time (about a second of math) and reused everywhere.

static var room_drone: AudioStreamWAV = AudioSynth.room_drone()
static var ghost_hum: AudioStreamWAV = AudioSynth.ghost_hum()
static var heartbeat: AudioStreamWAV = AudioSynth.heartbeat()
static var wind: AudioStreamWAV = AudioSynth.wind()
static var knock: AudioStreamWAV = AudioSynth.knock()
static var slam: AudioStreamWAV = AudioSynth.slam()
static var gunshot: AudioStreamWAV = AudioSynth.gunshot()
static var whisper: AudioStreamWAV = AudioSynth.whisper()
static var voices: AudioStreamWAV = AudioSynth.voices()
static var static_burst: AudioStreamWAV = AudioSynth.static_burst()
static var creak: AudioStreamWAV = AudioSynth.creak()
static var footstep: AudioStreamWAV = AudioSynth.footstep()
static var blip: AudioStreamWAV = AudioSynth.blip()
static var dread_swell: AudioStreamWAV = AudioSynth.dread_swell()
static var crickets: AudioStreamWAV = AudioSynth.crickets()
static var tinnitus: AudioStreamWAV = AudioSynth.tinnitus()
static var tv_static: AudioStreamWAV = AudioSynth.tv_static()
