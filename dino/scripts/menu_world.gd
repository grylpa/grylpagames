extends "res://scripts/menu_poster.gd"

# DINO'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): the game's own dinosaur
# cards (the shared zig-framed card) held up in a wide FAN, like a magician's hand, over the game's own
# background darkened to a vignette -- the fan breathing slowly, and every few seconds one card rising out
# of it, lit, turning a little to face you, then sinking back as the next one rises: "have you seen this
# one before?". Staged as a picture, not a deal (the user: the first version, one card dealt at a time in
# the middle, looked "too much like it's playable"). Made up, never the board.

const CARD: GDScript = preload("res://shared/scripts/card.gd")
const BG: String = "res://art/dinos/bk1.jpg"
const CARDS: Array = [3, 14, 21, 8, 27, 11, 19, 5, 24, 16, 9, 30, 12, 26, 7]
# A TURNING WHEEL (the user: the rising card made "disturbing jumps", and the poster was "too slow and
# boring"): the cards ride round a great wheel whose hub is below the screen, its upper arc showing, turning
# steadily; the card passing the top grows, lifts and brightens as it goes by. They are spaced so that no
# two ever overlap, so their stacking never has to change -- nothing can pop.
const SPACING: float = 0.42       # radians between cards on the wheel
const SPEED: float = 0.32          # radians a second

var _bg: TextureRect = null
var _layer: Node2D = null
var _cards: Array = []

func _setup() -> void:
	_bg = TextureRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.modulate = Color(0.42, 0.39, 0.37)
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
	var w: float = minf(full.x * 0.24, room * 0.26)
	var radius: float = (w * 1.35) / SPACING * 1.05        # the cards' arc spacing a little over their width
	var hub: Vector2 = Vector2(full.x * 0.5, top + room * 0.42 + radius)
	var n: int = _cards.size()
	for k in n:
		var c: Node2D = _cards[k]
		c.call("set_width", w)
		var a: float = wrapf(t * SPEED + float(k) * SPACING, -PI, PI)
		var near_top: float = exp(-pow(a / 0.30, 2.0))
		var sc: float = 0.82 + 0.48 * near_top
		var dir: Vector2 = Vector2(sin(a), -cos(a))
		var center: Vector2 = hub + dir * (radius + 26.0 * near_top)
		var half_h: float = float(c.call("card_height")) * 0.5 * sc
		var rot: float = a * (1.0 - 0.6 * near_top)
		c.position = center - Vector2(0.0, half_h).rotated(rot)
		c.rotation = rot
		c.scale = Vector2.ONE * sc
		c.visible = absf(a) < 1.6
		c.modulate = Color(0.72, 0.70, 0.68).lerp(Color(1, 1, 1), near_top)
	# no reordering: no two cards overlap

func _paint_top(_full: Vector2, _bottom: float) -> void:
	title("Dino", "Swipe to say if you've seen the card already", Color(0.66, 0.92, 0.36), Color(0.08, 0.14, 0.04),
		Color(0.4, 0.8, 0.2, 0.25))
