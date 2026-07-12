class_name MazeLib
extends RefCounted
## Pure maze mathematics — no Godot scene nodes in here, just grid data.
## HouseGenerator turns the result into actual geometry.
##
## Algorithm: recursive backtracker (depth-first carve) produces a "perfect"
## maze — exactly one path between any two cells, lots of twisting dead ends,
## no long sightlines. Then two mutations make it a house rather than a
## puzzle: "braiding" knocks down a fraction of extra walls so the maze has
## loops (getting un-lost feels *almost* possible, which is worse), and
## room-carving merges rectangular cell blocks into open rooms.

## Bitmask wall flags per cell. A wall exists between two cells only if BOTH
## agree — carving always clears the flag on both sides.
const N := 1
const E := 2
const S := 4
const W := 8

const OPPOSITE := {N: S, E: W, S: N, W: E}
const DELTA := {N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), W: Vector2i(-1, 0)}

var width: int
var height: int
## walls[y][x] = bitmask of remaining walls around that cell.
var walls: Array = []
## Cells belonging to carved-out rooms: Dictionary[Vector2i -> room index].
var room_of_cell: Dictionary = {}
## One Rect2i per room (in cell coordinates).
var rooms: Array[Rect2i] = []
## Corridor cells with exactly one opening — prime real estate for things
## the player has to walk INTO and then back out of.
var dead_ends: Array[Vector2i] = []

var _rng := RandomNumberGenerator.new()


func generate(w: int, h: int, seed_value: int, room_count: int, braid_fraction: float) -> void:
	width = w
	height = h
	_rng.seed = seed_value
	_carve_perfect_maze()
	_braid(braid_fraction)
	_carve_rooms(room_count)
	_find_dead_ends()


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < width and c.y >= 0 and c.y < height


func wall_at(c: Vector2i, dir: int) -> bool:
	return walls[c.y][c.x] & dir != 0


func is_room(c: Vector2i) -> bool:
	return room_of_cell.has(c)


## Removes the wall between cell c and its neighbor in dir, on both sides.
func carve(c: Vector2i, dir: int) -> void:
	var n: Vector2i = c + DELTA[dir]
	if not in_bounds(n):
		return
	walls[c.y][c.x] &= ~dir
	walls[n.y][n.x] &= ~OPPOSITE[dir]


func random_cell() -> Vector2i:
	return Vector2i(_rng.randi_range(0, width - 1), _rng.randi_range(0, height - 1))


func _carve_perfect_maze() -> void:
	walls.clear()
	for y in height:
		var row: Array[int] = []
		for x in width:
			row.append(N | E | S | W)
		walls.append(row)

	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	visited[Vector2i.ZERO] = true
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[int] = []
		for dir: int in DELTA:
			var next: Vector2i = current + DELTA[dir]
			if in_bounds(next) and not visited.has(next):
				options.append(dir)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen: int = options[_rng.randi_range(0, options.size() - 1)]
		carve(current, chosen)
		var target: Vector2i = current + DELTA[chosen]
		visited[target] = true
		stack.append(target)


## Knock down a fraction of walls at dead ends so the maze contains cycles.
## Cycles are what make players second-guess their mental map: "I've been
## here before... haven't I?"
func _braid(fraction: float) -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if _opening_count(c) != 1:
				continue
			if _rng.randf() > fraction:
				continue
			var sealed: Array[int] = []
			for dir: int in DELTA:
				if wall_at(c, dir) and in_bounds(c + DELTA[dir]):
					sealed.append(dir)
			if not sealed.is_empty():
				carve(c, sealed[_rng.randi_range(0, sealed.size() - 1)])


func _carve_rooms(count: int) -> void:
	var attempts := count * 8
	while rooms.size() < count and attempts > 0:
		attempts -= 1
		var rw := _rng.randi_range(2, 3)
		var rh := _rng.randi_range(2, 3)
		var rx := _rng.randi_range(0, width - rw)
		var ry := _rng.randi_range(0, height - rh)
		var rect := Rect2i(rx, ry, rw, rh)
		var overlaps := false
		for existing in rooms:
			# grow(1) keeps a 1-cell corridor buffer between rooms.
			if existing.grow(1).intersects(rect):
				overlaps = true
				break
		if overlaps:
			continue
		var room_index := rooms.size()
		rooms.append(rect)
		for y in range(ry, ry + rh):
			for x in range(rx, rx + rw):
				var c := Vector2i(x, y)
				room_of_cell[c] = room_index
				# Open everything internal to the room.
				for dir: int in DELTA:
					var n: Vector2i = c + DELTA[dir]
					if rect.has_point(n):
						carve(c, dir)


func _opening_count(c: Vector2i) -> int:
	var open := 0
	for dir: int in DELTA:
		if not wall_at(c, dir) and in_bounds(c + DELTA[dir]):
			open += 1
	return open


func _find_dead_ends() -> void:
	dead_ends.clear()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if not is_room(c) and _opening_count(c) == 1:
				dead_ends.append(c)
