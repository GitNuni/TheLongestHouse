class_name RanchBuilder
extends HouseBase
## Builds the True House: the canonical suburban ranch from
## docs/design/house_and_corruption.md, plus the street outside — cruiser,
## lawn, porch, neighbors' dark windows. This is the SANE baseline
## (corruption tier 0 only): the house must make sense before it can stop
## making sense. All wrongness here is deniable — a porch light flickering,
## one window of TV static, seven chairs at a six-person table, food still
## out, faint tinnitus near the porch. Nothing you could put in a report.
##
## Coordinates: x 0..15.2 east, z 0 (back yard) .. 9 (street side), garage
## attached west at x -5.4..0. Basement at y -2.8 under the kitchen wing.
## Interior walls 2.5 m; doors 2.0.

const WALL_H := 2.5
const WALL_T := 0.16
const DOOR_H := 2.0

var _rng := RandomNumberGenerator.new()
var _furnisher: Furnisher
var _mat_wall: StandardMaterial3D
var _mat_wainscot: StandardMaterial3D
var _mat_rail: StandardMaterial3D
var _mat_floor: StandardMaterial3D
var _mat_ceiling: StandardMaterial3D
var _mat_trim: StandardMaterial3D
var _mat_concrete: StandardMaterial3D
var _mat_glass: StandardMaterial3D
## Places the director can put spawns and positional sounds.
var _interior_points: Array[Vector3] = []
var _basement_points: Array[Vector3] = []


func _ready() -> void:
	_rng.randomize()
	_furnisher = Furnisher.new(_rng, self)
	_make_materials()
	_build_exterior()
	_build_walls()
	_build_floors_and_roof()
	_build_basement()
	_furnish_rooms()
	_place_tier0_details()
	_place_lights()
	_place_evidence()
	_spawn_basement_cultists()

	player_spawn = Vector3(6.0, 0.1, 17.2)
	evidence_logged.emit(0, evidence_total)


func random_corridor_position_near(origin: Vector3, min_m: float, max_m: float) -> Vector3:
	var all := _interior_points + _basement_points
	for _attempt in 24:
		var pos: Vector3 = all[_rng.randi_range(0, all.size() - 1)]
		var d := pos.distance_to(origin)
		if d >= min_m and d <= max_m:
			return pos
	return all[_rng.randi_range(0, all.size() - 1)]


func _make_materials() -> void:
	_mat_wall = BuildUtil.material(Color(0.58, 0.53, 0.44), 0.9)
	_mat_wainscot = BuildUtil.material(Color(0.3, 0.22, 0.16), 0.8)
	_mat_rail = BuildUtil.material(Color(0.36, 0.27, 0.2), 0.75)
	_mat_floor = BuildUtil.material(Color(0.33, 0.24, 0.16), 0.7)
	_mat_ceiling = BuildUtil.material(Color(0.52, 0.5, 0.46), 0.95)
	_mat_trim = BuildUtil.material(Color(0.28, 0.21, 0.16), 0.85)
	_mat_concrete = BuildUtil.material(Color(0.38, 0.38, 0.4), 0.95)
	_mat_glass = BuildUtil.material(Color(0.03, 0.04, 0.06), 0.05,
			Color(0.05, 0.08, 0.12), 0.15)


## ----- Wall plumbing ---------------------------------------------------------


## One wall segment with the house treatment: wainscot, rail, wallpaper.
func _seg(center: Vector3, length: float, along_x: bool, height := WALL_H,
		y_base := 0.0) -> void:
	var low := minf(1.0, height)
	var wain := Vector3(length, low, WALL_T + 0.03) if along_x \
			else Vector3(WALL_T + 0.03, low, length)
	var paper_h := height - low
	BuildUtil.box(self, center + Vector3(0, y_base + low / 2.0, 0), wain,
			_mat_wainscot, true)
	if paper_h > 0.01:
		var paper := Vector3(length, paper_h, WALL_T) if along_x \
				else Vector3(WALL_T, paper_h, length)
		BuildUtil.box(self, center + Vector3(0, y_base + low + paper_h / 2.0, 0),
				paper, _mat_wall, true)
		var rail := Vector3(length, 0.06, WALL_T + 0.06) if along_x \
				else Vector3(WALL_T + 0.06, 0.06, length)
		BuildUtil.box(self, center + Vector3(0, y_base + low + 0.01, 0), rail, _mat_rail)


