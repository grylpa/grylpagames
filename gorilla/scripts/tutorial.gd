extends RefCounted

# Gorilla's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Gorilla player actually gets wrong, in order of damage:
#   1. They treat it as a coin-collecting game and simply do not notice the gorillas, because
#      nothing on screen ever asks them to look. Then the count question at the end arrives out
#      of nowhere.
#   2. A gorilla runs the whole way across in a few seconds. A player who is reading a caption
#      misses it entirely and has no idea what they were meant to be looking at — so the tutorial
#      does NOT rely on catching one in flight. It holds one still in the center of its lane
#      (level.tutorial_hold_gorilla_midscreen) and points at it while the game is frozen.
#   3. Monsters. They are switched off for the whole tutorial (num_inside_monsters = 0) so nobody
#      is killed halfway through a lesson — but a player who is never shown one meets their first
#      at full speed with no warning, which is the very complaint tutorials exist to fix. So one
#      is spawned on the last teaching step, named, and pointed at, with the game frozen.
#   4. Movement, which is announced nowhere. This game does NOT have the drawn-path movement
#      wolves and storm use (MainGlobals.draw_path_mode is never set here): a quick swipe sets a
#      direction and you keep walking that way until you turn or stop. Saying "draw a path" here
#      would be plainly wrong, and "flick" on its own means nothing to most people.
#
# Monsters are switched off (num_inside_monsters = 0) and two gorillas are scheduled early — see
# level.gd's _tutorial_setup. Being killed halfway through a lesson teaches nothing.

const LEVEL_ID: int = 1

static func tutorial_level_id() -> int:
	return LEVEL_ID

# A TIGHT rect around a thing, measured from what is actually on screen.
#
# The overlay's `spot_radius` is a number of SCREEN units, and everything in this game is drawn
# through a camera that zooms (`create_camera(min(2.0, 1.0 / board_part_of_width))`). So no
# authored literal can be right: the same 70 is snug at one zoom and a halo the size of the wall
# at another, which is why every frame in this tutorial read as "look over there" rather than
# "look at this".
#
# `spot` also accepts a Callable returning a Rect2, and _rect_for() hands that straight back. So
# the size comes from the node's own sprites, put through the same canvas transform the player
# sees, and the zoom cancels out on its own.
static func _tight(pick: Callable, pad: float = 6.0) -> Callable:
	return func():
		var n: Node = pick.call()
		if n == null or not is_instance_valid(n) or not (n is CanvasItem):
			return null
		var xf: Transform2D = (n as CanvasItem).get_global_transform_with_canvas()
		var half: Vector2 = _visual_half(n)
		if half == Vector2.ZERO:
			return null
		var sc: Vector2 = xf.get_scale().abs()
		var ext: Vector2 = Vector2(half.x * sc.x, half.y * sc.y) + Vector2(pad, pad)
		return Rect2(xf.origin - ext, ext * 2.0)

# Half the extent of a node's own drawn sprites, in ITS local units. Walked rather than asked of
# the node, because the player is an Area2D whose picture lives in a child and an Area2D has no
# size of its own.
static func _visual_half(n: Node) -> Vector2:
	# A node that DRAWS itself knows its own extent and nothing else can work it out: the
	# peripheral gorilla is a bare Node2D whose every part comes off `body_height`, so it had no
	# sprite to measure and got no frame at all.
	if n.has_method("visual_half"):
		return n.call("visual_half")
	var best: Vector2 = _sprite_half(n)
	for c: Node in n.get_children():
		var h: Vector2 = _sprite_half(c)
		if h != Vector2.ZERO:
			var cs0: Vector2 = (c as Node2D).scale.abs() if c is Node2D else Vector2.ONE
			h = Vector2(h.x * cs0.x, h.y * cs0.y)
			best = Vector2(maxf(best.x, h.x), maxf(best.y, h.y))
		else:
			var deeper: Vector2 = _visual_half(c)
			if c is Node2D:
				var ds: Vector2 = (c as Node2D).scale.abs()
				deeper = Vector2(deeper.x * ds.x, deeper.y * ds.y)
			best = Vector2(maxf(best.x, deeper.x), maxf(best.y, deeper.y))
	return best

