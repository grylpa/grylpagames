extends Node2D

# Shared zigzag-framed image card, used by dino, couples, weris and friends.
#
# A NinePatch zig border (res://art/zig1.png — shared art, tinted via self_modulate) around
# an image, optionally with a name label below it (friends-style) and optional tap handling.
# Sized in ACTUAL PIXELS via set_width(); positioned at the card's TOP-CENTER.
#
# Fit modes:
#   ASPECT  frame matches the image's own aspect -> the WHOLE image shows, no crop (dino)
#   COVER   fixed aspect, image cover-cropped to fill (weris/friends)
#   FILL    fixed aspect (uniform frame), image STRETCHED to fill -> whole image, no crop,
#           but its aspect is changed to the frame's (couples: uniform grid of cards)
#
# Config (set before setup, or via the setters):
#   frame_patch / frame_inset  frame thickness (nine-patch border + image inset)
#   fit / fixed_aspect         see above
#   tappable / press_dim       emit card_pressed(meta) on click; optional press dim
#   meta                       payload passed with card_pressed
# Label: set_label(text) + show_label(bool). The card grows/shrinks to include the label.
# set_photo(true) (friends, weris): instead of the zig border, an OLD PRINTED PHOTO -- a frame of aged
# card stock (cream, yellowing toward its edges, a stain or two) with a deckled, slightly uneven cut
# edge, a nick or two out of it, a scorched stretch along one edge, a soft shadow, and the print itself
# faintly warmed and darkened at its corners; the name in dark ink on the bottom margin rather than on
# a yellow bar. Each card's wear is its own (_paper_seed). It was a plain warm-white frame, which the
# user asked to look like a real card's edge, "cuts, burns etc.". The cuts and the scorch stay inside
# the frame's margin, so no face is ever covered.

signal card_pressed(meta)

enum Fit { ASPECT, COVER, FILL }

const _ZIG: Texture2D = preload("res://art/zig1.png")
const ASPECT_H_OVER_W: float = 334.0 / 236.0
const _LABEL_FONT_FRAC: float = 46.0 / 236.0  # friends: 46px name font on a 236-wide card
const _LABEL_BAR_COLOR: Color = Color(1, 0.8039216, 0, 1)  # friends yellow name bar
const _LABEL_GAP: float = 0.0        # px between the image bottom and the yellow bar's TOP edge
const _LABEL_BOX_FRAC: float = 1.25  # name bar height = font_size * this (governs the space BELOW the name)
const _LABEL_TOP_TRIM: float = 0.1   # x font: pulls the NAME up within the bar -> LESS space ABOVE it
                                     # (bigger = name closer to the image); leaves the below unchanged

var frame_patch: int = 4
var frame_inset: float = 6.0
var fit: int = Fit.ASPECT
var fixed_aspect: float = ASPECT_H_OVER_W
var tappable: bool = false
var press_dim: bool = false
var meta = null

var _w: float = 200.0
var _aspect: float = ASPECT_H_OVER_W  # image aspect (used in ASPECT fit)
var _label_text: String = ""
var _label_on: bool = false

var _border: NinePatchRect = null
var _image: TextureRect = null
var _label: Label = null
var _bar: ColorRect = null
var _hit: Control = null
var photo: bool = false
var _photo_bg: Control = null
var _photo_fx: Control = null
var _paper_seed: int = 0
const _PAPER: Color = Color(0.94, 0.91, 0.83)
const _PAPER_EDGE: Color = Color(0.84, 0.76, 0.60)
const _INK: Color = Color(0.20, 0.16, 0.13)
const _CHAR: Color = Color(0.16, 0.09, 0.05)
const _SINGE: Color = Color(0.55, 0.32, 0.12)

func _ready() -> void:
	_build()

