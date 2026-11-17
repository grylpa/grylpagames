extends "res://scripts/menu_poster.gd"

# DINO N-BACK'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): a TRAIL of the game's
# own cards (the shared zig-framed card) winding back into the distance over the darkened dino backdrop --
# the newest large at the front, each one before it smaller and dimmer, further along the trail. Every few
# seconds a new card arrives at the front and the whole trail steps back one place; and when the new card
# is the same as the one N back, a golden thread of light joins the two, both glowing -- "is this the card
# from N back?". Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const BG: String = "res://art/dinos/bk1.jpg"
const N_BACK: int = 2
const STEP: float = 1.6          # a card every 1.6 s: at 2.6 the pause was too long
const SHOWN: int = 6
# the stream of pictures; where a card repeats the one two before it, the thread shows
const STREAM: Array = [3, 14, 3, 21, 8, 21, 11, 27, 11, 19, 5, 19]

var _bg: TextureRect = null
var _layer: Node2D = null
var _cards: Array = []          # one node per slot, re-dressed as the trail steps
var _fx: Control = null
var _under: Control = null
var _dressed: int = -1

func _setup() -> void:
	_bg = TextureRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.modulate = Color(0.26, 0.25, 0.30)
	if ResourceLoader.exists(BG):
		_bg.texture = load(BG)
	add_child(_bg)
	# the link between a matching pair is drawn UNDER the cards: it rises from behind one and sinks behind
	# the other, so it never lies across a picture
	_under = Control.new()
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_under.set_anchors_preset(Control.PRESET_FULL_RECT)
	_under.draw.connect(func() -> void: _draw_link(_under))
	add_child(_under)
	_layer = Node2D.new()
	add_child(_layer)
	for k in SHOWN + 1:
		var c: Node2D = CARD.new()
		_layer.add_child(c)
		c.call("set_frame", 8, 8)
		_cards.append(c)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(func() -> void: _draw_fx(_fx))
	add_child(_fx)

# the stream read from its third card, so the very first beat is a match and the thread shows at once
func _seq(i: int) -> int:
	return int(STREAM[posmod(i + 1, STREAM.size())])

func _tex(n: int) -> Texture2D:
	var p: String = "res://art/dinos/dino%d.jpg" % n
	return load(p) if ResourceLoader.exists(p) else null

# a place along the trail: 0 the front, 1 one back, ... (fractions between), on screen
func _trail(pos: float) -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var top: float = 240.0 if mobile else 160.0
	var u: float = pos / float(SHOWN)
	var depth: float = pow(0.72, pos)                    # each card back is 72% the size of the one in front
	# an S across the screen: the front at the lower left, round to the right, back toward the left far off
	var x: float = full.x * (0.5 + 0.27 * sin(pos * 0.95 - 0.9))
	var front_y: float = bottom - full.x * 0.19 * 1.42 * 0.75
	var y: float = lerpf(front_y, top + 40.0, 1.0 - pow(1.0 - u, 1.8))
	return {"p": Vector2(x, y), "s": depth, "a": clampf(1.0 - u * 0.85, 0.0, 1.0)}

func _tick(_delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	_bg.position = Vector2.ZERO
	_bg.size = full
	var n: int = int(t / STEP)
	var u: float = fmod(t, STEP) / STEP
	var shift: float = smoothstep(0.0, 0.40, u)        # the trail steps back in the first part of a beat
	var w: float = full.x * 0.19
	for k in _cards.size():
		var c: Node2D = _cards[k]
		var idx: int = n - k + 1                           # the picture this slot shows
		if _dressed != n:
			c.call("setup", _tex(_seq(idx)), Color(1, 1, 1))
			c.call("set_width", w)
		var pos: float = float(k) - 1.0 + shift          # slot 0 is the arriving card
		var tr_: Dictionary = _trail(maxf(pos, 0.0))
		var arrive: float = clampf(pos + 1.0, 0.0, 1.0)  # the newest slides in from below
		var sc: float = float(tr_["s"])
		var half_h: float = float(c.call("card_height")) * 0.5 * sc
		c.position = Vector2(tr_["p"]) + Vector2(0.0, 140.0 * (1.0 - arrive)) - Vector2(0.0, half_h)
		c.scale = Vector2.ONE * sc
		c.rotation = sin(float(idx) * 1.7) * 0.10
		c.modulate = Color(1, 1, 1, float(tr_["a"]) * arrive).lerp(Color(0.7, 0.7, 0.75, float(tr_["a"]) * arrive), clampf(pos * 0.3, 0.0, 1.0))
	if _dressed != n:
		_dressed = n
		# the nearest in front
		for k in _cards.size():
			_layer.move_child(_cards[k], _cards.size() - 1 - k)
	_fx.queue_redraw()
	_under.queue_redraw()

# the vignette over everything (the link is _draw_link's, under the cards)
func _draw_fx(d: Control) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	for side in [0.0, 1.0]:
		var x0: float = side * full.x
		var x1: float = x0 + (full.x * 0.22 if side == 0.0 else -full.x * 0.22)
		d.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, full.y), Vector2(x0, full.y)]),
			PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45)]))

