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

	_border.position = Vector2(-_w * 0.5, 0.0)  # top-center anchoring
	_border.size = Vector2(_w, total_h)

	# COVER keeps the image aspect and crops; ASPECT/FILL scale the image to fill the frame
	# (ASPECT's frame already matches the image so there's no distortion; FILL's fixed frame
	# stretches the image to a uniform aspect).
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if fit == Fit.COVER else TextureRect.STRETCH_SCALE
	_image.position = Vector2(frame_inset, frame_inset)
	_image.size = Vector2(_w - frame_inset * 2.0, img_h - frame_inset * 2.0)

	if lh > 0.0:
		var font_px: float = _w * _LABEL_FONT_FRAC
		var trim_px: float = font_px * _LABEL_TOP_TRIM
		var inner_w: float = _w - frame_inset * 2.0
		var bar_top: float = img_h - frame_inset + _LABEL_GAP  # yellow bar top (at the image bottom)
		_label.add_theme_font_size_override("font_size", int(font_px))
		_bar.position = Vector2(frame_inset, bar_top)
		_bar.size = Vector2(inner_w, font_px * _LABEL_BOX_FRAC - trim_px)
		_bar.visible = true
		# nudge the NAME up by trim_px (its top leading goes over the image) so the VISIBLE
		# name sits near the bar top -> less space ABOVE it; the space below is unchanged.
		_label.position = Vector2(frame_inset, bar_top - trim_px)
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
	_border.self_modulate = border_color
	_apply_size()

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
