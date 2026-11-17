extends "res://scripts/menu_poster.gd"

# FRIENDS' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): AN EVENING STROLL IN THE PARK. A
# dusk sky, warm at the horizon and deep blue above, the low sun's glow, a far skyline; a path running away between
# lawns and trees, lamps along it just lit. Coming up the path toward you, small in the distance and growing as
# they come (the game's arrivals grow too), the game's own people on their photo cards (the shared card, its photo
# style), each with a gentle walking bob, veering off to the side as they pass. A FRIEND has a name under the
# photo, and as they come near a "Hi, Name!" bubble rises beside them; a stranger walks by unnamed and unhailed.
# The park is a still layer (baked: menu_still_0_<m|d>.webp); the walkers are live, their photos loaded on threads.
# Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const PEOPLE: Array = ["Alina Vetrova", "Anand_Iyer", "Barbara_Coleman", "Beverly_Mitchel", "Carolyn_Ramirez"]
const WALK_S: float = 9.0                 # one walk up the path
const WALKERS: int = 3
const FRIEND_OF: Array = [true, false, true, true, false, true]   # by walk number: a friend, or a stranger

var _people: Array = []                   # file names found in art/people
var _tex: Dictionary = {}                 # file name -> Texture2D
var _cards: Array = []
var _walk_of: Array = []                  # the walk number each card is showing
var _bubbles: Control = null

func _setup() -> void:
	add_still(func(d: Control) -> void: _draw_park(d))
	# the people: every photo in the shared folder, in a fixed order
	var dir: DirAccess = DirAccess.open("res://art/people")
	if dir != null:
		for f in dir.get_files():
			var fn: String = f.trim_suffix(".import")
			if fn.ends_with(".jpg") and not _people.has(fn.get_basename()):
				_people.append(fn.get_basename())
	_people.sort()
	if _people.is_empty():
		_people = PEOPLE.duplicate()
	for k in WALKERS:
		var c: Node2D = CARD.new()
		add_child(c)
		c.call("set_photo", true)
		c.visible = false
		_cards.append(c)
		_walk_of.append(-1)
	_bubbles = Control.new()
	_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubbles.draw.connect(func() -> void: _draw_bubbles(_bubbles))
	add_child(_bubbles)

func _person(walk: int) -> String:
	return _people[posmod(walk * 7 + 3, _people.size())]

func _first(person: String) -> String:
	return person.replace("_", " ").split(" ")[0]

# the photo for a walk, requested on a thread; null until it has arrived
func _photo(person: String) -> Texture2D:
	if _tex.has(person):
		return _tex[person]
	var path: String = "res://art/people/%s.jpg" % person
	var st: int = ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
	elif st == ResourceLoader.THREAD_LOAD_LOADED:
		_tex[person] = ResourceLoader.load_threaded_get(path)
		return _tex[person]
	return null

func _geom(full: Vector2, bottom: float) -> Dictionary:
	var top: float = 230.0 if mobile else 140.0
	var horizon: float = top + (bottom - top) * 0.30
	return {"top": top, "horizon": horizon, "vp": Vector2(full.x * 0.5, horizon), "foot": bottom + 40.0}

# a walker's place on the path at s (0 far .. 1 near), on its side of the path
func _on_path(s: float, side: float, full: Vector2, bottom: float) -> Array:
	var g: Dictionary = _geom(full, bottom)
	var vp: Vector2 = g["vp"]
	var foot: float = g["foot"]
	var y: float = lerpf(vp.y + 6.0, foot, pow(s, 1.7))
	var half_w: float = lerpf(4.0, full.x * 0.30, pow(s, 1.7))
	var x: float = vp.x + side * half_w * (0.45 + 1.6 * pow(s, 4.0))
	return [Vector2(x, y), lerpf(0.10, 1.0, pow(s, 1.5))]

