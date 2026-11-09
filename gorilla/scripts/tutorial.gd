extends RefCounted

# Gorilla's coached tutorial. See docs/tutorials.md for the step schema.
#
# What a first-time Gorilla player has to be shown (2026-11-09: the maze fills the screen and the
# second job is rescuing lost baby gorillas, not counting gorillas outside a room):
#   1. Movement, which is announced nowhere: a quick swipe sets a direction and you keep walking
#      that way until you turn. (This game has no drawn-path movement.)
#   2. The lost baby. It appears quietly, far away, and the whole game is noticing it while you
#      eat somewhere else -- so the tutorial puts one on the board, points at it while the game is
#      frozen, and then waits for the player to actually go and rescue it.
#   3. Monsters. They are switched off for the whole tutorial (num_inside_monsters = 0) so nobody
#      is killed halfway through a lesson, and one is spawned on the last teaching step, named and
#      pointed at with the game frozen.
# No automatic babies or bananas during the tutorial (level._tutorial_setup).

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
	var baby_spot: Callable = _tight(func():
		return level.baby if level.baby != null and is_instance_valid(level.baby) else null, 10.0)
	var banana_spot: Callable = _tight(func():
		for b in level._bananas:
			if is_instance_valid(b["node"]):
				return b["node"]
		return null, 10.0)
	# The mother, who brings the sword (it replaced the super-food), pointed at through her own extent.
	var mother_spot: Callable = _tight(func():
		return level.mother if level.mother != null and is_instance_valid(level.mother) else null, 10.0)

	var monster_spot: Callable = _tight(func():
		for a in level.agents:
			if is_instance_valid(a):
				return a
		return null)

	return [
		{
			"title": "Gorilla",
			"text": "You're in a maze with apples scattered around it.\n\nEat them.",
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
			"setup": func(): level.tutorial_spawn_baby(),
			"title": "A lost baby",
			"text": "Now and then a baby gorilla gets lost somewhere in the maze, like this one.\n\nIt appears quietly, far from you, so keep an eye on the whole maze.",
			"spot": baby_spot,
		},
		{
			"title": "Rescue it",
			"text": "Go and get it: walk into it to rescue it.\n\nIn the real game a monster starts hunting it soon after it appears, so be quick.",
			"await": {"event": "baby_rescued", "timeout": 90.0},
			"hint_after": 20.0,
			"hint": "Swipe your way toward the baby gorilla.",
		},
		{
			"setup": func(): level.tutorial_spawn_mother(),
			"title": "Its mother",
			"text": "Each time you rescue a baby, its mother comes out somewhere else in the maze, holding a sword, for a few seconds.",
			"spot": mother_spot,
		},
		{
			"title": "The sword",
			"text": "Take the sword. For a few seconds the monsters run from you, and you can eat them.",
			"await": {"event": "gift_taken", "timeout": 90.0},
			"hint_after": 20.0,
			"hint": "Swipe your way to the mother gorilla.",
		},
		{
			"title": "Keep eating",
			"text": "You can't just stand still. Go too long without an apple and you starve.\n\nThe ring around you shows how long you have left. It fills up again with every apple you eat.",
			"spot": player_spot,
		},
		{
			"setup": func(): level.tutorial_spawn_banana(),
			"title": "Bananas",
			"text": "Bananas turn up now and then, for a few seconds only.\n\nA bunch fills your ring right up, so you can go far from the apples, to a baby or its mother.",
			"spot": banana_spot,
		},
		{
			"text": "Go and eat it.",
			"await": {"event": "banana_taken", "timeout": 90.0},
			"hint_after": 20.0,
			"hint": "Swipe your way to the bananas.",
		},
		{
			"setup": func(): level.tutorial_show_a_monster(),
			"title": "Monsters",
			"text": "Monsters share the maze and chase you. Being caught costs a life, and so does starving.",
			"spot": monster_spot,
		},
		{
			"title": "Ready",
			"text": "Rescue enough babies to pass the level.\n\nWatch the whole maze while you eat: babies, mothers and bananas all turn up far from you.",
		},
	]