## A wall running along X at depth z, from x0 to x1, with door/arch gaps:
## each gap is {"at": center_x, "w": width, "door": bool}.
func _wall_x(z: float, x0: float, x1: float, gaps: Array = []) -> void:
	gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["at"] < b["at"])
	var cursor := x0
	for gap: Dictionary in gaps:
		var g_at: float = gap["at"]
		var g_w: float = gap["w"]
		var left := g_at - g_w / 2.0
		if left - cursor > 0.05:
			_seg(Vector3((cursor + left) / 2.0, 0, z), left - cursor, true)
		# Header above the opening.
		BuildUtil.box(self, Vector3(g_at, (WALL_H + DOOR_H) / 2.0, z),
				Vector3(g_w, WALL_H - DOOR_H, WALL_T), _mat_wall, true)
		if gap.get("door", false):
			var door := HauntedDoor.new()
			door.position = Vector3(left, 0, z)
			add_child(door)
		cursor = g_at + g_w / 2.0
	if x1 - cursor > 0.05:
		_seg(Vector3((cursor + x1) / 2.0, 0, z), x1 - cursor, true)


## Same, running along Z at x.
func _wall_z(x: float, z0: float, z1: float, gaps: Array = []) -> void:
	gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["at"] < b["at"])
	var cursor := z0
	for gap: Dictionary in gaps:
		var g_at: float = gap["at"]
		var g_w: float = gap["w"]
		var near_edge := g_at - g_w / 2.0
		if near_edge - cursor > 0.05:
			_seg(Vector3(x, 0, (cursor + near_edge) / 2.0), near_edge - cursor, false)
		BuildUtil.box(self, Vector3(x, (WALL_H + DOOR_H) / 2.0, g_at),
				Vector3(WALL_T, WALL_H - DOOR_H, g_w), _mat_wall, true)
		if gap.get("door", false):
			var door := HauntedDoor.new()
			door.position = Vector3(x, 0, near_edge)
			door.rotation.y = -PI / 2.0
			add_child(door)
		cursor = g_at + g_w / 2.0
	if z1 - cursor > 0.05:
		_seg(Vector3(x, 0, (cursor + z1) / 2.0), z1 - cursor, false)


## Window panes + frame applied to both faces of a solid wall.
func _window(pos: Vector3, along_x: bool) -> void:
	var center := pos + Vector3(0, 1.5, 0)
	for side: float in [-1.0, 1.0]:
		var offset := Vector3(0, 0, side * (WALL_T / 2.0 + 0.03)) if along_x \
				else Vector3(side * (WALL_T / 2.0 + 0.03), 0, 0)
		var pane := Vector3(1.2, 1.0, 0.03) if along_x else Vector3(0.03, 1.0, 1.2)
		BuildUtil.box(self, center + offset, pane, _mat_glass)
		var bar_h := Vector3(1.34, 0.07, 0.06) if along_x else Vector3(0.06, 0.07, 1.34)
		var bar_v := Vector3(0.07, 1.14, 0.06) if along_x else Vector3(0.06, 1.14, 0.07)
		BuildUtil.box(self, center + offset + Vector3(0, 0.53, 0), bar_h, _mat_trim)
		BuildUtil.box(self, center + offset + Vector3(0, -0.53, 0), bar_h, _mat_trim)
		var span := Vector3(0.63, 0, 0) if along_x else Vector3(0, 0, 0.63)
		BuildUtil.box(self, center + offset + span, bar_v, _mat_trim)
		BuildUtil.box(self, center + offset - span, bar_v, _mat_trim)
		BuildUtil.box(self, center + offset, bar_v, _mat_trim)


## ----- The plan --------------------------------------------------------------


