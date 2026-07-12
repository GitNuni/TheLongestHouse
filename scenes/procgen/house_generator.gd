class_name HouseGenerator
extends Node3D
## Builds the entire house at runtime from MazeLib data: geometry, lights,
## doors, props, evidence, pickups, cultists, the looping hallway, phantom
## doors, and the pocket realms. Nothing about the interior is hand-placed;
## every run is a different house.
##
## Design intent (GDD Milestone 5, arriving early): the maze is large and
## braided, so sightlines are short and mental maps fail. Evidence hides in
## dead ends and behind furniture. The impossible parts — the loop hall, the
## phantom doors, the field, the beach — are stitched in through one-way
## teleports, so the house's topology simply does not add up.

signal evidence_logged(count: int, total: int)

const CELL := 4.0
const WALL_H := 3.0
const WALL_T := 0.2

@export var grid_width := 15
@export var grid_height := 15
@export var room_count := 8
@export var braid_fraction := 0.35
@export var evidence_count := 14
@export var ammo_count := 5
@export var cultist_count := 4
## 0 = randomize every run.
@export var maze_seed := 0

var maze := MazeLib.new()
var player_spawn := Vector3.ZERO
var evidence_total := 0
var evidence_found := 0

var _astar := AStar2D.new()
var _rng := RandomNumberGenerator.new()
var _furnisher: Furnisher
var _room_types: Array[Furnisher.RoomType] = []
var _mat_walls: Array[StandardMaterial3D] = []
var _mat_wainscot: StandardMaterial3D
var _mat_rail: StandardMaterial3D
var _mat_floor: StandardMaterial3D
var _mat_ceiling: StandardMaterial3D
var _mat_trim: StandardMaterial3D
var _mat_black: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _free_dead_ends: Array[Vector2i] = []
var _loop_occupied := false
var _loop_count := 0
var _loop_exit_open := false
var _loop_origin := Vector3.ZERO
## Impossible doors are numbered in build order, starting at 2 — the front
## door is room 1.
var _door_number := 2


func _ready() -> void:
	var seed_value := maze_seed if maze_seed != 0 else randi()
	_rng.seed = seed_value
	maze.generate(grid_width, grid_height, seed_value, room_count, braid_fraction)
	_free_dead_ends = maze.dead_ends.duplicate()

	_furnisher = Furnisher.new(_rng, self)
	_assign_room_types()
	_make_materials()
	_build_pathfinding()
	_build_geometry()
	_build_room_contents()
	_place_evidence()
	_place_ammo()
	_build_loop_hallway()
	_build_phantom_doors()
	_build_pocket_realms()
	_spawn_cultists()

	var spawn_cell := Vector2i(grid_width / 2, grid_height - 1)
	player_spawn = cell_center(spawn_cell)
	evidence_logged.emit(0, evidence_total)


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0, (c.y + 0.5) * CELL)


func world_to_cell(v: Vector3) -> Vector2i:
	return Vector2i(clampi(int(v.x / CELL), 0, grid_width - 1),
			clampi(int(v.z / CELL), 0, grid_height - 1))


## World-space waypoints between two positions, following maze corridors.
## A target of Vector3.ZERO means "somewhere random" (cultist patrol).
func find_path(from_world: Vector3, to_world: Vector3) -> PackedVector3Array:
	var from_cell := world_to_cell(from_world)
	var to_cell := world_to_cell(to_world)
	if to_world == Vector3.ZERO:
		to_cell = maze.random_cell()
	var cell_path := _astar.get_point_path(_cell_id(from_cell), _cell_id(to_cell))
	var points := PackedVector3Array()
	for p in cell_path:
		points.append(Vector3((p.x + 0.5) * CELL, 0, (p.y + 0.5) * CELL))
	return points


func random_corridor_position_near(origin: Vector3, min_m: float, max_m: float) -> Vector3:
	for _attempt in 24:
		var c := maze.random_cell()
		var pos := cell_center(c)
		var d := pos.distance_to(origin)
		if d >= min_m and d <= max_m:
			return pos
	return cell_center(maze.random_cell())


func _cell_id(c: Vector2i) -> int:
	return c.y * grid_width + c.x