# THE LINK, when the front card is the same as the one N back: a luminous arc bowing out to the side between
# them -- a wide soft glow, a bright fine core, both tapering to nothing at the ends, sparkles running along
# it -- fading in as the new card settles and out before the next (the user: the link was the right idea,
# drawn badly as a flat line; a gold frame round the two instead was "super ugly")
func _draw_link(d: Control) -> void:
	var n: int = int(t / STEP)
	var u: float = fmod(t, STEP) / STEP
	var front_idx: int = n + 1
	var back_idx: int = front_idx - N_BACK
	if _seq(front_idx) != _seq(back_idx):
		return
	var a: float = smoothstep(0.30, 0.50, u) * (1.0 - smoothstep(0.88, 1.0, u))
	if a <= 0.0:
		return
	var c0: Node2D = _cards[0]
	var c1: Node2D = _cards[N_BACK]
	var p0: Vector2 = c0.position + Vector2(0.0, float(c0.call("card_height")) * c0.scale.y * 0.5).rotated(c0.rotation)
	var p1: Vector2 = c1.position + Vector2(0.0, float(c1.call("card_height")) * c1.scale.y * 0.5).rotated(c1.rotation)
	var side: Vector2 = (p1 - p0).orthogonal().normalized()
	if side.x > 0.0:
		side = -side
	var ctrl: Vector2 = (p0 + p1) * 0.5 + side * p0.distance_to(p1) * 0.45
	var pts: Array = []
	var n_pts: int = 40
	for k in n_pts + 1:
		var f: float = float(k) / float(n_pts)
		pts.append(p0.lerp(ctrl, f).lerp(ctrl.lerp(p1, f), f))
	# the glow, then the core: each a ribbon whose width swells in the middle and tapers to the ends
	for layer_i in 4:
		var w: float = [26.0, 15.0, 7.0, 2.5][layer_i]
		var col: Color = [Color(1.0, 0.86, 0.55, 0.06), Color(1.0, 0.88, 0.60, 0.10), Color(1.0, 0.92, 0.72, 0.30), Color(1.0, 1.0, 0.95, 0.95)][layer_i]
		for k in n_pts:
			var f2: float = (float(k) + 0.5) / float(n_pts)
			var taper: float = sin(f2 * PI)
			d.draw_line(pts[k], pts[k + 1], Color(col, col.a * a), maxf(0.5, w * taper), true)
	# sparkles running along it, both ways
	for k in 5:
		var f3: float = fmod(t * 0.45 + float(k) / 5.0, 1.0)
		var dir_f: float = f3 if k % 2 == 0 else 1.0 - f3
		var sp: Vector2 = pts[int(dir_f * float(n_pts))]
		var tw: float = sin(f3 * PI)
		for g in 4:
			d.draw_circle(sp, (9.0 - 2.0 * float(g)) * tw, Color(1.0, 0.95, 0.80, 0.10 * a))
		d.draw_circle(sp, 2.0 * tw, Color(1, 1, 1, a))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dino N-Back", "Does this card match the one N cards back?", Color(0.66, 0.92, 0.36), Color(0.08, 0.14, 0.04),
		Color(0.4, 0.8, 0.2, 0.25))