func _build_walls() -> void:
	# Perimeter.
	_wall_x(0.0, 0.0, 15.2)                                     # back
	_wall_x(9.0, 0.0, 15.2, [{"at": 5.7, "w": 1.0, "door": true}])  # front
	_wall_z(0.0, 0.0, 3.6)                                      # kitchen west
	_wall_z(15.2, 0.0, 9.0)                                     # east
	# Garage shell (attached, west).
	_wall_z(-5.4, 3.6, 9.0)
	_wall_x(3.6, -5.4, 0.0)
	_wall_x(9.0, -5.4, 0.0, [{"at": -2.7, "w": 3.4}])
	BuildUtil.box(self, Vector3(-2.7, 1.05, 9.0), Vector3(3.4, 2.1, 0.1),
			BuildUtil.material(Color(0.5, 0.5, 0.48), 0.6), true)  # closed garage door
	_wall_z(0.0, 3.6, 9.0, [{"at": 4.7, "w": 0.9, "door": true}])   # laundry->garage

	# Run A: back rooms / hall (z = 3.6).
	_wall_x(3.6, 0.0, 15.2, [
		{"at": 1.25, "w": 0.9, "door": true},   # kitchen -> laundry
		{"at": 4.7, "w": 1.4},                  # dining arch
		{"at": 7.2, "w": 0.9, "door": true},    # BASEMENT DOOR
		{"at": 9.45, "w": 0.9, "door": true},   # bed 2
		{"at": 12.05, "w": 0.9, "door": true},  # master
	])
	# Run B: hall / front rooms (z = 4.8).
	_wall_x(4.8, 2.0, 13.0, [
		{"at": 5.6, "w": 2.0},                  # foyer opening
		{"at": 7.45, "w": 0.9, "door": true},   # bed 3
		{"at": 10.1, "w": 0.7, "door": true},   # linen closet
		{"at": 11.8, "w": 1.2},                 # den arch
	])
	_wall_z(2.0, 3.6, 4.8, [{"at": 4.2, "w": 0.9, "door": true}])   # hall -> laundry
	_wall_z(13.0, 3.6, 4.8, [{"at": 4.2, "w": 0.9, "door": true}])  # hall -> bath
	# Bath enclosure.
	_wall_z(13.0, 4.8, 5.6)
	_wall_x(5.6, 13.0, 15.2)
	# Laundry enclosure.
	_wall_x(5.6, 0.0, 2.0)
	_wall_z(2.0, 4.8, 5.6)
	# Kitchen / dining.
	_wall_z(3.6, 0.0, 3.6, [{"at": 1.8, "w": 1.6}])
	# Stair nook (basement stairwell shaft).
	_wall_z(6.6, 0.0, 3.6)
	_wall_z(7.8, 0.0, 3.6)
	# Bedroom dividers.
	_wall_z(11.0, 0.0, 3.6)
	# Master ensuite.
	_wall_z(13.6, 0.0, 2.0, [{"at": 1.0, "w": 0.8, "door": true}])
	_wall_x(2.0, 13.6, 15.2)
	# Living / foyer.
	_wall_z(4.6, 4.8, 9.0, [{"at": 6.5, "w": 1.8}])
	# Foyer / bed 3.
	_wall_z(6.6, 4.8, 9.0)
	# Bed 3 / den.
	_wall_z(9.6, 5.6, 9.0)
	# Linen closet box.
	_wall_z(9.6, 4.8, 5.6)
	_wall_z(10.6, 4.8, 5.6)
	_wall_x(5.6, 9.6, 10.6)

	# Windows (positions agree with the exterior the player walks past).
	_window(Vector3(1.9, 0, 0.0), true)     # kitchen, back yard
	_window(Vector3(9.3, 0, 0.0), true)     # bed 2
	_window(Vector3(12.7, 0, 0.0), true)    # master
	_window(Vector3(2.5, 0, 9.0), true)     # living picture window
	_window(Vector3(8.0, 0, 9.0), true)     # bed 3
	_window(Vector3(12.1, 0, 9.0), true)    # den
	_window(Vector3(15.2, 0, 1.1), false)   # master, side yard
	_window(Vector3(15.2, 0, 7.0), false)   # den, side yard


