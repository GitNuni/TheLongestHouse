class_name Furnisher
extends RefCounted
## Gives every generated room a domestic identity — the anti-Backrooms
## layer. A maze cell is just space; a BEDROOM is a claim that someone slept
## here, in this house, recently. That claim is what makes the wrongness
## land.
##
## No-End House structure: every piece of furniture is built through
## _place(), which applies wrongness mutations scaled by how deep in the
## house the room sits. Near the front door, rooms are merely stale. Deep
## rooms have the furniture on the ceiling and someone standing in the
## corner, facing the wall. The player learns the grammar (bed = bedroom)
## and then the grammar starts lying to them.

enum RoomType {LIVING, DINING, KITCHEN, BEDROOM, NURSERY, BATH, STUDY, CHAIR}

const CEIL_H := 3.0

var _rng: RandomNumberGenerator
var _parent: Node3D

var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _fabric: StandardMaterial3D
var _fabric_pale: StandardMaterial3D
var _porcelain: StandardMaterial3D
var _metal: StandardMaterial3D
var _mannequin_mat: StandardMaterial3D


func _init(rng: RandomNumberGenerator, parent: Node3D) -> void:
	_rng = rng
	_parent = parent
	_wood = BuildUtil.material(Color(0.42, 0.3, 0.2), 0.75)
	_wood_dark = BuildUtil.material(Color(0.28, 0.2, 0.14), 0.8)
	_fabric = BuildUtil.material(Color(0.38, 0.32, 0.3), 1.0)
	_fabric_pale = BuildUtil.material(Color(0.6, 0.58, 0.52), 1.0)
	_porcelain = BuildUtil.material(Color(0.82, 0.84, 0.83), 0.25)
	_metal = BuildUtil.material(Color(0.55, 0.56, 0.58), 0.3)
	_mannequin_mat = BuildUtil.material(Color(0.1, 0.09, 0.09), 1.0)


## Floor material per room type — pale tile for wet rooms, wood for the rest.
func floor_material(type: RoomType) -> StandardMaterial3D:
	match type:
		RoomType.BATH, RoomType.KITCHEN:
			return BuildUtil.material(Color(0.55, 0.57, 0.55), 0.4)
		_:
			return BuildUtil.material(Color(0.33, 0.24, 0.16), 0.7)