func _pin(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build() -> void:
	if _border != null:
		return
	_border = NinePatchRect.new()
	_border.texture = _ZIG
	_apply_patch()
	_border.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.self_modulate = Color(1, 1, 1, 1)
	_pin(_border)
	_border.clip_contents = true
	add_child(_border)

	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.clip_contents = true
	_pin(_image)
	_border.add_child(_image)

	# yellow name bar (separate from the text so the text can be nudged up independently)
	_bar = ColorRect.new()
	_bar.color = _LABEL_BAR_COLOR
	_pin(_bar)
	_bar.hide()
	_border.add_child(_bar)

	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	var sysfont: SystemFont = SystemFont.new()
	sysfont.font_names = PackedStringArray(["Open Sans Bold", "Open Sans SemiBold", "Open Sans", "sans-serif"])
	sysfont.font_weight = 800
	_label.add_theme_font_override("font", sysfont)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP  # name hugs the image; extra bar height falls below it
	_label.clip_text = true
	_pin(_label)
	_label.hide()
	_border.add_child(_label)

	# tap area on top; only STOP (active) when tappable
	_hit = Control.new()
	_hit.anchor_left = 0.0
	_hit.anchor_top = 0.0
	_hit.anchor_right = 0.0
	_hit.anchor_bottom = 0.0
	_hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit.gui_input.connect(_on_hit_gui_input)
	add_child(_hit)

	_apply_size()

func _apply_patch() -> void:
	if _border == null:
		return
	_border.patch_margin_left = frame_patch
	_border.patch_margin_top = frame_patch
	_border.patch_margin_right = frame_patch
	_border.patch_margin_bottom = frame_patch

func _label_h() -> float:
	if not _label_on:
		return 0.0
	# bar box is shortened by the trim (the name is pulled up into the image), so the space
	# BELOW the name is unchanged while the space ABOVE it shrinks.
	return _LABEL_GAP + _w * _LABEL_FONT_FRAC * (_LABEL_BOX_FRAC - _LABEL_TOP_TRIM)

func _apply_size() -> void:
	if _border == null:
		return
	var img_aspect: float = _aspect if fit == Fit.ASPECT else fixed_aspect
	var img_h: float = _w * img_aspect
	var lh: float = _label_h()
	var total_h: float = img_h + lh
	var inset: float = _w * 0.07 if photo else frame_inset

	_border.position = Vector2(-_w * 0.5, 0.0)  # top-center anchoring
	_border.size = Vector2(_w, total_h)
	if _photo_bg != null:
		_photo_bg.visible = photo
		_photo_bg.position = _border.position
		_photo_bg.size = _border.size
		_photo_bg.queue_redraw()

	# COVER keeps the image aspect and crops; ASPECT/FILL scale the image to fill the frame
	# (ASPECT's frame already matches the image so there's no distortion; FILL's fixed frame
	# stretches the image to a uniform aspect).
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if fit == Fit.COVER else TextureRect.STRETCH_SCALE
	_image.position = Vector2(inset, inset)
	_image.size = Vector2(_w - inset * 2.0, img_h - inset * 2.0)
	if _photo_fx != null:
		_photo_fx.visible = photo
		_photo_fx.position = _image.position
		_photo_fx.size = _image.size
		_photo_fx.queue_redraw()

	if lh > 0.0:
		var font_px: float = _w * _LABEL_FONT_FRAC
		var trim_px: float = font_px * _LABEL_TOP_TRIM
		var inner_w: float = _w - inset * 2.0
		var bar_top: float = img_h - inset + _LABEL_GAP  # yellow bar top (at the image bottom)
		_label.add_theme_font_size_override("font_size", int(font_px))
		_bar.position = Vector2(inset, bar_top)
		_bar.size = Vector2(inner_w, font_px * _LABEL_BOX_FRAC - trim_px)
		_bar.visible = true
		# nudge the NAME up by trim_px (its top leading goes over the image) so the VISIBLE
		# name sits near the bar top -> less space ABOVE it; the space below is unchanged.
		_label.position = Vector2(inset, bar_top - trim_px + (inset * 0.6 if photo else 0.0))
		_label.size = Vector2(inner_w, font_px * _LABEL_BOX_FRAC)
		_label.visible = true
	else:
		_bar.visible = false
		_label.visible = false

	_hit.position = Vector2(-_w * 0.5, 0.0)
	_hit.size = Vector2(_w, total_h)
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP if tappable else Control.MOUSE_FILTER_IGNORE

# --- public API -------------------------------------------------------------

func setup(tex: Texture2D, border_color: Color) -> void:
	_build()
	if tex != null and fit == Fit.ASPECT:
		var ts: Vector2 = tex.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			_aspect = ts.y / ts.x
	_image.texture = tex
	_border.self_modulate = Color(1, 1, 1, 0) if photo else border_color
	_apply_size()

# The printed-photo look (see the header). The zig border stays as the container but draws nothing.
func set_photo(on: bool) -> void:
	_build()
	photo = on
	if on and _photo_bg == null:
		_paper_seed = randi()
		_photo_bg = Control.new()
		_photo_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_photo_bg.draw.connect(_draw_paper)
		_pin(_photo_bg)
		add_child(_photo_bg)
		move_child(_photo_bg, 0)
		_photo_fx = Control.new()
		_photo_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_photo_fx.draw.connect(_draw_print_age)
		_pin(_photo_fx)
		_border.add_child(_photo_fx)
		_border.move_child(_photo_fx, _image.get_index() + 1)
	_border.self_modulate = Color(1, 1, 1, 0) if on else Color(1, 1, 1, 1)
	_bar.color = Color(0, 0, 0, 0) if on else _LABEL_BAR_COLOR
	_label.add_theme_color_override("font_color", _INK if on else Color(0, 0, 0, 1))
	_apply_size()

# The card stock's outline: the four sides walked in small steps, each point pushed in a little at
# random (a deckled cut), with one or two V-shaped nicks; the corners slightly rounded off.
func _paper_outline(sz: Vector2, margin: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var corners: Array = [Vector2(0, 0), Vector2(sz.x, 0), sz, Vector2(0, sz.y)]
	var inward: Array = [Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)]
	var nick_side: int = rng.randi_range(0, 3)
	var nick_at: float = rng.randf_range(0.2, 0.8)
	var nick2_side: int = (nick_side + 2) % 4 if rng.randf() < 0.5 else -1
	var nick2_at: float = rng.randf_range(0.25, 0.75)
	var round_r: float = margin * 0.25
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var inn: Vector2 = inward[side]
		var length: float = a.distance_to(b)
		var steps: int = maxi(8, int(length / 6.0))
		var ph1: float = rng.randf_range(0.0, TAU)
		var ph2: float = rng.randf_range(0.0, TAU)
		for k in steps:
			var u: float = float(k) / float(steps)
			var p: Vector2 = a.lerp(b, u)
			# a smooth waver, not per-point noise: spiky outlines can fail to triangulate
			var d: float = 0.5 + 0.35 * sin(u * length * 0.21 + ph1) + 0.2 * sin(u * length * 0.53 + ph2)
			# round the corner off a touch
			var to_end: float = minf(u, 1.0 - u) * length
			if to_end < round_r:
				d += (round_r - to_end) * (round_r - to_end) / round_r * 0.6
			for nk: Array in [[nick_side, nick_at, 0.75], [nick2_side, nick2_at, 0.5]]:
				if int(nk[0]) == side:
					var dist: float = absf(u - float(nk[1])) * length
					var half: float = margin * 0.35
					if dist < half:
						d += (1.0 - dist / half) * margin * float(nk[2])
			pts.append(p + inn * d)
	return pts

func _draw_paper() -> void:
	var c: Control = _photo_bg
	var sz: Vector2 = c.size
	if sz.x < 4.0 or sz.y < 4.0:
		return
	var margin: float = _w * 0.07
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _paper_seed
	var outline: PackedVector2Array = _paper_outline(sz, margin, rng)
	# the shadow: the same shape, offset, twice (a soft edge)
	for sh: Array in [[Vector2(5, 8), 0.16], [Vector2(3, 5), 0.22]]:
		var moved: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in outline:
			moved.append(p + (sh[0] as Vector2))
		c.draw_colored_polygon(moved, Color(0, 0, 0, float(sh[1])))
	# the stock: yellowed at the edge, cream inside (a smaller lighter panel over the edge color)
	c.draw_colored_polygon(outline, _PAPER_EDGE)
	var inner: Rect2 = Rect2(Vector2(margin * 0.35, margin * 0.35), sz - Vector2(margin * 0.7, margin * 0.7))
	var steps: int = 12
	for k in steps:
		var t: float = float(k + 1) / float(steps)
		var r: Rect2 = inner.grow(-margin * 0.06 * float(k))
		c.draw_rect(r, _PAPER_EDGE.lerp(_PAPER, t), true)
	# a stain or two, faint rings of tea
	for _i in rng.randi_range(0, 2):
		var at: Vector2 = Vector2(rng.randf_range(0.1, 0.9) * sz.x, rng.randf_range(0.82, 0.97) * sz.y)
		var rr: float = margin * rng.randf_range(0.6, 1.2)
		c.draw_circle(at, rr, Color(0.60, 0.42, 0.20, 0.07), true, -1.0, true)
		c.draw_arc(at, rr, 0.0, TAU, 24, Color(0.50, 0.33, 0.15, 0.12), 1.0, true)
	# a SCORCHED stretch along one edge: a dark char right at the edge fading through brown into the
	# stock, its depth wavering, kept inside the margin
	var side: int = rng.randi_range(0, 3)
	var u0: float = rng.randf_range(0.05, 0.45)
	var u1: float = u0 + rng.randf_range(0.35, 0.55)
	var corners: Array = [Vector2(0, 0), Vector2(sz.x, 0), sz, Vector2(0, sz.y)]
	var inward: Array = [Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)]
	var a: Vector2 = corners[side]
	var b: Vector2 = corners[(side + 1) % 4]
	var inn: Vector2 = inward[side]
	var n: int = 48
	var ph: float = rng.randf_range(0.0, TAU)
	for layer: Array in [[1.15, _SINGE, 0.16], [0.95, _SINGE, 0.20], [0.75, _SINGE.darkened(0.25), 0.26],
			[0.55, _SINGE.darkened(0.5), 0.34], [0.38, _CHAR, 0.50], [0.22, _CHAR, 0.70]]:
		var poly: PackedVector2Array = PackedVector2Array()
		for k in n + 1:
			var u: float = lerpf(u0, u1, float(k) / float(n))
			poly.append(a.lerp(b, u) + inn * 1.3)
		for k in range(n, -1, -1):
			var f: float = float(k) / float(n)
			var u: float = lerpf(u0, u1, f)
			# flat along most of its length, tapering only at its two ends, the rim ragged
			var swell: float = smoothstep(0.0, 0.18, f) * smoothstep(1.0, 0.82, f)
			var ragged: float = 0.72 + 0.18 * sin(f * 8.0 + ph) + 0.10 * sin(f * 19.0 + ph * 2.0)
			var depth: float = margin * float(layer[0]) * swell * ragged
			poly.append(a.lerp(b, u) + inn * (1.3 + depth))
		c.draw_colored_polygon(poly, Color(layer[1] as Color, float(layer[2])))