func _build_floors_and_roof() -> void:
	# Room slabs (the stair nook x 6.6..7.8 z 0..3.6 gets NO slab — open well).
	var rects: Array[Rect2] = [
		Rect2(0, 0, 3.6, 3.6),      # kitchen
		Rect2(3.6, 0, 3.0, 3.6),    # dining
		Rect2(7.8, 0, 3.2, 3.6),    # bed 2
		Rect2(11.0, 0, 4.2, 3.6),   # master + ensuite
		Rect2(2.0, 3.6, 11.0, 1.2), # hall
		Rect2(0, 3.6, 2.0, 2.0),    # laundry
		Rect2(13.0, 3.6, 2.2, 2.0), # bath
		Rect2(0, 5.6, 0.0, 0.0),    # (spacer)
		Rect2(0, 4.8, 4.6, 4.2),    # living
		Rect2(4.6, 4.8, 2.0, 4.2),  # foyer corridor
		Rect2(6.6, 4.8, 3.0, 4.2),  # bed 3
		Rect2(9.6, 4.8, 3.4, 4.2),  # closet strip + den west
		Rect2(13.0, 5.6, 2.2, 3.4), # den east
	]
	for r in rects:
		if r.size.x < 0.1:
			continue
		BuildUtil.box(self, Vector3(r.position.x + r.size.x / 2.0, -0.05,
				r.position.y + r.size.y / 2.0), Vector3(r.size.x, 0.1, r.size.y),
				_mat_floor, true)
	# Garage slab.
	BuildUtil.box(self, Vector3(-2.7, -0.05, 6.3), Vector3(5.4, 0.1, 5.4),
			_mat_concrete, true)
	# One ceiling over everything interior.
	BuildUtil.box(self, Vector3(4.9, WALL_H + 0.06, 4.5), Vector3(20.8, 0.12, 9.2),
			_mat_ceiling, true)
	# Roof: low flat slab with eaves, plus a modest ridge for the silhouette.
	var roof := BuildUtil.material(Color(0.2, 0.17, 0.15), 0.95)
	BuildUtil.box(self, Vector3(4.9, WALL_H + 0.45, 4.5), Vector3(22.0, 0.35, 10.4),
			roof, true)
	BuildUtil.box(self, Vector3(4.9, WALL_H + 0.85, 4.5), Vector3(16.0, 0.5, 6.0), roof)

	for point: Vector3 in [Vector3(1.8, 0, 1.8), Vector3(5.1, 0, 1.8),
			Vector3(9.4, 0, 1.8), Vector3(13.1, 0, 1.8), Vector3(4.0, 0, 4.2),
			Vector3(9.0, 0, 4.2), Vector3(12.0, 0, 4.2), Vector3(2.3, 0, 6.9),
			Vector3(5.6, 0, 6.9), Vector3(8.1, 0, 6.9), Vector3(12.4, 0, 7.2),
			Vector3(1.0, 0, 4.6), Vector3(14.1, 0, 4.6)]:
		_interior_points.append(point)