## Populate one room. origin/span are the room's world-space footprint;
## wrongness is 0 (front of house) .. 1 (deepest).
func furnish(type: RoomType, origin: Vector3, span: Vector3, wrongness: float) -> void:
	var cx := origin.x + span.x / 2.0
	var cz := origin.z + span.z / 2.0
	match type:
		RoomType.LIVING:
			_rug(Vector3(cx, 0, cz), Vector2(2.8, 2.0), Color(0.32, 0.14, 0.12))
			_place(Vector3(cx - 0.8, 0, cz + 0.7), 0.0, wrongness, 1.1, _build_couch)
			_place(Vector3(cx - 0.6, 0, cz - 0.9), 0.0, wrongness, 0.9, _build_tv)
			_place(Vector3(cx + 1.2, 0, cz), _rng.randf_range(0, TAU), wrongness, 0.7,
					_build_side_table)
		RoomType.DINING:
			_rug(Vector3(cx, 0, cz), Vector2(3.0, 2.4), Color(0.2, 0.2, 0.28))
			_place(Vector3(cx, 0, cz), 0.0, wrongness, 0.78, _build_dining_table)
			for i in 4:
				var angle := i * TAU / 4.0
				_place(Vector3(cx + cos(angle) * 1.1, 0, cz + sin(angle) * 1.1),
						angle + PI, wrongness, 0.95, _build_chair)
		RoomType.KITCHEN:
			_place(Vector3(origin.x + 0.5, 0, cz), 0.0, wrongness * 0.5, 0.95,
					_build_counter)
			_place(Vector3(origin.x + 0.55, 0, origin.z + 0.7), 0.0, wrongness, 1.9,
					_build_fridge)
			_place(Vector3(cx + 0.5, 0, cz), _rng.randf_range(0, TAU), wrongness, 0.9,
					_build_chair)
		RoomType.BEDROOM:
			_rug(Vector3(cx, 0, cz + 0.6), Vector2(1.6, 2.4), Color(0.25, 0.22, 0.3))
			_place(Vector3(cx - 0.7, 0, cz - 0.5), 0.0, wrongness, 0.9, _build_bed)
			_place(Vector3(cx + 1.1, 0, origin.z + 0.5), 0.0, wrongness, 1.15,
					_build_dresser)
		RoomType.NURSERY:
			_rug(Vector3(cx, 0, cz), Vector2(1.8, 1.8), Color(0.4, 0.38, 0.3))
			_place(Vector3(cx - 0.6, 0, cz - 0.4), 0.0, wrongness, 0.85, _build_crib)
			_place(Vector3(cx + 0.9, 0, cz + 0.6), _rng.randf_range(0, TAU), wrongness,
					1.0, _build_rocking_chair)
			for i in 3:
				BuildUtil.box(_parent, Vector3(cx + _rng.randf_range(-1.0, 1.0), 0.07,
						cz + _rng.randf_range(-1.0, 1.0)), Vector3(0.14, 0.14, 0.14),
						BuildUtil.material(Color(0.5, 0.3, 0.2).lerp(
						Color(0.3, 0.4, 0.5), _rng.randf()), 0.8))
		RoomType.BATH:
			_place(Vector3(origin.x + 0.6, 0, cz), 0.0, wrongness * 0.4, 0.6, _build_tub)
			_place(Vector3(cx + 0.8, 0, origin.z + 0.5), 0.0, wrongness, 0.9, _build_sink)
		RoomType.STUDY:
			_rug(Vector3(cx, 0, cz), Vector2(2.2, 1.8), Color(0.18, 0.25, 0.2))
			_place(Vector3(cx - 0.5, 0, cz - 0.6), 0.0, wrongness, 0.78, _build_desk)
			_place(Vector3(cx - 0.5, 0, cz + 0.2), PI, wrongness, 0.95, _build_chair)
			_place(Vector3(cx + 1.2, 0, origin.z + 0.4), 0.0, wrongness, 1.9,
					_build_bookshelf)
		RoomType.CHAIR:
			_build_chair_room(origin, span, wrongness)

	# The deep-house extras: a watcher in the corner, facing away.
	if wrongness > 0.55 and _rng.randf() < 0.4:
		_build_mannequin(Vector3(origin.x + 0.5, 0, origin.z + 0.5))
	if wrongness > 0.4 and _rng.randf() < 0.5:
		var sigil := BuildUtil.material(Color(0.25, 0.06, 0.05), 1.0,
				Color(0.7, 0.1, 0.08), 0.35)
		BuildUtil.box(_parent, Vector3(cx, 1.5, origin.z + 0.13),
				Vector3(0.7, 0.9, 0.04), sigil)


## Places one furniture piece via `builder`, applying wrongness mutations:
## most furniture is normal; deeper rooms tip it over, skew it, or put it on
## the ceiling. `height` is the piece's approximate height for ceiling math.
func _place(pos: Vector3, yaw: float, wrongness: float, height: float,
		builder: Callable) -> void:
	var wrapper := Node3D.new()
	wrapper.position = pos
	wrapper.rotation.y = yaw
	_parent.add_child(wrapper)
	builder.call(wrapper)

	var roll := _rng.randf()
	if roll < wrongness * 0.22:
		# On the ceiling, exactly where it would stand on the floor.
		wrapper.position.y = CEIL_H
		wrapper.rotation.x = PI
	elif roll < wrongness * 0.42:
		# Tipped over sideways.
		wrapper.rotation.z = PI / 2.0 * (1.0 if _rng.randf() < 0.5 else -1.0)
		wrapper.position.y = height * 0.3
	elif roll < wrongness * 0.75:
		# Just... slightly off. Skewed a few degrees, subtly too large.
		wrapper.rotation.y += _rng.randf_range(-0.2, 0.2)
		wrapper.rotation.z = _rng.randf_range(-0.05, 0.05)
		wrapper.scale = Vector3.ONE * (1.0 + wrongness * 0.14)


func _rug(center: Vector3, size: Vector2, color: Color) -> void:
	BuildUtil.box(_parent, center + Vector3(0, 0.012, 0),
			Vector3(size.x, 0.02, size.y), BuildUtil.material(color, 1.0))


