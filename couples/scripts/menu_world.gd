extends "res://scripts/menu_poster.gd"

# COUPLES' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): A CARD TABLE UNDER A LAMP. Green
# felt, a pool of warm light, a dark rim; the game's own dino cards (the shared zig-framed card) lying scattered on
# it at easy angles -- and among them, far apart, two that are THE SAME. Every few seconds the pair finds itself:
# both glow, rise off the felt, slide together side by side, hold a moment under a gold ring, and settle back to
# where they lay. The felt is a still layer (baked: menu_still_0_<m|d>.webp); the cards load on threads and fade
# in as their photos arrive. Scattered, not a grid. Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
# [x, y (shares of the box), degrees, picture] -- the two 21s are the couple
const LAYOUT: Array = [
	[0.16, 0.20, -8.0, 3], [0.50, 0.14, 5.0, 14], [0.84, 0.22, -4.0, 8],
	[0.30, 0.50, 6.0, 27], [0.70, 0.48, -7.0, 11], [0.12, 0.80, 4.0, 19],
	[0.44, 0.84, -5.0, 5], [0.86, 0.80, 9.0, 24],
	[0.66, 0.16, -3.0, 21], [0.24, 0.62, 3.0, 21],
]
const PAIR: Array = [8, 9]
const CYCLE: float = 7.0

var _layer: Node2D = null
var _under: Control = null
var _cards: Array = []
var _pending: Dictionary = {}       # path -> [card indexes]

func _setup() -> void:
	add_still(func(d: Control) -> void: _draw_felt(d))
	_under = Control.new()
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under.set_anchors_preset(Control.PRESET_FULL_RECT)
	_under.draw.connect(func() -> void: _draw_under(_under))
	add_child(_under)
	_layer = Node2D.new()
	add_child(_layer)

# the cards are made a few a frame (ten at once held the first frame up)
func _make_cards(n: int) -> void:
	for _i in n:
		if _cards.size() >= LAYOUT.size():
			return
		var k: int = _cards.size()
		var c: Node2D = CARD.new()
		_layer.add_child(c)
		c.call("set_frame", 8, 8)
		c.visible = false
		_cards.append(c)
		var p: String = "res://art/dinos/dino%d.jpg" % int(LAYOUT[k][3])
		if ResourceLoader.exists(p):
			if not _pending.has(p):
				_pending[p] = []
				ResourceLoader.load_threaded_request(p)
			(_pending[p] as Array).append(k)

func _box(full: Vector2, bottom: float) -> Rect2:
	var top: float = 300.0 if mobile else 172.0
	return Rect2(Vector2(full.x * 0.06, top), Vector2(full.x * 0.88, bottom - top - 10.0))

func _card_w(full: Vector2, bottom: float) -> float:
	var box: Rect2 = _box(full, bottom)
	return minf(full.x * 0.18, box.size.y * (0.24 if mobile else 0.34))

# where card k is now: its place, its turn, its lift (0 lying, 1 risen); the pair's comings and goings
func _pose(k: int, full: Vector2, bottom: float) -> Array:
	var box: Rect2 = _box(full, bottom)
	var lay: Array = LAYOUT[k]
	var home: Vector2 = box.position + Vector2(float(lay[0]) * box.size.x, float(lay[1]) * box.size.y)
	var rot: float = deg_to_rad(float(lay[2])) + deg_to_rad(1.2) * sin(t * 0.5 + float(k))
	var lift: float = 0.0
	var pi: int = PAIR.find(k)
	if pi >= 0:
		var u: float = fmod(t, CYCLE)
		var go: float = smoothstep(2.6, 3.8, u) * (1.0 - smoothstep(5.4, 6.7, u))
		lift = smoothstep(2.4, 3.0, u) * (1.0 - smoothstep(6.2, 6.9, u))
		var w: float = _card_w(full, bottom)
		var meet: Vector2 = box.position + box.size * Vector2(0.5, 0.42)
		var side: Vector2 = meet + Vector2((-0.56 if pi == 0 else 0.56) * w * 1.1, 0.0)
		home = home.lerp(side, go)
		rot = lerp_angle(rot, deg_to_rad(-3.0 if pi == 0 else 3.0), go)
	return [home, rot, lift]

func _tick(delta: float) -> void:
	_make_cards(3)
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	for path in _pending.keys():
		var st: int = ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var tex: Texture2D = ResourceLoader.load_threaded_get(path)
			for k in _pending[path]:
				(_cards[k] as Node2D).call("setup", tex, Color(1, 1, 1))
				(_cards[k] as Node2D).set_meta("photo", true)
				(_cards[k] as Node2D).modulate.a = 0.0
			_pending.erase(path)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pending.erase(path)
	var w: float = _card_w(full, bottom)
	for k in _cards.size():
		var c: Node2D = _cards[k]
		if not c.has_meta("photo"):
			continue
		c.visible = true
		c.modulate.a = fade_in(true, c.modulate.a, delta)
		c.call("set_width", w)
		var pose: Array = _pose(k, full, bottom)
		var sc: float = 1.0 + 0.12 * float(pose[2])
		var half_h: float = float(c.call("card_height")) * 0.5 * sc
		var rot: float = pose[1]
		c.position = (pose[0] as Vector2) - Vector2(0.0, half_h).rotated(rot)
		c.rotation = rot
		c.scale = Vector2.ONE * sc
	_under.queue_redraw()