# The print itself, aged: faintly warmed, and darker toward its corners.
static var _age_tex: GradientTexture2D = null

func _draw_print_age() -> void:
	var c: Control = _photo_fx
	if _age_tex == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 1))
		g.add_point(0.55, Color(0, 0, 0, 0.0))
		_age_tex = GradientTexture2D.new()
		_age_tex.gradient = g
		_age_tex.fill = GradientTexture2D.FILL_RADIAL
		_age_tex.fill_from = Vector2(0.5, 0.5)
		_age_tex.fill_to = Vector2(1.0, 1.0)
		_age_tex.width = 128
		_age_tex.height = 128
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1.0, 0.82, 0.55, 0.08), true)
	c.draw_texture_rect(_age_tex, Rect2(Vector2.ZERO, c.size), false, Color(0.25, 0.15, 0.05, 0.35))

func set_frame(patch_margin: int, inset: float) -> void:
	frame_patch = patch_margin
	frame_inset = inset
	_apply_patch()
	_apply_size()

func set_label(text: String) -> void:
	_label_text = text
	_label.text = text
	_label_on = text != ""
	_apply_size()

func show_label(v: bool) -> void:
	_label_on = v  # reserve/hide the label area (works even before a name is set)
	_apply_size()

func set_width(w: float) -> void:
	_w = maxf(w, 20.0)
	_apply_size()

func set_card_position(p: Vector2) -> void:
	position = p

func card_width() -> float:
	return _w

func card_height() -> float:
	var img_aspect: float = _aspect if fit == Fit.ASPECT else fixed_aspect
	return _w * img_aspect + _label_h()

func scaled_size() -> Vector2:
	return Vector2(_w, card_height())

func scaled_h() -> float:
	return card_height()

func _on_hit_gui_input(event: InputEvent) -> void:
	if not tappable:
		return
	# handle only mouse-button (touch is covered by mouse-emulation; avoids double-fire)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if press_dim:
				modulate = Color(0.9, 0.9, 0.9)
		else:
			if press_dim:
				modulate = Color(1, 1, 1)
			card_pressed.emit(meta)
			get_viewport().set_input_as_handled()