## How deep into the house a cell sits, 0 at the front door (south edge,
## where the player spawns) to 1 at the far north. Drives the No-End House
## gradient: rooms near the entrance are almost normal; deep rooms are not.
func _wrongness_at(c: Vector2i) -> float:
	return clampf(1.0 - float(c.y) / float(grid_height - 1), 0.0, 1.0)


func _assign_room_types() -> void:
	var pool: Array[Furnisher.RoomType] = [
		Furnisher.RoomType.LIVING, Furnisher.RoomType.KITCHEN,
		Furnisher.RoomType.DINING, Furnisher.RoomType.BEDROOM,
		Furnisher.RoomType.BATH, Furnisher.RoomType.STUDY,
		Furnisher.RoomType.NURSERY, Furnisher.RoomType.BEDROOM,
	]
	for i in maze.rooms.size():
		_room_types.append(pool[i % pool.size()])
	# Fisher-Yates with the run's own rng, so the layout stays seed-stable.
	for i in range(_room_types.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := _room_types[i]
		_room_types[i] = _room_types[j]
		_room_types[j] = swap
	# The deepest room is always the chair room. A chair. A lamp.
	# The wrong number of shadows. (If you know, you know.)
	var deepest := 0
	var best_y := grid_height
	for i in maze.rooms.size():
		var mid_y := maze.rooms[i].position.y + maze.rooms[i].size.y / 2
		if mid_y < best_y:
			best_y = mid_y
			deepest = i
	if not _room_types.is_empty():
		_room_types[deepest] = Furnisher.RoomType.CHAIR


func _make_materials() -> void:
	# Wallpaper in four near-identical faded-domestic tints assigned by
	# location hash. The eye can't name the difference, but rooms feel subtly
	# discontinuous — wrongness below the threshold of articulation.
	for tint: Color in [Color(0.58, 0.52, 0.42), Color(0.55, 0.5, 0.46),
			Color(0.52, 0.54, 0.46), Color(0.57, 0.48, 0.44)]:
		_mat_walls.append(BuildUtil.material(tint, 0.9))
	_mat_wainscot = BuildUtil.material(Color(0.3, 0.22, 0.16), 0.8)
	_mat_rail = BuildUtil.material(Color(0.36, 0.27, 0.2), 0.75)
	_mat_floor = BuildUtil.material(Color(0.33, 0.24, 0.16), 0.7)
	_mat_ceiling = BuildUtil.material(Color(0.5, 0.48, 0.44), 0.95)
	_mat_trim = BuildUtil.material(Color(0.28, 0.21, 0.16), 0.85)
	_mat_black = BuildUtil.material(Color(0.015, 0.015, 0.02), 1.0)
	_mat_glass = BuildUtil.material(Color(0.03, 0.04, 0.06), 0.05,
			Color(0.05, 0.08, 0.12), 0.15)


func _build_pathfinding() -> void:
	for y in grid_height:
		for x in grid_width:
			var c := Vector2i(x, y)
			_astar.add_point(_cell_id(c), Vector2(c))
	for y in grid_height:
		for x in grid_width:
			var c := Vector2i(x, y)
			if not maze.wall_at(c, MazeLib.E) and x + 1 < grid_width:
				_astar.connect_points(_cell_id(c), _cell_id(c + Vector2i(1, 0)))
			if not maze.wall_at(c, MazeLib.S) and y + 1 < grid_height:
				_astar.connect_points(_cell_id(c), _cell_id(c + Vector2i(0, 1)))


func _wall_material(c: Vector2i) -> StandardMaterial3D:
	return _mat_walls[(c.x * 7 + c.y * 13) % _mat_walls.size()]


func _build_geometry() -> void:
	for y in grid_height:
		for x in grid_width:
			var c := Vector2i(x, y)
			var center := cell_center(c)
			var floor_mat := _mat_floor
			if maze.is_room(c):
				floor_mat = _furnisher.floor_material(_room_types[maze.room_of_cell[c]])
			BuildUtil.box(self, center + Vector3(0, -0.05, 0),
					Vector3(CELL, 0.1, CELL), floor_mat, true)
			BuildUtil.box(self, center + Vector3(0, WALL_H + 0.05, 0),
					Vector3(CELL, 0.1, CELL), _mat_ceiling, true)
			# North + West walls per cell; South/East come from neighbors,
			# plus the outer boundary rows below. Outer walls get an
			# inner-facing normal so they can grow windows.
			if maze.wall_at(c, MazeLib.N):
				_build_wall(center + Vector3(0, 0, -CELL / 2.0), true, c,
						Vector3(0, 0, 1) if y == 0 else Vector3.ZERO)
			if maze.wall_at(c, MazeLib.W):
				_build_wall(center + Vector3(-CELL / 2.0, 0, 0), false, c,
						Vector3(1, 0, 0) if x == 0 else Vector3.ZERO)
			if y == grid_height - 1 and maze.wall_at(c, MazeLib.S):
				_build_wall(center + Vector3(0, 0, CELL / 2.0), true, c,
						Vector3(0, 0, -1))
			if x == grid_width - 1 and maze.wall_at(c, MazeLib.E):
				_build_wall(center + Vector3(CELL / 2.0, 0, 0), false, c,
						Vector3(-1, 0, 0))

	_place_lights()
	_place_doors()
	_decorate_corridors()


## Two-tone house wall: dark wainscot below, wallpaper above, chair rail
## between — the single strongest "this is a home" visual cue. Outer walls
## (inner_normal set) sometimes grow a window looking out onto nothing.
func _build_wall(pos: Vector3, along_x: bool, c: Vector2i,
		inner_normal := Vector3.ZERO) -> void:
	var length := CELL + WALL_T
	var wainscot_size := Vector3(length, 1.0, WALL_T + 0.04) if along_x \
			else Vector3(WALL_T + 0.04, 1.0, length)
	var paper_size := Vector3(length, WALL_H - 1.0, WALL_T) if along_x \
			else Vector3(WALL_T, WALL_H - 1.0, length)
	var rail_size := Vector3(length, 0.07, WALL_T + 0.07) if along_x \
			else Vector3(WALL_T + 0.07, 0.07, length)
	BuildUtil.box(self, pos + Vector3(0, 0.5, 0), wainscot_size, _mat_wainscot, true)
	BuildUtil.box(self, pos + Vector3(0, (WALL_H + 1.0) / 2.0, 0), paper_size,
			_wall_material(c), true)
	BuildUtil.box(self, pos + Vector3(0, 1.02, 0), rail_size, _mat_rail)

	if inner_normal != Vector3.ZERO and _rng.randf() < 0.35:
		_build_window(pos + inner_normal * (WALL_T / 2.0 + 0.04), along_x)


## A window on an outer wall. The glass is near-black with the faintest cold
## sheen: there is an outside, and it has nothing in it.
func _build_window(pos: Vector3, along_x: bool) -> void:
	var center := pos + Vector3(0, 1.55, 0)
	var pane_size := Vector3(1.3, 1.0, 0.04) if along_x else Vector3(0.04, 1.0, 1.3)
	BuildUtil.box(self, center, pane_size, _mat_glass)
	var bar_h := Vector3(1.46, 0.08, 0.07) if along_x else Vector3(0.07, 0.08, 1.46)
	var bar_v := Vector3(0.08, 1.16, 0.07) if along_x else Vector3(0.07, 1.16, 0.08)
	BuildUtil.box(self, center + Vector3(0, 0.54, 0), bar_h, _mat_trim)
	BuildUtil.box(self, center + Vector3(0, -0.54, 0), bar_h, _mat_trim)
	var side := Vector3(0.69, 0, 0) if along_x else Vector3(0, 0, 0.69)
	BuildUtil.box(self, center + side, bar_v, _mat_trim)
	BuildUtil.box(self, center - side, bar_v, _mat_trim)
	BuildUtil.box(self, center, bar_v, _mat_trim)


func _place_lights() -> void:
	# Moody, not dark: rooms always lit, corridors lit every other cell so
	# the house reads clearly — dread comes from what the light shows and
	# how it behaves, not from squinting. Deeper cells burn colder and less
	# reliably (the No-End gradient again).
	for i in maze.rooms.size():
		var room := maze.rooms[i]
		if _room_types[i] == Furnisher.RoomType.CHAIR:
			continue  # the chair room lights itself — one corner lamp only
		var mid := Vector3((room.position.x + room.size.x / 2.0) * CELL, WALL_H - 0.3,
				(room.position.y + room.size.y / 2.0) * CELL)
		_ceiling_fixture(mid, Color(1.0, 0.88, 0.72), 1.5, 8.5,
				_rng.randf_range(0.08, 0.3), _rng.randf_range(16.0, 32.0))
	for y in grid_height:
		for x in grid_width:
			var c := Vector2i(x, y)
			if maze.is_room(c):
				continue
			if (x + y) % 2 != 0:
				continue
			var wrong := _wrongness_at(c)
			_ceiling_fixture(cell_center(c) + Vector3(0, WALL_H - 0.3, 0),
					Color(1.0, lerpf(0.88, 0.8, wrong), lerpf(0.72, 0.62, wrong)),
					lerpf(1.35, 1.0, wrong), 6.5,
					lerpf(0.1, 0.45, wrong) * _rng.randf_range(0.7, 1.3),
					lerpf(34.0, 11.0, wrong))


## A light plus its physical fixture — a ceiling rose and a glowing bulb —
## so illumination has a visible source instead of hanging in the air.
func _ceiling_fixture(pos: Vector3, color: Color, energy: float, range_m: float,
		flicker: float, blackout_interval: float) -> void:
	BuildUtil.box(self, pos + Vector3(0, 0.24, 0), Vector3(0.34, 0.05, 0.34), _mat_trim)
	BuildUtil.box(self, pos + Vector3(0, 0.12, 0), Vector3(0.11, 0.2, 0.11),
			BuildUtil.material(Color(0.9, 0.86, 0.74), 0.6, Color(1.0, 0.9, 0.7), 1.4))
	BuildUtil.haunt_light(self, pos, color, energy, range_m, flicker, blackout_interval)


## Runners, crooked pictures — the corridor half of the anti-Backrooms work.
func _decorate_corridors() -> void:
	var runner := BuildUtil.material(Color(0.34, 0.15, 0.13), 1.0)
	var frame_wood := BuildUtil.material(Color(0.32, 0.24, 0.16), 0.8)
	var print_dark := BuildUtil.material(Color(0.12, 0.11, 0.1), 0.9)
	for y in grid_height:
		for x in grid_width:
			var c := Vector2i(x, y)
			if maze.is_room(c):
				continue
			var center := cell_center(c)
			if _rng.randf() < 0.4:
				BuildUtil.box(self, center + Vector3(0, 0.012, 0),
						Vector3(2.2, 0.02, 3.1), runner)
			if _rng.randf() < 0.3:
				for dir: int in MazeLib.DELTA:
					if not maze.wall_at(c, dir):
						continue
					var n: Vector2i = MazeLib.DELTA[dir]
					var wall_pos := center + Vector3(n.x, 0, n.y) \
							* (CELL / 2.0 - WALL_T / 2.0 - 0.06)
					var holder := Node3D.new()
					holder.position = wall_pos + Vector3(0, 1.6, 0)
					if n.x != 0:
						holder.rotation.y = PI / 2.0
					holder.rotation.z = _rng.randf_range(-0.09, 0.09)
					add_child(holder)
					BuildUtil.box(holder, Vector3.ZERO, Vector3(0.55, 0.7, 0.05),
							frame_wood)
					BuildUtil.box(holder, Vector3(0, 0, 0.012),
							Vector3(0.44, 0.58, 0.04), print_dark)
					break


func _place_doors() -> void:
	# Hinged doors on some room entrances. Maze openings are a full cell
	# (4 m) wide, so each door gets jamb walls narrowing the gap to a 1 m
	# doorway first. Doors open themselves when approached; the
	# HauntDirector slams them later.
	for room in maze.rooms:
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var c := Vector2i(x, y)
				for dir: int in MazeLib.DELTA:
					var n: Vector2i = c + MazeLib.DELTA[dir]
					if maze.wall_at(c, dir) or not maze.in_bounds(n):
						continue
					if maze.is_room(n) or _rng.randf() > 0.5:
						continue
					_build_doorway(cell_center(c), MazeLib.DELTA[dir], c)


## Narrows a 4 m cell-boundary opening down to a 1 m doorway (two jamb
## walls + header) and hangs a HauntedDoor in it.
func _build_doorway(center: Vector3, offset: Vector2i, c: Vector2i) -> void:
	var boundary := center + Vector3(offset.x, 0, offset.y) * (CELL / 2.0)
	var mat := _wall_material(c)
	var door := HauntedDoor.new()
	if offset.y != 0:
		# Boundary wall runs along X.
		for side: float in [-1.45, 1.45]:
			BuildUtil.box(self, boundary + Vector3(side, WALL_H / 2.0, 0),
					Vector3(1.6, WALL_H, WALL_T), mat, true)
		BuildUtil.box(self, boundary + Vector3(0, 2.52, 0),
				Vector3(1.4, WALL_H - 2.05, WALL_T), mat, true)
		door.position = boundary + Vector3(-0.5, 0, 0)
		door.rotation.y = 0.0
	else:
		# Boundary wall runs along Z.
		for side: float in [-1.45, 1.45]:
			BuildUtil.box(self, boundary + Vector3(0, WALL_H / 2.0, side),
					Vector3(WALL_T, WALL_H, 1.6), mat, true)
		BuildUtil.box(self, boundary + Vector3(0, 2.52, 0),
				Vector3(WALL_T, WALL_H - 2.05, 1.4), mat, true)
		door.position = boundary + Vector3(0, 0, -0.5)
		door.rotation.y = -PI / 2.0
	add_child(door)


func _build_room_contents() -> void:
	for i in maze.rooms.size():
		var room := maze.rooms[i]
		var origin := Vector3(room.position.x * CELL, 0, room.position.y * CELL)
		var span := Vector3(room.size.x * CELL, 0, room.size.y * CELL)
		var mid_cell := Vector2i(room.position.x + room.size.x / 2,
				room.position.y + room.size.y / 2)
		_furnisher.furnish(_room_types[i], origin, span, _wrongness_at(mid_cell))


func _take_dead_end() -> Vector2i:
	if _free_dead_ends.is_empty():
		return maze.random_cell()
	var i := _rng.randi_range(0, _free_dead_ends.size() - 1)
	var c: Vector2i = _free_dead_ends[i]
	_free_dead_ends.remove_at(i)
	return c


func _place_evidence() -> void:
	evidence_total = evidence_count
	for i in evidence_count:
		var evidence := Evidence.new()
		evidence.kind = (i % Evidence.Kind.size()) as Evidence.Kind
		var c := _take_dead_end()
		# Tucked toward a sealed corner of the dead end, near the floor —
		# visible only once you've fully committed to walking in.
		var center := cell_center(c)
		evidence.position = center + Vector3(_rng.randf_range(-1.2, 1.2), 0.02,
				_rng.randf_range(-1.2, 1.2))
		evidence.logged.connect(_on_evidence_logged)
		add_child(evidence)


func _on_evidence_logged(_evidence: Evidence) -> void:
	evidence_found += 1
	evidence_logged.emit(evidence_found, evidence_total)


func _place_ammo() -> void:
	var brass := BuildUtil.material(Color(0.65, 0.5, 0.25), 0.3, Color(0.8, 0.6, 0.2), 0.15)
	for _i in ammo_count:
		var c := maze.random_cell()
		var holder := Node3D.new()
		holder.position = cell_center(c) + Vector3(_rng.randf_range(-1.0, 1.0), 0,
				_rng.randf_range(-1.0, 1.0))
		add_child(holder)
		BuildUtil.box(holder, Vector3(0, 0.06, 0), Vector3(0.22, 0.12, 0.14), brass)
		BuildUtil.trigger(holder, Vector3(0, 0.5, 0), Vector3(1.2, 1.6, 1.2),
				func(body: Player) -> void:
					body.add_ammo(6)
					holder.queue_free())


func _spawn_cultists() -> void:
	# Deferred: the player node registers itself with the generator after
	# scene setup; cultists need that reference.
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	for _i in cultist_count:
		var cultist := Cultist.new()
		cultist.player = player
		cultist.find_path = find_path
		var pos := random_corridor_position_near(player_spawn, 20.0, 80.0)
		cultist.position = pos + Vector3(0, 0.2, 0)
		add_child(cultist)


## ----- The Long Hall (marker: looping hallway, one occupant at a time) ----


func _build_loop_hallway() -> void:
	# Built far outside the maze; reachable only by teleport. Segments are
	# identical, so the two shift-triggers are invisible seams. After three
	# full loops the far end stops looping and an exit door appears-ish
	# (starts working). The entry refuses a second occupant while someone is
	# inside — in co-op this becomes a per-player experience by design.
	_loop_origin = Vector3(-40.0, 0, -20.0)
	var segments := 10
	for i in segments:
		var base := _loop_origin + Vector3(0, 0, -4.0 * i)
		BuildUtil.box(self, base + Vector3(0, -0.05, -2), Vector3(2.4, 0.1, 4),
				_mat_floor, true)
		BuildUtil.box(self, base + Vector3(0, WALL_H + 0.05, -2), Vector3(2.4, 0.1, 4),
				_mat_ceiling, true)
		BuildUtil.box(self, base + Vector3(-1.25, WALL_H / 2.0, -2),
				Vector3(0.1, WALL_H, 4), _mat_walls[0], true)
		BuildUtil.box(self, base + Vector3(1.25, WALL_H / 2.0, -2),
				Vector3(0.1, WALL_H, 4), _mat_walls[0], true)
		BuildUtil.box(self, base + Vector3(-1.0, 1.05, 0), Vector3(0.4, 2.1, 0.2),
				_mat_trim, true)
		BuildUtil.box(self, base + Vector3(1.0, 1.05, 0), Vector3(0.4, 2.1, 0.2),
				_mat_trim, true)
		BuildUtil.box(self, base + Vector3(0, 2.5, 0), Vector3(2.4, 1.0, 0.2),
				_mat_trim, true)
		BuildUtil.haunt_light(self, base + Vector3(0, 2.6, -2),
				Color(1.0, 0.85, 0.65), 0.9, 5.0, 0.3, 16.0)
	# End caps: you teleported in; there is no way out but the trick.
	BuildUtil.box(self, _loop_origin + Vector3(0, WALL_H / 2.0, 0.15),
			Vector3(2.8, WALL_H, 0.3), _mat_black, true)
	BuildUtil.box(self, _loop_origin + Vector3(0, WALL_H / 2.0, -40.15),
			Vector3(2.8, WALL_H, 0.3), _mat_black, true)

	# Deep trigger: shift back 16 m, count the loop.
	BuildUtil.trigger(self, _loop_origin + Vector3(0, 1.3, -30.0),
			Vector3(2.4, 2.6, 0.4), _on_loop_deep)
	# Entrance-side trigger: shift deeper (endless both ways until released).
	BuildUtil.trigger(self, _loop_origin + Vector3(0, 1.3, -6.0),
			Vector3(2.4, 2.6, 0.4), _on_loop_shallow)
	# Exit trigger sits past the deep trigger; only works once released.
	BuildUtil.trigger(self, _loop_origin + Vector3(0, 1.3, -38.5),
			Vector3(2.4, 2.6, 0.6), _on_loop_exit)

	# Entry: a phantom-style dark door at a dead end in the maze.
	var entry_cell := _take_dead_end()
	_build_dark_doorframe(cell_center(entry_cell), _on_loop_enter)


func _on_loop_enter(player: Player) -> void:
	if _loop_occupied:
		# The hall admits one guest at a time. The door is just a door today.
		return
	_loop_occupied = true
	_loop_count = 0
	_loop_exit_open = false
	# Yaw 0 faces -Z: straight down the corridor, away from the sealed cap.
	_teleport(player, _loop_origin + Vector3(0, 0.1, -2.0), 0.0)


## Safety valve: if the occupant dies (or anything else yanks them out), the
## hall must not stay locked forever.
func release_loop() -> void:
	_loop_occupied = false


func _on_loop_deep(player: Player) -> void:
	if _loop_exit_open:
		return
	_loop_count += 1
	if _loop_count >= 3:
		_loop_exit_open = true
		return
	player.global_position.z += 16.0
	player.reset_physics_interpolation()


func _on_loop_shallow(player: Player) -> void:
	player.global_position.z -= 16.0
	player.reset_physics_interpolation()


func _on_loop_exit(player: Player) -> void:
	if not _loop_exit_open:
		return
	_loop_occupied = false
	var out_cell := _take_dead_end()
	_teleport(player, cell_center(out_cell) + Vector3(0, 0.1, 0), 0.0)


## ----- Phantom doors (marker: doors that are gone when you turn around) ---


func _build_phantom_doors() -> void:
	for _i in 5:
		var c := _take_dead_end()
		_build_dark_doorframe(cell_center(c), func(player: Player) -> void:
			var dest := _take_dead_end()
			_free_dead_ends.append(c)  # the door "moves on" — cell reusable
			_teleport(player, cell_center(dest) + Vector3(0, 0.1, 0),
					_rng.randf_range(0.0, TAU)))


## A doorframe with a lightless void where the panel should be. Stepping in
## fires `callable`. There is never a matching door where you come out.
##
## Every impossible door carries a number, scrawled and slightly crooked —
## they count upward as the generator builds them, and where the count ends
## is the house's little joke (readers of a certain story will know).
func _build_dark_doorframe(center: Vector3, callable: Callable) -> void:
	var holder := Node3D.new()
	holder.position = center + Vector3(0, 0, -1.5)
	add_child(holder)
	BuildUtil.box(holder, Vector3(-0.55, 1.05, 0), Vector3(0.3, 2.1, 0.25), _mat_trim, true)
	BuildUtil.box(holder, Vector3(0.55, 1.05, 0), Vector3(0.3, 2.1, 0.25), _mat_trim, true)
	BuildUtil.box(holder, Vector3(0, 2.25, 0), Vector3(1.4, 0.3, 0.25), _mat_trim, true)
	BuildUtil.box(holder, Vector3(0, 1.05, 0.08), Vector3(0.8, 2.1, 0.05), _mat_black)
	var numeral := Label3D.new()
	numeral.text = str(_door_number)
	_door_number += 1
	numeral.font_size = 220
	numeral.modulate = Color(0.5, 0.12, 0.1)
	numeral.position = Vector3(0, 1.7, 0.15)
	numeral.rotation.z = _rng.randf_range(-0.12, 0.12)
	holder.add_child(numeral)
	BuildUtil.trigger(holder, Vector3(0, 1.05, 0), Vector3(0.8, 2.1, 0.3), callable)


func _teleport(player: Player, to: Vector3, yaw: float) -> void:
	player.global_position = to
	player.rotation.y = yaw
	player.reset_physics_interpolation()
	player.play_static_blip()


## ----- Pocket realms (marker: rooms that are not rooms) --------------------


func _build_pocket_realms() -> void:
	_build_field()
	_build_beach()
	_build_forest()
	_build_lobby_sign()


## The sign at the front door. Cheerful. Unsigned. Load-bearing.
func _build_lobby_sign() -> void:
	var spawn_cell := Vector2i(grid_width / 2, grid_height - 1)
	var sign := Label3D.new()
	sign.text = "ROOM 1 THIS WAY.\nEIGHT MORE FOLLOW.\nREACH THE END AND YOU WIN!"
	sign.font_size = 60
	sign.modulate = Color(0.8, 0.76, 0.66)
	sign.position = cell_center(spawn_cell) + Vector3(0, 1.9, -1.6)
	add_child(sign)


## Room five: trees grown INTO the house. No walls in sight, birdsong and
## insects you can hear but never see — and the floor is still, undeniably,
## the same wood paneling as the rest of the house. You never left.
func _build_forest() -> void:
	var origin := Vector3(-600, 0, 300)
	# The floor matching the house is the whole trick — same material.
	BuildUtil.box(self, origin + Vector3(0, -0.1, 0), Vector3(90, 0.2, 90),
			_mat_floor, true)
	var bark := BuildUtil.material(Color(0.25, 0.2, 0.15), 0.95)
	var canopy := BuildUtil.material(Color(0.07, 0.12, 0.06), 1.0)
	for _i in 28:
		var pos := origin + Vector3(_rng.randf_range(-40, 40), 0,
				_rng.randf_range(-40, 40))
		if pos.distance_to(origin) < 6.0:
			continue
		var trunk_h := _rng.randf_range(3.0, 4.5)
		BuildUtil.box(self, pos + Vector3(0, trunk_h / 2.0, 0),
				Vector3(0.4, trunk_h, 0.4), bark, true)
		BuildUtil.box(self, pos + Vector3(0, trunk_h + 0.8, 0),
				Vector3(_rng.randf_range(2.2, 3.6), 1.6, _rng.randf_range(2.2, 3.6)),
				canopy)
	var bugs := BuildUtil.speaker(self, origin + Vector3(0, 2, 0),
			AudioBank.crickets, -10.0, 120.0)
	bugs.play()

	# A dim lamp hangs where no ceiling is, over the way back.
	var frame_pos := origin + Vector3(0, 0, -25)
	_build_dark_doorframe(frame_pos + Vector3(0, 0, 1.5), func(player: Player) -> void:
		var dest := _take_dead_end()
		_teleport(player, cell_center(dest) + Vector3(0, 0.1, 0), 0.0))
	BuildUtil.haunt_light(self, frame_pos + Vector3(0, 3.2, -1.5),
			Color(0.95, 0.9, 0.75), 1.3, 10.0, 0.2, 40.0)

	var entry := _take_dead_end()
	_build_dark_doorframe(cell_center(entry), func(player: Player) -> void:
		_teleport(player, origin + Vector3(0, 0.1, 8), 0.0))


func _build_field() -> void:
	# An open field at night. Endless flat dark, one doorway standing alone,
	# lit. There is nothing else here. That is the entire point.
	var origin := Vector3(600, 0, 0)
	var grass := BuildUtil.material(Color(0.08, 0.11, 0.07), 1.0)
	BuildUtil.box(self, origin + Vector3(0, -0.1, 0), Vector3(240, 0.2, 240), grass, true)
	var shrub := BuildUtil.material(Color(0.05, 0.07, 0.05), 1.0)
	for _i in 40:
		BuildUtil.box(self, origin + Vector3(_rng.randf_range(-110, 110),
				_rng.randf_range(0.15, 0.4), _rng.randf_range(-110, 110)),
				Vector3(_rng.randf_range(0.4, 1.4), _rng.randf_range(0.3, 0.9),
				_rng.randf_range(0.4, 1.4)), shrub)
	var wind_speaker := BuildUtil.speaker(self, origin + Vector3(0, 2, 0),
			AudioBank.wind, -6.0, 200.0)
	wind_speaker.play()

	# The way back: a lone doorframe, the only light for a hundred meters.
	var frame_pos := origin + Vector3(0, 0, -20)
	_build_dark_doorframe(frame_pos + Vector3(0, 0, 1.5), func(player: Player) -> void:
		var dest := _take_dead_end()
		_teleport(player, cell_center(dest) + Vector3(0, 0.1, 0), 0.0))
	BuildUtil.haunt_light(self, frame_pos + Vector3(0, 2.6, -1.5),
			Color(0.9, 0.85, 0.7), 1.4, 9.0, 0.15, 45.0)

	# Entry from the maze.
	var entry := _take_dead_end()
	_build_dark_doorframe(cell_center(entry), func(player: Player) -> void:
		# Arrive 25 m from the lit doorframe, facing it across the dark.
		_teleport(player, origin + Vector3(0, 0.1, 5), 0.0))


func _build_beach() -> void:
	# A shoreline under no moon. The sea is a faint luminous line that never
	# moves. A door stands in the sand.
	var origin := Vector3(600, 0, 600)
	var sand := BuildUtil.material(Color(0.28, 0.25, 0.19), 0.95)
	BuildUtil.box(self, origin + Vector3(0, -0.1, 20), Vector3(200, 0.2, 60), sand, true)
	var sea := BuildUtil.material(Color(0.02, 0.05, 0.08), 0.1,
			Color(0.1, 0.25, 0.35), 0.25)
	BuildUtil.box(self, origin + Vector3(0, -0.25, -60), Vector3(200, 0.1, 100), sea, true)
	# Horizon glow: a dim distant band where sea meets nothing.
	var glow := BuildUtil.material(Color(0.02, 0.03, 0.05), 1.0,
			Color(0.2, 0.3, 0.4), 0.5)
	BuildUtil.box(self, origin + Vector3(0, 1.5, -108), Vector3(200, 3, 0.5), glow)
	var wind_speaker := BuildUtil.speaker(self, origin + Vector3(0, 2, 10),
			AudioBank.wind, -4.0, 200.0)
	wind_speaker.pitch_scale = 0.7
	wind_speaker.play()

	var frame_pos := origin + Vector3(8, 0, 30)
	_build_dark_doorframe(frame_pos, func(player: Player) -> void:
		var dest := _take_dead_end()
		_teleport(player, cell_center(dest) + Vector3(0, 0.1, 0), 0.0))
	BuildUtil.haunt_light(self, frame_pos + Vector3(0, 2.6, -1.5),
			Color(0.9, 0.85, 0.7), 1.2, 8.0, 0.2, 60.0)

	var entry := _take_dead_end()
	_build_dark_doorframe(cell_center(entry), func(player: Player) -> void:
		_teleport(player, origin + Vector3(0, 0.1, 40), 0.0))