func _build_basement() -> void:
	# Unfinished. Concrete. The cult's floor.
	BuildUtil.box(self, Vector3(3.9, -2.85, 2.8), Vector3(8.2, 0.1, 6.0),
			_mat_concrete, true)
	for wall_data: Array in [[Vector3(3.9, -1.4, -0.08), Vector3(8.2, 2.8, 0.16)],
			[Vector3(3.9, -1.4, 5.68), Vector3(8.2, 2.8, 0.16)],
			[Vector3(-0.08, -1.4, 2.8), Vector3(0.16, 2.8, 6.0)],
			[Vector3(7.88, -1.4, 2.8), Vector3(0.16, 2.8, 6.0)]]:
		BuildUtil.box(self, wall_data[0], wall_data[1], _mat_concrete, true)
	# Stairwell shaft walls below grade; west side open at the bottom north
	# stretch so the stairs release into the room.
	BuildUtil.box(self, Vector3(6.6, -1.4, 2.4), Vector3(0.16, 2.8, 2.4),
			_mat_concrete, true)
	BuildUtil.box(self, Vector3(7.8, -1.4, 1.8), Vector3(0.16, 2.8, 3.6),
			_mat_concrete, true)

	# Landing strip flush with the hall floor, then the run begins.
	BuildUtil.box(self, Vector3(7.2, -0.05, 3.45), Vector3(1.2, 0.1, 0.34),
			_mat_floor, true)
	# Straight stair run down: z 3.3 (top) to z 0.1, drop 2.8.
	var steps := BuildUtil.material(Color(0.3, 0.27, 0.24), 0.9)
	for k in 13:
		BuildUtil.box(self, Vector3(7.2, -0.1 - 0.215 * k, 3.18 - 0.246 * k),
				Vector3(0.85, 0.22, 0.26), steps)
	var ramp := StaticBody3D.new()
	add_child(ramp)
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(0.9, 0.1, 4.3)
	ramp_shape.shape = ramp_box
	# In code, Transform3D takes the three basis axes as Vector3 COLUMNS plus
	# the origin (the 12-float flat form only exists in .tscn files).
	# This is a rotation about X tilting the ramp to descend toward -Z:
	# top edge lands at (y 0, z 3.3), bottom at (y -2.8, z 0.1).
	ramp_shape.transform = Transform3D(
			Vector3(1, 0, 0),
			Vector3(0, 0.752, -0.658),
			Vector3(0, 0.658, 0.752),
			Vector3(7.2, -1.4, 1.7))
	ramp.add_child(ramp_shape)

	# Ritual corner: circle of candles, sigils, and things on shelves.
	var circle_center := Vector3(2.6, -2.8, 2.6)
	var sigil := BuildUtil.material(Color(0.25, 0.06, 0.05), 1.0,
			Color(0.7, 0.1, 0.08), 0.35)
	BuildUtil.box(self, circle_center + Vector3(0, 0.006, 0), Vector3(2.6, 0.01, 2.6),
			BuildUtil.material(Color(0.2, 0.06, 0.05), 1.0, Color(0.6, 0.1, 0.08), 0.3))
	for i in 6:
		var angle := i * TAU / 6.0
		BuildUtil.box(self, circle_center + Vector3(cos(angle) * 1.6, 0.13,
				sin(angle) * 1.6), Vector3(0.07, 0.24, 0.07),
				BuildUtil.material(Color(0.9, 0.85, 0.7), 0.8, Color(1, 0.65, 0.3), 1.4))
	BuildUtil.box(self, Vector3(0.4, -1.55, 4.8), Vector3(0.7, 0.9, 0.04), sigil)
	BuildUtil.box(self, Vector3(6.0, -1.55, 0.15), Vector3(0.7, 0.9, 0.04), sigil)
	# Water heater and shelving — the basement is still a basement.
	BuildUtil.box(self, Vector3(0.6, -2.05, 0.6), Vector3(0.7, 1.5, 0.7),
			BuildUtil.material(Color(0.6, 0.6, 0.62), 0.4), true)
	BuildUtil.box(self, Vector3(5.2, -1.85, 5.3), Vector3(2.0, 1.9, 0.4),
			BuildUtil.material(Color(0.32, 0.25, 0.18), 0.85), true)

	for point: Vector3 in [Vector3(2.6, -2.8, 2.6), Vector3(5.5, -2.8, 1.5),
			Vector3(1.5, -2.8, 4.5)]:
		_basement_points.append(point)