# under the cards: each card's contact shadow (longer and softer for the pair as it rises), and the pair's glow
func _draw_under(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var w: float = _card_w(full, bottom)
	var u: float = fmod(t, CYCLE)
	var glow: float = smoothstep(1.8, 2.6, u) * (1.0 - smoothstep(6.0, 6.9, u))
	for k in _cards.size():
		var c: Node2D = _cards[k]
		if not c.visible:
			continue
		var pose: Array = _pose(k, full, bottom)
		var lift: float = pose[2]
		var hh: float = float(c.call("card_height")) * (1.0 + 0.12 * lift)
		var ctr: Vector2 = pose[0]
		var off: Vector2 = Vector2(5.0, 7.0) + Vector2(10.0, 16.0) * lift
		d.draw_set_transform(ctr + off, float(pose[1]), Vector2.ONE)
		for j in 4:
			var g: float = 2.0 + float(j) * (3.0 + 4.0 * lift)
			d.draw_rect(Rect2(-w * 0.5 - g, -hh * 0.5 - g, w + g * 2.0, hh + g * 2.0), Color(0, 0, 0, (0.10 - 0.04 * lift) * c.modulate.a))
		if PAIR.has(k) and glow > 0.0:
			d.draw_set_transform(ctr, float(pose[1]), Vector2.ONE)
			for j2 in 7:
				var g2: float = 4.0 + float(j2) * 5.0
				d.draw_rect(Rect2(-w * 0.5 - g2, -hh * 0.5 - g2, w + g2 * 2.0, hh + g2 * 2.0), Color(1.0, 0.82, 0.40, 0.07 * glow * (0.75 + 0.25 * sin(t * 5.0))))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# the gold ring round the couple while they stand together
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var u: float = fmod(t, CYCLE)
	var ring: float = smoothstep(3.6, 4.1, u) * (1.0 - smoothstep(5.2, 5.6, u))
	if ring > 0.0 and _cards.size() > int(PAIR[1]) and (_cards[PAIR[0]] as Node2D).visible:
		var box: Rect2 = _box(full, bottom)
		var meet: Vector2 = box.position + box.size * Vector2(0.5, 0.42)
		var w: float = _card_w(full, bottom)
		var hh: float = float((_cards[PAIR[0]] as Node2D).call("card_height")) * 1.12
		var r: Rect2 = Rect2(meet - Vector2(w * 1.25, hh * 0.5 + 10.0), Vector2(w * 2.5, hh + 20.0))
		cv.draw_rect(r.grow(2.0), Color(0.15, 0.08, 0.02, 0.5 * ring), false, 5.0)
		cv.draw_rect(r, Color(1.0, 0.84, 0.42, ring), false, 3.0)
	title("Couples", "Find the two identical cards", Color(1.0, 0.88, 0.55), Color(0.06, 0.12, 0.06),
		Color(1.0, 0.85, 0.45, 0.22))

# --- the table (a still layer) ---------------------------------------------------------------------------------

func _draw_felt(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var box: Rect2 = _box(full, bottom)
	# the felt, darker toward the edges, under a pool of warm light
	d.draw_rect(Rect2(Vector2.ZERO, full), Color(0.04, 0.16, 0.10))
	var c: Vector2 = box.get_center()
	for k in 24:
		var r: float = full.y * 0.75 * (1.0 - float(k) / 24.0)
		d.draw_set_transform(c, 0.0, Vector2(1.0, 0.85))
		d.draw_circle(Vector2.ZERO, r, Color(0.20, 0.42, 0.24, 0.045))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 10:
		d.draw_set_transform(c + Vector2(0, -20), 0.0, Vector2(1.0, 0.8))
		d.draw_circle(Vector2.ZERO, box.size.x * 0.55 * (1.0 - float(k) / 10.0), Color(1.0, 0.85, 0.55, 0.022))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# its nap: fine specks
	for k in 2600:
		var p: Vector2 = Vector2(h01(k + 11) * full.x, h01(k + 12) * full.y)
		d.draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(0, 0, 0, 0.10) if k % 2 == 0 else Color(1, 1, 1, 0.035))
	# the table's padded rim showing at the left and right edges, and a dark vignette into the corners
	for side in [0.0, 1.0]:
		var x0: float = -10.0 if side == 0.0 else full.x - 26.0
		d.draw_rect(Rect2(x0, 0.0, 36.0, full.y), Color(0.20, 0.10, 0.05))
		d.draw_rect(Rect2(x0 + (28.0 if side == 0.0 else 0.0), 0.0, 8.0, full.y), Color(0.34, 0.18, 0.08))
		d.draw_rect(Rect2(x0 + (34.0 if side == 0.0 else -4.0), 0.0, 4.0, full.y), Color(0, 0, 0, 0.35))
	for k in 12:
		var a: float = 0.05
		d.draw_rect(Rect2(Vector2.ZERO, Vector2(full.x, 30.0 + float(k) * 16.0)), Color(0, 0, 0, a))