func _tick(_delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var w_full: float = minf(full.x * 0.26, (bottom - float(_geom(full, bottom)["top"])) * 0.36)
	var order: Array = []
	for k in WALKERS:
		var c: Node2D = _cards[k]
		var tw: float = t + float(k) * WALK_S / float(WALKERS)
		var walk: int = int(floor(tw / WALK_S)) * WALKERS + k
		var s: float = fmod(tw, WALK_S) / WALK_S
		var person: String = _person(walk)
		var tex: Texture2D = _photo(person)
		if tex == null:
			c.visible = false
			continue
		if _walk_of[k] != walk:
			# a new walker, far off (nearly invisible there): their photo, their name if a friend
			_walk_of[k] = walk
			c.call("setup", tex, Color(1, 1, 1))
			var friend: bool = FRIEND_OF[posmod(walk, FRIEND_OF.size())]
			c.call("set_label", _first(person) if friend else "")
			c.call("show_label", friend)
			c.set_meta("friend", friend)
			c.set_meta("name", _first(person))
		var side: float = -1.0 if posmod(walk, 2) == 0 else 1.0
		var at: Array = _on_path(s, side, full, bottom)
		var sc: float = at[1]
		c.visible = true
		c.call("set_width", w_full)
		var h: float = float(c.call("card_height"))
		# the walk: a small bob with each step, a slight rock; fading in far off
		var step: float = sin(t * 5.5 + float(k) * 2.0)
		var p: Vector2 = at[0]
		c.scale = Vector2.ONE * sc
		c.rotation = deg_to_rad(2.0) * step * sc + side * deg_to_rad(4.0) * pow(s, 3.0)
		# the card's origin is its top center: its foot on the path
		c.position = p - Vector2(0.0, h * sc + absf(step) * 6.0 * sc).rotated(c.rotation)
		# far off it is dim in the dusk and fades in; near, in full color
		c.modulate = Color(lerpf(0.55, 1.0, smoothstep(0.0, 0.5, s)), lerpf(0.52, 1.0, smoothstep(0.0, 0.5, s)), lerpf(0.60, 1.0, smoothstep(0.0, 0.5, s)), smoothstep(0.0, 0.10, s))
		c.set_meta("s", s)
		order.append([s, c])
	# the nearer walkers in front
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for o in order:
		move_child(o[1] as Node2D, get_child_count() - 1)
	move_child(_bubbles, get_child_count() - 1)
	if _top != null:
		move_child(_top, get_child_count() - 1)
	_bubbles.queue_redraw()

# a friend's greeting: a speech bubble rising beside them as they come near, fading as they pass
func _draw_bubbles(d: Control) -> void:
	var f: Font = MainGlobals.get_text_font()
	for c in _cards:
		var cc: Node2D = c
		if not cc.visible or not bool(cc.get_meta("friend", false)):
			continue
		var s: float = float(cc.get_meta("s", 0.0))
		var a: float = smoothstep(0.40, 0.52, s) * (1.0 - smoothstep(0.78, 0.88, s))
		if a <= 0.0:
			continue
		var txt: String = "Hi, %s!" % str(cc.get_meta("name", ""))
		var fs: int = 30 if mobile else 22
		var tw: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w: float = float(cc.call("card_width")) * cc.scale.x
		var on_left: bool = cc.position.x > MainGlobals.full_screen_size.x * 0.5
		# beside the head (the card's origin is its top center)
		var anchor: Vector2 = cc.position + Vector2(-(w * 0.5 + 8.0) if on_left else w * 0.5 + 8.0, 10.0 - 14.0 * a)
		var box: Rect2 = Rect2(anchor + Vector2(-tw - 28.0 if on_left else 0.0, -fs - 18.0), Vector2(tw + 28.0, fs + 18.0))
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bg: Color = Color(1.0, 0.98, 0.92, 0.95 * a)
		d.draw_rect(box.grow(2.0), Color(0.15, 0.10, 0.06, 0.6 * a))
		d.draw_rect(box, bg)
		var tail_x: float = box.end.x - 18.0 if on_left else box.position.x + 18.0
		d.draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 7.0, box.end.y), Vector2(tail_x + 7.0, box.end.y), Vector2(tail_x + (10.0 if on_left else -10.0), box.end.y + 14.0)]), bg)
		d.draw_string(f, box.position + Vector2(14.0, fs + 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.20, 0.30, 0.18, a))

# --- the park at dusk (a still layer) ----------------------------------------------------------------------------