func _build_couch(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.26, 0), Vector3(1.9, 0.52, 0.8), _fabric, true)
	BuildUtil.box(parent, Vector3(0, 0.72, 0.32), Vector3(1.9, 0.55, 0.22), _fabric)
	BuildUtil.box(parent, Vector3(-0.85, 0.62, 0), Vector3(0.2, 0.3, 0.75), _fabric)
	BuildUtil.box(parent, Vector3(0.85, 0.62, 0), Vector3(0.2, 0.3, 0.75), _fabric)


func _build_tv(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.24, 0), Vector3(1.2, 0.48, 0.35), _wood_dark, true)
	BuildUtil.box(parent, Vector3(0, 0.8, 0), Vector3(1.0, 0.6, 0.09),
			BuildUtil.material(Color(0.04, 0.04, 0.05), 0.25))


func _build_side_table(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.5, 0), Vector3(0.5, 0.05, 0.5), _wood, true)
	BuildUtil.box(parent, Vector3(0, 0.25, 0), Vector3(0.08, 0.5, 0.08), _wood)


func _build_dining_table(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.74, 0), Vector3(1.6, 0.07, 1.0), _wood, true)
	for corner: Vector2 in [Vector2(-0.7, -0.4), Vector2(0.7, -0.4),
			Vector2(-0.7, 0.4), Vector2(0.7, 0.4)]:
		BuildUtil.box(parent, Vector3(corner.x, 0.37, corner.y),
				Vector3(0.07, 0.74, 0.07), _wood)


func _build_chair(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.44, 0), Vector3(0.42, 0.05, 0.42), _wood, true)
	BuildUtil.box(parent, Vector3(0, 0.22, 0), Vector3(0.06, 0.44, 0.06), _wood)
	BuildUtil.box(parent, Vector3(0, 0.75, 0.19), Vector3(0.42, 0.6, 0.05), _wood)


func _build_counter(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.45, 0), Vector3(0.62, 0.9, 2.4), _wood_dark, true)
	BuildUtil.box(parent, Vector3(0, 0.92, 0), Vector3(0.66, 0.04, 2.5), _porcelain)


func _build_fridge(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.95, 0), Vector3(0.75, 1.9, 0.7), _metal, true)
	BuildUtil.box(parent, Vector3(0.3, 1.2, -0.36), Vector3(0.05, 0.5, 0.04), _metal)


func _build_bed(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.25, 0), Vector3(1.4, 0.3, 2.0), _wood_dark, true)
	BuildUtil.box(parent, Vector3(0, 0.46, 0), Vector3(1.34, 0.18, 1.94), _fabric_pale)
	BuildUtil.box(parent, Vector3(0, 0.56, -0.75), Vector3(0.6, 0.12, 0.35), _porcelain)
	BuildUtil.box(parent, Vector3(0, 0.75, -0.99), Vector3(1.4, 0.9, 0.08), _wood_dark)


func _build_dresser(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.55, 0), Vector3(1.0, 1.1, 0.45), _wood, true)
	for i in 3:
		BuildUtil.box(parent, Vector3(0, 0.25 + i * 0.3, -0.24),
				Vector3(0.8, 0.04, 0.02), _wood_dark)


func _build_crib(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.35, 0), Vector3(0.65, 0.1, 1.1), _fabric_pale, true)
	for x: float in [-0.32, 0.32]:
		BuildUtil.box(parent, Vector3(x, 0.5, 0), Vector3(0.04, 0.7, 1.1), _wood)
	for z: float in [-0.55, 0.55]:
		BuildUtil.box(parent, Vector3(0, 0.5, z), Vector3(0.65, 0.7, 0.04), _wood)


func _build_rocking_chair(parent: Node3D) -> void:
	_build_chair(parent)
	for x: float in [-0.2, 0.2]:
		BuildUtil.box(parent, Vector3(x, 0.03, 0), Vector3(0.05, 0.06, 0.7), _wood_dark)


func _build_tub(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 1.7), _porcelain, true)
	BuildUtil.box(parent, Vector3(0, 0.55, 0), Vector3(0.6, 0.1, 1.5),
			BuildUtil.material(Color(0.06, 0.08, 0.09), 0.1))