# Half of ONE node's own picture, if it has one. Sprite2D has get_rect(); AnimatedSprite2D does
# NOT — its size is the current frame's texture. Asking both the same question is what made every
# spot fall back to nothing on the first attempt. Measured on the node ITSELF, so a sprite handed
# over directly is measurable too and not just one nested in a parent.
static func _sprite_half(n: Node) -> Vector2:
	if n is Sprite2D:
		return (n as Sprite2D).get_rect().size * 0.5
	if n is AnimatedSprite2D:
		var a: AnimatedSprite2D = n as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) \
				and a.sprite_frames.get_frame_count(a.animation) > 0:
			var tex: Texture2D = a.sprite_frames.get_frame_texture(a.animation,
				mini(a.frame, a.sprite_frames.get_frame_count(a.animation) - 1))
			if tex != null:
				return tex.get_size() * 0.5
	return Vector2.ZERO

static func steps(level: Node, _game) -> Array:
	var player_spot: Callable = _tight(func():
		return level.player if level.player != null and is_instance_valid(level.player) else null)
	var gorilla_spot: Callable = _tight(func():
		for g in level.peripheral_gorillas:
			if is_instance_valid(g):
				return g
		return null)
	# A REAL super-food on the board, pointed at through its own sprite. The step used to have no
	# spot at all, so the one thing the player has to be told about got no frame.
	var superfood_spot: Callable = _tight(func():
		for row in level.board:
			for cell in row:
				if cell != null and cell.pipe != null and is_instance_valid(cell.pipe) \
						and cell.pipe.has_coin == 1000:
					return cell.pipe.get_node_or_null("PipeCoin1")
		return null, 8.0)

	var monster_spot: Callable = _tight(func():
		for a in level.agents:
			if is_instance_valid(a):
				return a
		return null)

	return [
		{
			"title": "Gorilla",
			"text": "You are in a walled room with apples all over the floor.\n\nEat every one of them.",
		},
		{
			"text": "This is you. You walk by yourself, and keep going the same way until you turn.",
			"spot": player_spot,
		},
		{
			"text": "Swipe in a direction to turn that way. Arrow keys do the same.\n\nTry it.",
			"await": {"event": "player_steered", "timeout": 60.0},
			"hint_after": 10.0,
			"hint": "A quick swipe up, down, left or right.",
		},
		{
			"setup": func():
				level.tutorial_spawn_gorilla()
				level.tutorial_hold_gorilla_midscreen(),
			"title": "The second job",
			"text": "Gorillas walk past outside the wall — like this one.\n\nCount them. They only ever pass along the edges, one at a time.",
			"spot": gorilla_spot,
		},
		{
			"spot": superfood_spot,
			"title": "Super-foods",
			"text": "A super-food makes you dangerous for a few seconds — monsters run from you.\n\nThere are a few of them. Eat them too: the room is not clear while any is left.",
		},
		{
			"title": "Keep eating",
			"text": "You cannot stand still and watch. Go too long without an apple and you starve.\n\nThe ring around you is the time you have left; it fills again with every one you eat.",
			"spot": player_spot,
		},
		{
			"title": "Two things at once",
			"text": "Clear the apples, and keep count.\n\nThey hold your eyes in the center of the room; the gorillas only ever appear round the outside.",
		},
		{
			"setup": func(): level.tutorial_show_a_monster(),
			"title": "Monsters",
			"text": "Monsters share the room and chase you. Being caught costs a life, and so does starving.\n\nAn exact gorilla count wins one back.",
			"spot": monster_spot,
		},
		{
			"title": "Ready",
			"text": "When the room is clear, or the time is up, you are asked how many gorillas went past.\n\nGet it right for a bonus, and a life back.",
		},
	]
