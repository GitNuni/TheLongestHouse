class_name Evidence
extends Node3D
## A piece of evidence the player logs by aiming the bodycam at it and
## holding the tag key. Builds its own visual based on `kind`.
##
## Placement philosophy (see HouseGenerator): evidence lives in dead ends,
## behind furniture, low to the ground — the maze makes you EARN line of
## sight. The faint emissive pulse is the only mercy: a flicker of
## not-quite-right in the corner of the eye.
##
## The collider sits on collision layer 4 so gunfire (layer 1 mask) ignores
## it, while the player's tagging raycast (mask 1|4) can still hit it —
## through open air only; walls and props on layer 1 still block the ray.

signal logged(evidence: Evidence)

enum Kind {SIGIL_PAGE, BONES, RECORDER, IDOL, NOTE}

const TAG_SECONDS := 1.4

var kind := Kind.SIGIL_PAGE
var tag_progress := 0.0
var is_logged := false

var _pulse_material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	match kind:
		Kind.SIGIL_PAGE:
			_pulse_material = BuildUtil.material(
					Color(0.75, 0.7, 0.6), 0.9, Color(0.9, 0.25, 0.1), 0.25)
			BuildUtil.box(self, Vector3(0, 0.012, 0), Vector3(0.28, 0.02, 0.38),
					_pulse_material)
		Kind.BONES:
			_pulse_material = BuildUtil.material(
					Color(0.85, 0.82, 0.72), 0.7, Color(0.7, 0.7, 0.5), 0.12)
			for i in 4:
				var b := BuildUtil.box(self,
						Vector3(randf_range(-0.2, 0.2), 0.03, randf_range(-0.2, 0.2)),
						Vector3(0.3, 0.05, 0.06), _pulse_material)
				b.rotation.y = randf_range(0.0, TAU)
		Kind.RECORDER:
			_pulse_material = BuildUtil.material(
					Color(0.1, 0.1, 0.12), 0.4, Color(0.9, 0.15, 0.1), 1.2)
			BuildUtil.box(self, Vector3(0, 0.04, 0), Vector3(0.16, 0.08, 0.1),
					BuildUtil.material(Color(0.15, 0.15, 0.17), 0.4))
			BuildUtil.box(self, Vector3(0.05, 0.09, 0), Vector3(0.02, 0.02, 0.02),
					_pulse_material)
		Kind.IDOL:
			_pulse_material = BuildUtil.material(
					Color(0.12, 0.08, 0.07), 0.95, Color(0.6, 0.1, 0.05), 0.3)
			BuildUtil.box(self, Vector3(0, 0.15, 0), Vector3(0.1, 0.3, 0.1), _pulse_material)
			BuildUtil.box(self, Vector3(0, 0.32, 0), Vector3(0.16, 0.06, 0.06), _pulse_material)
		Kind.NOTE:
			# A clean white envelope, hand-addressed. "From Management."
			_pulse_material = BuildUtil.material(
					Color(0.88, 0.86, 0.8), 0.85, Color(0.8, 0.75, 0.6), 0.1)
			BuildUtil.box(self, Vector3(0, 0.008, 0), Vector3(0.24, 0.012, 0.16),
					_pulse_material)
			var label := Label3D.new()
			label.text = "from management"
			label.font_size = 26
			label.modulate = Color(0.25, 0.2, 0.2)
			label.position = Vector3(0, 0.02, 0)
			label.rotation.x = -PI / 2.0
			add_child(label)

	# Tagging target — layer 4, see class docs.
	var body := StaticBody3D.new()
	body.collision_layer = 4
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.4, 0.5)
	shape.shape = box
	shape.position = Vector3(0, 0.2, 0)
	body.add_child(shape)
	add_child(body)
	add_to_group("evidence")


func _process(delta: float) -> void:
	if is_logged:
		return
	_time += delta
	# Slow uneasy pulse; not a beacon, a wrongness.
	var pulse := 0.5 + 0.5 * sin(_time * 2.2 + sin(_time * 0.7) * 2.0)
	_pulse_material.emission_energy_multiplier = lerpf(0.08, 0.5, pulse)


## Called by the player each frame the bodycam is held on this item.
## Returns progress in 0..1.
func advance_tag(delta: float) -> float:
	if is_logged:
		return 1.0
	tag_progress += delta / TAG_SECONDS
	if tag_progress >= 1.0:
		is_logged = true
		_pulse_material.emission_energy_multiplier = 0.0
		logged.emit(self)
	return clampf(tag_progress, 0.0, 1.0)


## Progress decays if the camera drifts off target — no lazy drive-by tags.
func decay_tag(delta: float) -> void:
	if not is_logged:
		tag_progress = maxf(0.0, tag_progress - delta * 0.7)
