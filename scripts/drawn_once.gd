class_name DrawnOnce
extends Control
# A LAYER DRAWN ONCE (2026-11-19). The menu posters redrew their still parts -- skies, walls, rock, titles -- every frame,
# and on a mid-range phone every shape costs: a poster could spend 20-40 ms a frame on parts that never change (14-25
# fps, where phones run far richer games at 60). This draws `fn(d)` ONCE onto an off-screen canvas of the screen's own
# pixel size (as sharp as drawing straight to the screen), and each frame shows only that picture: one draw.
#
# It is redrawn when queue_redraw() is called on it -- call that only when the layout changes. Full-screen, anchored to
# its parent; `fn` draws in the parent's units, as it would on a plain Control.
#
#   - the canvas is 16-bit float: a poster's soft glows are many layers at 1-3% (a moon's corona of 26 circles), which
#     an 8-bit canvas rounds away;
#   - it is shown with PREMULTIPLIED alpha: what was drawn into the transparent canvas is stored premultiplied, and
#     blended the usual way every soft glow came out darker than drawn straight to the screen;
#   - `picture` (optional) returns a ready picture to show instead (a still layer's baked WebP, when it fits the layout).

var fn: Callable
var picture: Callable = Callable()
var inner_material: Material = null      # a material for the off-screen canvas `fn` draws on (a shader backdrop)

var _vp: SubViewport = null
var _inner: Control = null
static var _premult_mat: CanvasItemMaterial = null

static func make(draw_fn: Callable) -> DrawnOnce:
	var d: DrawnOnce = DrawnOnce.new()
	d.fn = draw_fn
	return d

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	if picture.is_valid():
		var tex: Texture2D = picture.call()
		if tex != null:
			material = null
			draw_texture(tex, Vector2.ZERO)
			return
	material = _premult()
	draw_texture_rect(_render(full), Rect2(Vector2.ZERO, full), false)

# (re)render the drawing; the texture on the screen follows by itself
func _render(full: Vector2) -> Texture2D:
	var k: float = _px_per_unit()
	if _vp == null:
		_vp = SubViewport.new()
		_vp.transparent_bg = true
		_vp.disable_3d = true
		_vp.use_hdr_2d = true
		_inner = Control.new()
		_inner.material = inner_material
		_inner.draw.connect(func() -> void: fn.call(_inner))
		_vp.add_child(_inner)
		add_child(_vp)
	var want: Vector2i = Vector2i(ceili(full.x * k), ceili(full.y * k))
	if _vp.size != want:
		_vp.size = want
		_vp.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * k)
		_inner.size = full
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_inner.queue_redraw()
	return _vp.get_texture()

# how many screen pixels a unit of the canvas is (the canvas is 680 wide; a phone's screen ~1080-1200)
func _px_per_unit() -> float:
	var w: float = float(get_viewport().get_visible_rect().size.x)
	var real: float = float(get_window().size.x) if get_window() != null else w
	return clampf(real / maxf(1.0, w), 1.0, 3.0)

static func _premult() -> CanvasItemMaterial:
	if _premult_mat == null:
		_premult_mat = CanvasItemMaterial.new()
		_premult_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _premult_mat