func _build_sink(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.42, 0), Vector3(0.5, 0.84, 0.45), _porcelain, true)
	BuildUtil.box(parent, Vector3(0, 1.5, -0.2), Vector3(0.5, 0.7, 0.04),
			BuildUtil.material(Color(0.05, 0.08, 0.1, 1.0), 0.08))


func _build_desk(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.72, 0), Vector3(1.3, 0.06, 0.65), _wood, true)
	for x: float in [-0.55, 0.55]:
		BuildUtil.box(parent, Vector3(x, 0.36, 0), Vector3(0.08, 0.72, 0.6), _wood_dark)
	BuildUtil.box(parent, Vector3(-0.2, 0.78, -0.1), Vector3(0.3, 0.04, 0.4),
			_fabric_pale)


func _build_bookshelf(parent: Node3D) -> void:
	BuildUtil.box(parent, Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.3), _wood_dark, true)
	for i in 4:
		var shelf_y := 0.35 + i * 0.45
		BuildUtil.box(parent, Vector3(0, shelf_y, 0.02), Vector3(0.8, 0.03, 0.26), _wood)
		for b in _rng.randi_range(3, 6):
			BuildUtil.box(parent, Vector3(-0.3 + b * 0.11, shelf_y + 0.13, 0.02),
					Vector3(0.07, 0.22, 0.18),
					BuildUtil.material(Color(0.3, 0.2, 0.15).lerp(
					Color(0.2, 0.25, 0.35), _rng.randf()), 0.9))


## A chair in the middle of a wood-paneled floor. A single lamp in the
## corner, doing a poor job. And shadows — plural — cast by nothing, most of
## them pointing in directions the lamp cannot explain. (Room three. Then
## room six. Then room eight.)
func _build_chair_room(origin: Vector3, span: Vector3, wrongness: float) -> void:
	var cx := origin.x + span.x / 2.0
	var cz := origin.z + span.z / 2.0
	var chair := Node3D.new()
	chair.position = Vector3(cx, 0, cz)
	chair.rotation.y = _rng.randf_range(0.0, TAU)
	_parent.add_child(chair)
	_build_chair(chair)

	# The corner lamp: pole, shade, and the room's only light.
	var corner := Vector3(origin.x + 0.6, 0, origin.z + 0.6)
	BuildUtil.box(_parent, corner + Vector3(0, 0.7, 0), Vector3(0.06, 1.4, 0.06),
			_metal)
	BuildUtil.box(_parent, corner + Vector3(0, 1.5, 0), Vector3(0.4, 0.35, 0.4),
			BuildUtil.material(Color(0.75, 0.68, 0.5), 0.8, Color(1.0, 0.85, 0.6), 0.8))
	BuildUtil.haunt_light(_parent, corner + Vector3(0, 1.45, 0),
			Color(1.0, 0.85, 0.62), 0.9, 6.5, 0.12, 25.0)

	# The shadows. One is honest — it points away from the lamp. The others
	# belong to no one.
	var shadow_mat := BuildUtil.material(Color(0.02, 0.02, 0.03, 0.55), 1.0)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var lamp_dir := Vector2(cx - corner.x, cz - corner.z).angle()
	var count := 2 + int(wrongness * 3.0)
	for i in count:
		var angle := lamp_dir if i == 0 else _rng.randf_range(0.0, TAU)
		var streak := Node3D.new()
		streak.position = Vector3(cx, 0.008, cz)
		streak.rotation.y = -angle
		_parent.add_child(streak)
		BuildUtil.box(streak, Vector3(0.85, 0, 0), Vector3(1.7, 0.006, 0.42),
				shadow_mat)


func _build_mannequin(pos: Vector3) -> void:
	var figure := Node3D.new()
	figure.position = pos
	figure.rotation.y = _rng.randf_range(0.0, TAU)
	_parent.add_child(figure)
	BuildUtil.box(figure, Vector3(0, 0.4, 0), Vector3(0.35, 0.8, 0.25), _mannequin_mat)
	BuildUtil.box(figure, Vector3(0, 1.15, 0), Vector3(0.5, 0.7, 0.3), _mannequin_mat)
	BuildUtil.box(figure, Vector3(0, 1.63, 0), Vector3(0.22, 0.26, 0.22), _mannequin_mat)
