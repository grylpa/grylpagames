extends "res://scripts/menu_poster.gd"

# DINO'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): the game's own dinosaur
# cards (the shared zig-framed card) held up in a wide FAN, like a magician's hand, over the game's own
# background darkened to a vignette -- the fan breathing slowly, and every few seconds one card rising out
# of it, lit, turning a little to face you, then sinking back as the next one rises: "have you seen this
# one before?". Staged as a picture, not a deal (the user: the first version, one card dealt at a time in
# the middle, looked "too much like it's playable"). Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const BG: String = "res://art/dinos/bk1.jpg"
const CARDS: Array = [3, 14, 21, 8, 27, 11, 19]
const STEP: float = 3.2          # one card rising and settling

var _bg: TextureRect = null
var _layer: Node2D = null
var _cards: Array = []

func _setup() -> void:
	_bg = TextureRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.modulate = Color(0.55, 0.50, 0.46)
	if ResourceLoader.exists(BG):
		_bg.texture = load(BG)
	add_child(_bg)
	var shade: Control = Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.draw.connect(func() -> void: _draw_shade(shade))
	add_child(shade)
	_layer = Node2D.new()
	add_child(_layer)
	for k in CARDS.size():
		var c: Node2D = CARD.new()
		_layer.add_child(c)
		c.call("set_frame", 8, 8)
		var p: String = "res://art/dinos/dino%d.jpg" % int(CARDS[k])
		c.call("setup", load(p) if ResourceLoader.exists(p) else null, Color(1, 1, 1))
		_cards.append(c)

# a vignette, and a warm spotlight behind the fan
func _draw_shade(d: Control) -> void:
	var f: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else f.y * 0.62
	for k in 10:
		d.draw_set_transform(Vector2(f.x * 0.5, bottom * 0.62), 0.0, Vector2(1.0, 0.9))
		d.draw_circle(Vector2.ZERO, f.x * (0.95 - 0.08 * float(k)), Color(1.0, 0.85, 0.55, 0.03))
	d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(f.x, 0), Vector2(f.x, f.y * 0.32), Vector2(0, f.y * 0.32)]),
		PackedColorArray([Color(0, 0, 0, 0.70), Color(0, 0, 0, 0.70), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	for side in [0.0, 1.0]:
		var x0: float = side * f.x
		var x1: float = x0 + (f.x * 0.22 if side == 0.0 else -f.x * 0.22)
		d.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, f.y), Vector2(x0, f.y)]),
			PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5)]))

func _tick(_delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	_bg.position = Vector2.ZERO
	_bg.size = full
	var top: float = 230.0 if mobile else 150.0
	var room: float = maxf(120.0, bottom - top)
	var w: float = minf(full.x * 0.25, room * 0.30)
	# the hand: the fan's pivot below the cards, the cards spread round it
	var pivot: Vector2 = Vector2(full.x * 0.5, top + room * 1.05)
	var radius: float = room * 0.55
	var n: int = _cards.size()
	var spread: float = deg_to_rad(50.0) + deg_to_rad(3.0) * sin(t * 0.6)
	var i: int = int(t / STEP) % n
	var u: float = fmod(t, STEP) / STEP
	var rise: float = sin(clampf(u / 0.85, 0.0, 1.0) * PI)
	for k in n:
		var c: Node2D = _cards[k]
		c.call("set_width", w)
		var a: float = lerpf(-spread * 0.5, spread * 0.5, float(k) / float(n - 1))
		var lift: float = rise if k == i else 0.0
		var dir: Vector2 = Vector2(sin(a), -cos(a))
		# a card's origin is its TOP-CENTER, so it is placed to turn about its center
		var rot: float = a * (1.0 - 0.75 * lift)
		var sc: float = 1.0 + 0.22 * lift
		var half_h: float = float(c.call("card_height")) * 0.5 * sc
		var center: Vector2 = pivot + dir * (radius + lift * room * 0.14)
		c.position = center - Vector2(0.0, half_h).rotated(rot)
		c.rotation = rot
		c.scale = Vector2.ONE * sc
		c.modulate = Color(1, 1, 1).lerp(Color(0.80, 0.78, 0.74), 1.0 - lift) if k != i else Color(1, 1, 1)
	# the rising card in front of the others, the rest in fan order
	for k in n:
		_layer.move_child(_cards[k], k)
	_layer.move_child(_cards[i], n - 1)

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dino", "Swipe to say if you've seen the card already", Color(0.66, 0.92, 0.36), Color(0.08, 0.14, 0.04),
		Color(0.4, 0.8, 0.2, 0.25))
