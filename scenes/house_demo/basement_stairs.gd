extends Node3D
## The basement stairs that go down much, much too far.
##
## Six real flights exist. A TeleportArea partway down silently lifts the
## player back up two flights each time they pass it, so the descent repeats.
## After MAX_LOOPS descents the loop switches off and the player finally
## reaches the real bottom — and what's waiting down there.

const MAX_LOOPS := 7

var _descents := 0

@onready var _loop_trigger: TeleportArea = $LoopTrigger


func _on_loop_trigger_triggered() -> void:
	_descents += 1
	if _descents >= MAX_LOOPS:
		# set_deferred because we're inside this trigger's own signal callback;
		# flipping monitoring mid-callback is not allowed by the physics server.
		_loop_trigger.set_deferred("monitoring", false)