func _furnish_rooms() -> void:
	# All at wrongness 0 — the True House is sane. The Furnisher's mutation
	# gate simply never fires at zero.
	_furnisher.furnish(Furnisher.RoomType.LIVING, Vector3(0, 0, 4.8),
			Vector3(4.6, 0, 4.2), 0.0)
	_furnisher.furnish(Furnisher.RoomType.DINING, Vector3(3.6, 0, 0),
			Vector3(3.0, 0, 3.6), 0.0)
	_furnisher.furnish(Furnisher.RoomType.KITCHEN, Vector3(0, 0, 0),
			Vector3(3.6, 0, 3.6), 0.0)
	_furnisher.furnish(Furnisher.RoomType.BEDROOM, Vector3(7.8, 0, 0),
			Vector3(3.2, 0, 3.6), 0.0)
	_furnisher.furnish(Furnisher.RoomType.BEDROOM, Vector3(11.0, 0, 0),
			Vector3(2.6, 0, 3.6), 0.0)
	_furnisher.furnish(Furnisher.RoomType.BEDROOM, Vector3(6.6, 0, 5.4),
			Vector3(3.0, 0, 3.6), 0.0)
	_furnisher.furnish(Furnisher.RoomType.BATH, Vector3(13.0, 0, 3.6),
			Vector3(2.2, 0, 2.0), 0.0)
	_furnisher.furnish(Furnisher.RoomType.STUDY, Vector3(10.6, 0, 5.6),
			Vector3(4.6, 0, 3.4), 0.0)
	# Ensuite: just a sink and mirror.
	var sink_holder := Node3D.new()
	sink_holder.position = Vector3(14.4, 0, 0.6)
	add_child(sink_holder)
	BuildUtil.box(sink_holder, Vector3(0, 0.42, 0), Vector3(0.5, 0.84, 0.45),
			BuildUtil.material(Color(0.82, 0.84, 0.83), 0.25), true)
	# Laundry: washer and dryer.
	for i in 2:
		BuildUtil.box(self, Vector3(0.55 + i * 0.85, 0.45, 5.2),
				Vector3(0.75, 0.9, 0.7),
				BuildUtil.material(Color(0.8, 0.8, 0.82), 0.3), true)


func _place_tier0_details() -> void:
	# Seven chairs at a table set for six. Nobody counts chairs — at first.
	var dining_center := Vector3(5.1, 0, 1.8)
	for i in 3:
		var angle := _rng.randf_range(0.0, TAU)
		var extra := Node3D.new()
		extra.position = dining_center + Vector3(cos(angle) * 1.35, 0,
				sin(angle) * 1.35)
		extra.rotation.y = angle + PI
		add_child(extra)
		var wood := BuildUtil.material(Color(0.42, 0.3, 0.2), 0.75)
		BuildUtil.box(extra, Vector3(0, 0.44, 0), Vector3(0.42, 0.05, 0.42), wood, true)
		BuildUtil.box(extra, Vector3(0, 0.22, 0), Vector3(0.06, 0.44, 0.06), wood)
		BuildUtil.box(extra, Vector3(0, 0.75, 0.19), Vector3(0.42, 0.6, 0.05), wood)
	# Dinner, still out. Still warm, if anyone checks.
	for i in 4:
		BuildUtil.box(self, dining_center + Vector3(_rng.randf_range(-0.5, 0.5),
				0.79, _rng.randf_range(-0.3, 0.3)), Vector3(0.2, 0.04, 0.2),
				BuildUtil.material(Color(0.8, 0.78, 0.72), 0.4))
	# The TV in the living room is on. It is tuned to nothing.
	var tv_pos := Vector3(1.7, 0, 6.0)
	var tv_light := BuildUtil.haunt_light(self, tv_pos + Vector3(0, 1.0, 0.6),
			Color(0.55, 0.65, 1.0), 0.5, 3.5, 0.85, 6.0)
	tv_light.distress_color = Color(0.2, 0.25, 0.35)
	var tv_speaker := BuildUtil.speaker(self, tv_pos + Vector3(0, 0.8, 0),
			AudioBank.tv_static, -18.0, 9.0)
	tv_speaker.play()
	# The tinnitus. Fades in near the house; the player will blame their ears.
	var whine := BuildUtil.speaker(self, Vector3(7.6, 1.5, 4.5),
			AudioBank.tinnitus, -26.0, 26.0)
	whine.play()


