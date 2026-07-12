class_name TeleportArea
extends Area3D
## The workhorse of every non-euclidean trick: an invisible volume that
## silently relocates the player the moment they step into it.
##
## Two modes:
## - relative_offset: shift the player by a fixed vector. Used for seamless
##   loops — if the geometry at the destination is identical to the geometry
##   here, the player cannot tell they moved.
## - destination_path: path to a Marker3D anywhere in the scene. Used for
##   impossible connections (a basement door that opens into the foyer).
##   A plain NodePath resolved by hand in _ready(), rather than a typed
##   @export var destination: Marker3D — that style only links up correctly
##   when set by dragging a node onto it in the editor's Inspector, and these
##   scenes are hand-authored as text, so it would silently stay unset.
##   Orientation is NOT changed, so place the destination so the player's
##   current walking direction still makes sense when they arrive.

signal triggered

@export var relative_offset := Vector3.ZERO
@export var destination_path: NodePath

var _destination: Marker3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not destination_path.is_empty():
		_destination = get_node(destination_path)


func _on_body_entered(body: Node3D) -> void:
	if not (body is Player):
		return
	if _destination != null:
		body.global_position = _destination.global_position
	else:
		body.global_position += relative_offset
	# Without this, physics interpolation smears the jump across one frame.
	body.reset_physics_interpolation()
	triggered.emit()
