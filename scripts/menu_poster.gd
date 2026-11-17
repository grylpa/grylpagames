extends Control

# THE BASE OF A GAME'S OPENING POSTER (2026-11-17). A game's main scene returns one from
# `menu_backdrop()`; the shared main_menu.gd puts it behind a slim panel at the foot (level, PLAY, the
# links) and tells it where that panel starts (`set_scene_bottom`). A poster extends this script
# (`extends "res://scripts/menu_poster.gd"`) and draws its scene in `_paint(full, bottom)`; the name and
# the pitch go on top with `title()`.
#
# The user: the first screen "needs to create interest and elicit the player to continue and play the
# game. it needs to be beautiful, with something that is personal for each game" -- each game's poster
# is a little living scene of what the game is about, its name set in its own style.
# MADE UP, NEVER THE BOARD: the menu also opens mid-game, so a poster must show nothing of the game in play.

var scene_bottom: float = -1.0
var t: float = 0.0             # seconds since the poster appeared, for its motion
var mobile: bool = false
var cv: CanvasItem = null      # what the helpers draw on: this poster, or its TOP layer in _paint_top
var _top: Control = null

func menu_draws_title() -> bool:
	return true

func set_scene_bottom(y: float) -> void:
	scene_bottom = y
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mobile = MainGlobals.is_mobile()
	cv = self
	_setup()
	# the TOP layer, over any child nodes a poster adds (coins, sprites): the name goes there
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.draw.connect(func() -> void:
		var f2: Vector2 = Vector2(MainGlobals.full_screen_size)
		cv = _top
		_paint_top(f2, scene_bottom if scene_bottom > 0.0 else f2.y * 0.62)
		cv = self)
	add_child(_top)

# SHOWN AT ONCE (the user: "dont allow the initial menu screen to hold up before showing it" -- Wolves,
# hidden until its animals' pictures were rendered, took a noticeable time to appear): the poster is on
# screen from its first frame. A PART whose art is rendered after it appears (baked pictures, atlases) is
# held back and fades in on its own when ready -- drawn half-made it popped or was swapped in front of the
# player (Tip the Scales' "strange flicker") -- with `fade_in(part_ready, current, delta)`.
static func fade_in(part_ready: bool, current: float, delta: float) -> float:
	if part_ready or current > 0.0:
		return minf(1.0, current + delta * 4.0)
	return 0.0

func _process(delta: float) -> void:
	if is_visible_in_tree():
		t += delta
		_tick(delta)
		queue_redraw()
		if _top != null:
			_top.queue_redraw()

func _draw() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	cv = self
	_paint(full, bottom)

# --- for the poster to fill in ----------------------------------------------------------------------

func _setup() -> void:
	pass

func _tick(_delta: float) -> void:
	pass

func _paint(_full: Vector2, _bottom: float) -> void:
	pass

# over the poster's child nodes; the name usually goes here
func _paint_top(_full: Vector2, _bottom: float) -> void:
	pass

# --- helpers ------------------------------------------------------------------------------------------

# The name, centered near the top, and the pitch under it. `face` its color, `edge` a dark outline,
# `glow` a soft halo (alpha 0 for none), `font` the face (the player's display font by default).
# Returns the y under the pitch, where the scene may start.
func title(text: String, pitch: String, face: Color, edge: Color, glow: Color = Color(0, 0, 0, 0),
		font: Font = null, size_mobile: int = 80, pitch_col: Color = Color(0.96, 0.93, 0.86)) -> float:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var f: Font = font if font != null else get_theme_default_font()
	var fs: int = size_mobile if mobile else int(float(size_mobile) * 0.72)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while tw > full.x - 40.0 and fs > 28:
		fs -= 2
		tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y: float = (74.0 if mobile else 46.0) + float(fs) * 0.8
	var p: Vector2 = Vector2((full.x - tw) * 0.5, y)
	if glow.a > 0.0:
		for g in 3:
			cv.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 20 - g * 6, Color(glow, glow.a * (0.35 + 0.3 * float(g))))
	cv.draw_string(f, p + Vector2(0, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
	cv.draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, edge)
	cv.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, face)
	if pitch == "":
		return y + 20.0
	var pf: Font = MainGlobals.get_text_font()
	var pfs: int = 23 if mobile else 17
	var py: float = y + float(pfs) * 2.0
	for ln in wrap_text(pf, pitch, pfs, full.x - 60.0):
		var lw: float = pf.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
		cv.draw_string(pf, Vector2((full.x - lw) * 0.5, py + 2.0), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(0, 0, 0, 0.6))
		cv.draw_string(pf, Vector2((full.x - lw) * 0.5, py), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, pitch_col)
		py += float(pfs) * 1.35
	return py

static func wrap_text(font: Font, text: String, fs: int, width: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var line: String = ""
	for w in text.split(" "):
		var cand: String = w if line == "" else line + " " + w
		if line != "" and font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			out.append(line)
			line = w
		else:
			line = cand
	if line != "":
		out.append(line)
	return out

# a vertical gradient over a rect
func vgrad(r: Rect2, top: Color, bot: Color) -> void:
	cv.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bot, bot]))

# a soft round glow: rings fading out
func glow_at(c: Vector2, radius: float, col: Color, rings: int = 6) -> void:
	for k in rings:
		cv.draw_circle(c, radius * (1.0 - float(k) / float(rings)), Color(col, col.a / float(rings) * 1.6))

# an ellipse (filled), by squashing a circle
func ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	cv.draw_set_transform(c, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	cv.draw_circle(Vector2.ZERO, rx, col)
	cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# deterministic noise in 0..1 for an integer: a proper integer hash (an LCG's neighbors were correlated --
# Wolves' "scattered" grass blades all fell along one diagonal line)
static func h01(i: int) -> float:
	var x: int = (i * 0x9E3779B1) & 0xffffffff
	x ^= x >> 16
	x = (x * 0x85EBCA6B) & 0xffffffff
	x ^= x >> 13
	x = (x * 0xC2B2AE35) & 0xffffffff
	x ^= x >> 16
	return float(x & 0xffffff) / 16777216.0
