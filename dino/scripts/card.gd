extends Node2D

# A single Dino card: a zigzag ("non-definitive") border around a full-bleed image.
# Built entirely in code (no .tscn). The border is a NinePatchRect of res://art/zig1.png
# tinted (self_modulate) to the card's colour — white for dinos, yellow for people.
#
# Sizing is done in ACTUAL PIXELS via set_width() (the NinePatchRect/TextureRect sizes are
# set directly; the Node2D scale stays 1) — scaling a bare Control via Node2D.scale is
# unreliable, so we avoid it. The Node2D is positioned at the card's TOP-CENTER.

const UNSCALED_W: float = 236.0
const UNSCALED_H: float = 334.0
const ASPECT_H_OVER_W: float = UNSCALED_H / UNSCALED_W
const INSET: float = 8.0            # image inset = frame thickness; matches PATCH_MARGIN
const PATCH_MARGIN: int = 8         # zig nine-patch border width (texture is 32x32)
const _ZIG: Texture2D = preload("res://art/zig1.png")

var _border: NinePatchRect = null
var _image: TextureRect = null
var _w: float = 200.0
var _aspect: float = ASPECT_H_OVER_W  # height/width of the current image (frame matches it)

func _ready() -> void:
	_build()

func _build() -> void:
	if _border != null:
		return
	_border = NinePatchRect.new()
	_border.texture = _ZIG
	_border.patch_margin_left = PATCH_MARGIN
	_border.patch_margin_top = PATCH_MARGIN
	_border.patch_margin_right = PATCH_MARGIN
	_border.patch_margin_bottom = PATCH_MARGIN
	_border.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_border.self_modulate = Color(1, 1, 1, 1)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pin anchors to top-left so the rect is driven purely by our explicit offsets
	# (position/size) and never gets re-laid-out to the viewport size.
	_border.anchor_left = 0.0
	_border.anchor_top = 0.0
	_border.anchor_right = 0.0
	_border.anchor_bottom = 0.0
	add_child(_border)

	_image = TextureRect.new()
	# SCALE (not COVERED): the frame is sized to the image's own aspect ratio, so the
	# FULL image fills the frame with no cropping and negligible distortion.
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	# Without EXPAND_IGNORE_SIZE the TextureRect keeps the photo's native size as its
	# minimum, ignores the rect we set, and draws full-res from the top-left — spilling
	# past the frame's bottom-right. IGNORE_SIZE makes it honor our (w-INSET) rect.
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
	_image.position = Vector2(INSET, INSET)
	_image.size = Vector2(_w - INSET * 2.0, h - INSET * 2.0)

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