func _draw_park(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var g: Dictionary = _geom(full, bottom)
	var horizon: float = g["horizon"]
	var vp: Vector2 = g["vp"]
	# the sky: deep blue above, violet, a warm band at the horizon, the low sun's glow
	var bands: Array = [[0.0, Color(0.08, 0.10, 0.24)], [0.55, Color(0.30, 0.20, 0.38)], [0.85, Color(0.85, 0.45, 0.32)], [1.0, Color(1.0, 0.72, 0.42)]]
	for k in bands.size() - 1:
		var y0: float = horizon * float(bands[k][0])
		var y1: float = horizon * float(bands[k + 1][0])
		d.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(full.x, y0), Vector2(full.x, y1), Vector2(0, y1)]),
			PackedColorArray([bands[k][1], bands[k][1], bands[k + 1][1], bands[k + 1][1]]))
	for k in 12:
		d.draw_set_transform(Vector2(vp.x + full.x * 0.12, horizon), 0.0, Vector2(1.6, 0.6))
		d.draw_circle(Vector2.ZERO, 160.0 - float(k) * 12.0, Color(1.0, 0.80, 0.50, 0.035))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 30:
		d.draw_circle(Vector2(h01(k + 50) * full.x, h01(k + 60) * horizon * 0.45), 0.8 + h01(k + 70), Color(1, 1, 1, 0.35 + 0.3 * h01(k + 80)))
	# a far skyline, hazed, a few windows lit
	var x: float = 0.0
	var k2: int = 0
	while x < full.x:
		var bw: float = 26.0 + 40.0 * h01(k2 + 100)
		var bh: float = 18.0 + 60.0 * h01(k2 + 110)
		d.draw_rect(Rect2(x, horizon - bh, bw - 2.0, bh), Color(0.30, 0.22, 0.32))
		for wi in int(bh / 9.0):
			if h01(k2 * 13 + wi) > 0.72:
				d.draw_rect(Rect2(x + 4.0 + 8.0 * float(wi % 3), horizon - bh + 4.0 + 9.0 * float(wi), 3.0, 3.0), Color(1.0, 0.85, 0.55, 0.8))
		x += bw
		k2 += 1
	# the lawns, darkening toward you
	d.draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(full.x, horizon), Vector2(full.x, full.y), Vector2(0, full.y)]),
		PackedColorArray([Color(0.20, 0.26, 0.20), Color(0.20, 0.26, 0.20), Color(0.05, 0.09, 0.06), Color(0.05, 0.09, 0.06)]))
	# the path: gravel, pale in the last light, running to the horizon, its edges lined
	var foot: float = g["foot"]
	var path: PackedVector2Array = PackedVector2Array([vp + Vector2(-5, 0), vp + Vector2(5, 0), Vector2(full.x * 0.5 + full.x * 0.36, foot), Vector2(full.x * 0.5 - full.x * 0.36, foot)])
	d.draw_polygon(path, PackedColorArray([Color(0.72, 0.58, 0.48), Color(0.72, 0.58, 0.48), Color(0.36, 0.30, 0.28), Color(0.36, 0.30, 0.28)]))
	for k3 in 900:
		var s: float = h01(k3 + 200)
		var yy: float = lerpf(horizon, foot, pow(s, 1.7))
		var hw: float = lerpf(5.0, full.x * 0.36, pow(s, 1.7))
		var xx: float = vp.x + (h01(k3 + 300) * 2.0 - 1.0) * hw
		d.draw_rect(Rect2(xx, yy, 1.0 + 2.0 * s, 1.0 + 1.5 * s), Color(0.15, 0.10, 0.08, 0.25) if k3 % 2 == 0 else Color(1.0, 0.92, 0.80, 0.12))
	for side in [-1.0, 1.0]:
		d.draw_line(vp + Vector2(side * 5.0, 0.0), Vector2(full.x * 0.5 + side * full.x * 0.36, foot), Color(0.12, 0.16, 0.10), 3.0, true)
	# trees along both sides, receding: trunks and round crowns, dark against the sky
	for i in 7:
		var s2: float = 1.0 - float(i) / 7.0
		for side2 in [-1.0, 1.0]:
			var ty: float = lerpf(horizon, foot, pow(s2, 1.7))
			var tx: float = vp.x + side2 * lerpf(16.0, full.x * 0.62, pow(s2, 1.7))
			var sc: float = lerpf(0.12, 1.4, pow(s2, 1.5))
			var tc: Color = Color(0.10, 0.14, 0.12).lerp(Color(0.03, 0.05, 0.04), s2)
			d.draw_rect(Rect2(tx - 5.0 * sc, ty - 110.0 * sc, 10.0 * sc, 110.0 * sc), tc)
			for j in 5:
				d.draw_circle(Vector2(tx + (h01(i * 9 + j) - 0.5) * 60.0 * sc, ty - (130.0 + 50.0 * h01(i * 9 + j + 3)) * sc), (40.0 + 16.0 * h01(i * 9 + j + 5)) * sc, tc)
	# THE LAMPS along the path, just lit: posts, lanterns, a pool of light on the gravel under each
	for i2 in 5:
		var s3: float = 1.0 - (float(i2) + 0.5) / 5.0
		for side3 in [-1.0, 1.0]:
			var ly: float = lerpf(horizon, foot, pow(s3, 1.7))
			var lx: float = vp.x + side3 * lerpf(10.0, full.x * 0.42, pow(s3, 1.7))
			var sc2: float = lerpf(0.10, 1.2, pow(s3, 1.5))
			d.draw_set_transform(Vector2(lx - side3 * 30.0 * sc2, ly), 0.0, Vector2(1.0, 0.3))
			for j2 in 6:
				d.draw_circle(Vector2.ZERO, (70.0 - float(j2) * 10.0) * sc2, Color(1.0, 0.82, 0.50, 0.05))
			d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			d.draw_rect(Rect2(lx - 2.5 * sc2, ly - 150.0 * sc2, 5.0 * sc2, 150.0 * sc2), Color(0.06, 0.06, 0.07))
			var lamp: Vector2 = Vector2(lx, ly - 158.0 * sc2)
			for j3 in 6:
				d.draw_circle(lamp, (40.0 - float(j3) * 6.0) * sc2, Color(1.0, 0.82, 0.50, 0.06))
			d.draw_rect(Rect2(lamp.x - 7.0 * sc2, lamp.y - 10.0 * sc2, 14.0 * sc2, 18.0 * sc2), Color(1.0, 0.90, 0.65))
			d.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-10, -10) * sc2, lamp + Vector2(10, -10) * sc2, lamp + Vector2(0, -20) * sc2]), Color(0.06, 0.06, 0.07))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Friends", "Recognize your friends on an evening stroll", Color(1.0, 0.86, 0.62), Color(0.16, 0.08, 0.10),
		Color(1.0, 0.75, 0.5, 0.25))