func _place_lights() -> void:
	# Calm, domestic, warm — flicker levels a homeowner would ignore.
	for light_spec: Array in [
		[Vector3(1.8, 0, 1.8), 0.08],   # kitchen
		[Vector3(5.1, 0, 1.8), 0.05],   # dining
		[Vector3(9.4, 0, 1.8), 0.06],   # bed 2
		[Vector3(12.6, 0, 1.8), 0.05],  # master
		[Vector3(4.5, 0, 4.2), 0.12],   # hall west
		[Vector3(10.5, 0, 4.2), 0.12],  # hall east
		[Vector3(2.3, 0, 6.9), 0.1],    # living
		[Vector3(5.6, 0, 7.5), 0.08],   # foyer
		[Vector3(8.1, 0, 6.9), 0.06],   # bed 3
		[Vector3(12.6, 0, 7.2), 0.08],  # den
		[Vector3(1.0, 0, 4.6), 0.1],    # laundry
		[Vector3(14.1, 0, 4.6), 0.15],  # bath
	]:
		var pos: Vector3 = light_spec[0]
		BuildUtil.box(self, pos + Vector3(0, WALL_H - 0.06, 0),
				Vector3(0.3, 0.05, 0.3), _mat_trim)
		BuildUtil.box(self, pos + Vector3(0, WALL_H - 0.16, 0),
				Vector3(0.1, 0.18, 0.1),
				BuildUtil.material(Color(0.9, 0.86, 0.74), 0.6, Color(1, 0.9, 0.7), 1.3))
		BuildUtil.haunt_light(self, pos + Vector3(0, WALL_H - 0.28, 0),
				Color(1.0, 0.88, 0.72), 1.4, 7.0, light_spec[1],
				_rng.randf_range(50.0, 120.0))
	# Garage: one cold tube.
	BuildUtil.haunt_light(self, Vector3(-2.7, WALL_H - 0.3, 6.3),
			Color(0.85, 0.9, 0.88), 1.0, 7.0, 0.25, 30.0)
	# Basement: two bare bulbs, colder, less reliable.
	BuildUtil.haunt_light(self, Vector3(2.4, -0.5, 2.6), Color(0.9, 0.85, 0.7),
			1.0, 6.0, 0.3, 22.0)
	BuildUtil.haunt_light(self, Vector3(6.2, -0.5, 4.2), Color(0.8, 0.82, 0.78),
			0.8, 5.0, 0.4, 18.0)


func _build_exterior() -> void:
	var lawn := BuildUtil.material(Color(0.1, 0.14, 0.08), 1.0)
	var asphalt := BuildUtil.material(Color(0.09, 0.09, 0.1), 0.95)
	var pavement := BuildUtil.material(Color(0.3, 0.3, 0.3), 0.9)

	BuildUtil.box(self, Vector3(4.9, -0.06, 12.2), Vector3(34, 0.1, 6.6), lawn, true)
	BuildUtil.box(self, Vector3(4.9, -0.06, -2.5), Vector3(34, 0.1, 5.2), lawn, true)
	BuildUtil.box(self, Vector3(4.9, -0.05, 16.3), Vector3(34, 0.1, 1.6),
			pavement, true)
	BuildUtil.box(self, Vector3(4.9, -0.06, 20.5), Vector3(34, 0.1, 6.8),
			asphalt, true)
	# Front walk and driveway.
	BuildUtil.box(self, Vector3(5.75, -0.04, 12.2), Vector3(0.9, 0.11, 6.6),
			pavement, true)
	BuildUtil.box(self, Vector3(-2.7, -0.04, 12.2), Vector3(3.4, 0.11, 6.6),
			pavement, true)

	# Porch: slab, posts, roof, and the light that flickers first.
	BuildUtil.box(self, Vector3(5.7, 0.01, 9.8), Vector3(2.6, 0.08, 1.6),
			pavement, true)
	for post_x: float in [4.6, 6.8]:
		BuildUtil.box(self, Vector3(post_x, 1.25, 10.4), Vector3(0.12, 2.5, 0.12),
				_mat_trim, true)
	BuildUtil.box(self, Vector3(5.7, 2.56, 9.9), Vector3(3.0, 0.12, 2.0), _mat_trim)
	BuildUtil.haunt_light(self, Vector3(5.7, 2.2, 9.4), Color(1.0, 0.85, 0.6),
			1.1, 6.0, 0.3, 14.0)

	# House number by the door. This address is on the call sheet.
	var number := Label3D.new()
	number.text = "1409"
	number.font_size = 48
	number.modulate = Color(0.75, 0.7, 0.6)
	number.position = Vector3(6.5, 1.9, 9.06)
	add_child(number)

	# The cruiser, parked mid-street, lights going.
	var cruiser := PoliceCruiser.new()
	cruiser.position = Vector3(7.5, 0, 18.5)
	cruiser.rotation.y = PI
	add_child(cruiser)
	# Ammo in the trunk.
	_ammo_box(Vector3(9.6, 0.7, 18.5))

	# Streetlights.
	for light_x: float in [-6.0, 5.0, 16.0]:
		BuildUtil.box(self, Vector3(light_x, 2.4, 16.9), Vector3(0.14, 4.8, 0.14),
				BuildUtil.material(Color(0.2, 0.2, 0.22), 0.7), true)
		BuildUtil.haunt_light(self, Vector3(light_x, 4.6, 16.9),
				Color(1.0, 0.8, 0.55), 1.6, 11.0, 0.08, 60.0)

	# Neighbors across the street: dark shapes, dark windows. One window,
	# far down, has the faint blue of a TV. Nobody answers doors tonight.
	var silhouette := BuildUtil.material(Color(0.05, 0.05, 0.06), 1.0)
	for neighbor_x: float in [-8.0, 6.0, 20.0]:
		BuildUtil.box(self, Vector3(neighbor_x, 1.6, 27.5), Vector3(9.0, 3.2, 6.0),
				silhouette, true)
	BuildUtil.box(self, Vector3(7.8, 1.5, 24.4), Vector3(0.9, 0.7, 0.05),
			BuildUtil.material(Color(0.1, 0.12, 0.2), 0.5, Color(0.25, 0.3, 0.5), 0.4))

	# Mailbox at the curb.
	BuildUtil.box(self, Vector3(4.3, 0.5, 15.6), Vector3(0.08, 1.0, 0.08),
			_mat_trim, true)
	BuildUtil.box(self, Vector3(4.3, 1.1, 15.6), Vector3(0.5, 0.25, 0.25),
			BuildUtil.material(Color(0.25, 0.25, 0.28), 0.5), true)


