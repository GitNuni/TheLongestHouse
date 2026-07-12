class_name PoliceCruiser
extends Node3D
## The patrol car at the curb — the run's opening image and the player's
## one piece of the ordinary world. The light bar washes the lawn and the
## front of the house in alternating red/blue all shift long, and the radio
## murmurs dispatch static. Self-building, like all ranch props.

var _red_light: OmniLight3D
var _blue_light: OmniLight3D
var _strobe_time := 0.0


func _ready() -> void:
	var paint := BuildUtil.material(Color(0.08, 0.08, 0.1), 0.35)
	var white := BuildUtil.material(Color(0.8, 0.8, 0.82), 0.4)
	var glass := BuildUtil.material(Color(0.05, 0.06, 0.08), 0.1)
	var tire := BuildUtil.material(Color(0.05, 0.05, 0.05), 1.0)

	BuildUtil.box(self, Vector3(0, 0.62, 0), Vector3(4.6, 0.55, 1.85), paint, true)
	BuildUtil.box(self, Vector3(-0.2, 1.15, 0), Vector3(2.3, 0.52, 1.7), white, true)
	BuildUtil.box(self, Vector3(-0.2, 1.15, 0.86), Vector3(1.9, 0.4, 0.03), glass)
	BuildUtil.box(self, Vector3(-0.2, 1.15, -0.86), Vector3(1.9, 0.4, 0.03), glass)
	BuildUtil.box(self, Vector3(0.98, 1.12, 0), Vector3(0.03, 0.38, 1.5), glass)
	for wheel_x: float in [-1.55, 1.55]:
		for wheel_z: float in [-0.85, 0.85]:
			BuildUtil.box(self, Vector3(wheel_x, 0.32, wheel_z),
					Vector3(0.62, 0.62, 0.24), tire)
	# Door shields.
	for side: float in [-0.94, 0.94]:
		var decal := Label3D.new()
		decal.text = "POLICE"
		decal.font_size = 64
		decal.modulate = Color(0.85, 0.75, 0.5)
		decal.position = Vector3(0.1, 0.68, side)
		decal.rotation.y = -PI / 2.0 if side > 0 else PI / 2.0
		add_child(decal)

	# The light bar.
	BuildUtil.box(self, Vector3(-0.2, 1.48, 0), Vector3(1.1, 0.12, 0.32),
			BuildUtil.material(Color(0.1, 0.1, 0.1), 0.4))
	BuildUtil.box(self, Vector3(-0.48, 1.48, 0), Vector3(0.45, 0.14, 0.28),
			BuildUtil.material(Color(0.5, 0.05, 0.05), 0.3, Color(1, 0.1, 0.1), 1.2))
	BuildUtil.box(self, Vector3(0.08, 1.48, 0), Vector3(0.45, 0.14, 0.28),
			BuildUtil.material(Color(0.05, 0.05, 0.5), 0.3, Color(0.15, 0.2, 1), 1.2))
	_red_light = _strobe(Vector3(-0.48, 1.7, 0), Color(1.0, 0.12, 0.08))
	_blue_light = _strobe(Vector3(0.08, 1.7, 0), Color(0.15, 0.25, 1.0))

	# Dispatch radio, forever mid-sentence.
	var radio := BuildUtil.speaker(self, Vector3(0, 1.1, 0), AudioBank.tv_static,
			-26.0, 10.0)
	radio.pitch_scale = 0.6
	radio.play()


func _strobe(pos: Vector3, color: Color) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = 22.0
	light.shadow_enabled = true
	add_child(light)
	return light


func _process(delta: float) -> void:
	_strobe_time += delta
	# Classic alternating wig-wag at ~1.4 Hz per side.
	var phase := fmod(_strobe_time * 2.8, 2.0)
	_red_light.light_energy = 2.6 if phase < 0.7 else 0.0
	_blue_light.light_energy = 2.6 if phase >= 1.0 and phase < 1.7 else 0.0
