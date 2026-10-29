class_name DoorGuard
extends RefCounted

# A DOOR MAY NOT TURN WHILE AN ACTOR IS IN ITS CELL (every door game: Valet, Dispatch, pneumo,
# Lights Out, taxi, Detour). Turning it under an actor re-routed that actor mid-cell -- it would
# suddenly turn back or jump onto the other branch (user, 2026-10-29).
#
# "In its cell" is generous on purpose: the actor's logical cell, the cell it is moving into, or ANY
# drawn part of it (a train's carts and tail, a creature's body) inside the door's square.

static func occupied(door: Node2D, pos: Vector2i, actors: Array, tile: float) -> bool:
	var half: float = tile * 0.5
	for a in actors:
		if a == null or not is_instance_valid(a) or not (a is Node2D):
			continue
		var n: Node2D = a as Node2D
		if n.get("board_pos") == pos:
			return true
		var tp = n.get("target_position")
		if tp is Vector2 and n.get("set_target_once") != false and _inside(door, n.get_parent().to_global(tp) if n.get_parent() is Node2D else tp, half):
			return true
		if _inside(door, n.global_position, half):
			return true
		for c in n.get_children():
			if c is Node2D and (c as Node2D).visible and _inside(door, (c as Node2D).global_position, half):
				return true
	return false


static func _inside(door: Node2D, gp: Vector2, half: float) -> bool:
	var lp: Vector2 = door.to_local(gp)
	return absf(lp.x) < half and absf(lp.y) < half