func _ammo_box(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	BuildUtil.box(holder, Vector3.ZERO, Vector3(0.22, 0.12, 0.14),
			BuildUtil.material(Color(0.65, 0.5, 0.25), 0.3, Color(0.8, 0.6, 0.2), 0.15))
	BuildUtil.trigger(holder, Vector3(0, 0.3, 0), Vector3(1.2, 1.6, 1.2),
			func(body: Player) -> void:
				body.add_ammo(6)
				holder.queue_free())


func _place_evidence() -> void:
	var placements: Array[Array] = [
		[Evidence.Kind.NOTE, Vector3(1.3, 0.52, 5.9)],       # living side table
		[Evidence.Kind.RECORDER, Vector3(0.6, 0.94, 1.2)],   # kitchen counter
		[Evidence.Kind.IDOL, Vector3(12.5, 0.02, 0.5)],      # master, floor corner
		[Evidence.Kind.BONES, Vector3(8.2, 0.02, 0.6)],      # bed 2, under window
		[Evidence.Kind.SIGIL_PAGE, Vector3(14.3, 0.02, 8.3)],  # den corner
		[Evidence.Kind.SIGIL_PAGE, Vector3(2.6, -2.78, 2.6)],  # ritual circle
		[Evidence.Kind.RECORDER, Vector3(5.4, -2.78, 5.0)],  # basement shelf area
		[Evidence.Kind.NOTE, Vector3(0.8, -2.78, 1.6)],      # basement floor
	]
	evidence_total = placements.size()
	for placement in placements:
		var evidence := Evidence.new()
		evidence.kind = placement[0]
		evidence.position = placement[1]
		evidence.logged.connect(_on_evidence_item_logged)
		add_child(evidence)


func _on_evidence_item_logged(_evidence: Evidence) -> void:
	evidence_found += 1
	evidence_logged.emit(evidence_found, evidence_total)


func _spawn_basement_cultists() -> void:
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	for i in 2:
		var cultist := Cultist.new()
		cultist.player = player
		# Straight-line paths only — fine in the open basement room, which is
		# the only place cultists live in the True House.
		cultist.find_path = func(_from: Vector3, to: Vector3) -> PackedVector3Array:
			if to == Vector3.ZERO:
				return PackedVector3Array([
					_basement_points[_rng.randi_range(0, _basement_points.size() - 1)]])
			return PackedVector3Array([to])
		cultist.position = _basement_points[i] + Vector3(0, 0.2, 0)
		add_child(cultist)
