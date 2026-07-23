extends Node2D

# A single Couples card: a thin zigzag ("non-definitive") white border around a full-bleed
# dino image. Built entirely in code (no .tscn). The border is a NinePatchRect of
# res://art/zig1.png (shared art) tinted (self_modulate) to the card's colour.
#
# Sizing is done in ACTUAL PIXELS via set_width() (the NinePatchRect/TextureRect sizes are
# set directly; the Node2D scale stays 1). The Node2D is positioned at the card's TOP-CENTER.

const _ZIG: Texture2D = preload("res://art/zig1.png")

# Frame thickness — thin, weris-style (the zig texture is 32x32).
var _patch_margin: int = 4    # zig nine-patch border width
var _inset: float = 6.0       # image inset = visible frame thickness

var _border: NinePatchRect = null
var _image: TextureRect = null
var _w: float = 200.0
var _aspect: float = 1.52     # height/width of the current image (frame matches it)

func _ready() -> void:
	_build()

func _build() -> void:
	if _border != null:
		return
	_border = NinePatchRect.new()
	_border.texture = _ZIG
	_border.patch_margin_left = _patch_margin
	_border.patch_margin_top = _patch_margin
	_border.patch_margin_right = _patch_margin
	_border.patch_margin_bottom = _patch_margin
	_border.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.self_modulate = Color(1, 1, 1, 1)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pin anchors top-left so the rect is driven purely by our explicit offsets.
	_border.anchor_left = 0.0
	_border.anchor_top = 0.0
	_border.anchor_right = 0.0
	_border.anchor_bottom = 0.0
	add_child(_border)

	_image = TextureRect.new()
	# SCALE: the frame is sized to the image's own aspect ratio, so the FULL image fills it.
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.clip_contents = true
	_image.anchor_left = 0.0
	_image.anchor_top = 0.0
	_image.anchor_right = 0.0
	_image.anchor_bottom = 0.0
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.add_child(_image)
	_border.clip_contents = true
	_apply_size()

func _apply_size() -> void:
	if _border == null:
		return
	var h: float = _w * _aspect
	_border.position = Vector2(-_w * 0.5, 0.0)  # top-center anchoring
	_border.size = Vector2(_w, h)
	_image.position = Vector2(_inset, _inset)
	_image.size = Vector2(_w - _inset * 2.0, h - _inset * 2.0)

func setup(tex: Texture2D, border_color: Color) -> void:
	_build()
	# Match the frame's aspect to the image so the whole image shows (no cropping).
	if tex != null:
		var ts: Vector2 = tex.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			_aspect = ts.y / ts.x
	_image.texture = tex
	_border.self_modulate = border_color
	_apply_size()

func set_width(w: float) -> void:
	_w = maxf(w, 20.0)
	_apply_size()

func card_width() -> float:
	return _w

func card_height() -> float:
	return _w * _aspect
