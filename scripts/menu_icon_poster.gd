extends Control

# THE FALLBACK POSTER (main_menu.gd, for a game whose main scene has no `menu_backdrop()`): the game's
# chooser icon made into the whole screen -- its own colors as a soft wash from edge to edge, the icon
# itself large, crisp and floating gently in the middle, and the game's name and pitch above it. The user
# (2026-11-17): "when no poster, we can draw the game icon over the entire screen instead of the poster".
# The icons are 200 px, so the full-screen layer is the icon shrunk to a few pixels and spread smooth (a
# color field, never a blurry enlargement of the picture); only the middle copy shows the picture, at
# about twice its size.
#
# The menu also opens mid-game: this shows nothing of the game in play.

const ACCENT: Color = Color(0.976, 0.792, 0.353)

var _icon: Texture2D = null
var _wash: Texture2D = null
var _title: String = ""
var _pitch: String = ""
var _t: float = 0.0
var scene_bottom: float = -1.0

func setup(folder: String, title: String, pitch: String) -> void:
	_title = title
	_pitch = pitch
	var path: String = "res://%s/art/game_screen_200.png" % folder
	if ResourceLoader.exists(path):
		_icon = load(path)
		var img: Image = _icon.get_image()
		if img != null:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.resize(6, 10, Image.INTERPOLATE_BILINEAR)
			img.resize(60, 100, Image.INTERPOLATE_CUBIC)
			_wash = ImageTexture.create_from_image(img)

func menu_draws_title() -> bool:
	return true

func set_scene_bottom(y: float) -> void:
	scene_bottom = y
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()

func _draw() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var mobile: bool = MainGlobals.is_mobile()
	draw_rect(Rect2(Vector2.ZERO, full), Color(0.04, 0.045, 0.07))
	if _wash != null:
		draw_texture_rect(_wash, Rect2(Vector2.ZERO, full), false, Color(0.62, 0.62, 0.66))
	# darker at the top and the foot, where the words and the panel are
	var top_c: Color = Color(0.02, 0.02, 0.04, 0.78)
	var mid_c: Color = Color(0.02, 0.02, 0.04, 0.0)    # fades to NOTHING: ending at 0.1 left a hard line (the user)
	var h: float = full.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(full.x, 0), Vector2(full.x, h * 0.42), Vector2(0, h * 0.42)]),
		PackedColorArray([top_c, top_c, mid_c, mid_c]))
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.45), Vector2(full.x, h * 0.45), Vector2(full.x, h), Vector2(0, h)]),
		PackedColorArray([mid_c, mid_c, top_c, top_c]))
	# the name and the pitch
	var font: Font = get_theme_default_font()
	var tfs: int = 70 if mobile else 52
	var tw: float = font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	while tw > full.x - 40.0 and tfs > 30:
		tfs -= 2
		tw = font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var ty: float = (70.0 if mobile else 44.0) + float(tfs) * 0.8
	draw_string(font, Vector2((full.x - tw) * 0.5, ty + 5.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(0, 0, 0, 0.55))
	draw_string_outline(font, Vector2((full.x - tw) * 0.5, ty), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, 6, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2((full.x - tw) * 0.5, ty), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, ACCENT)
	var pf: Font = MainGlobals.get_text_font()
	var pfs: int = 23 if mobile else 17
	var lines: PackedStringArray = _wrap(pf, _pitch, pfs, full.x - 60.0)
	var py: float = ty + float(pfs) * 1.9
	for ln in lines:
		var lw: float = pf.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
		draw_string(pf, Vector2((full.x - lw) * 0.5, py + 2.0), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(0, 0, 0, 0.5))
		draw_string(pf, Vector2((full.x - lw) * 0.5, py), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, Color(0.96, 0.93, 0.86))
		py += float(pfs) * 1.35
	# the icon, between the words and the panel, floating
	if _icon == null:
		return
	var bottom: float = scene_bottom if scene_bottom > 0.0 else h * 0.62
	var room_top: float = py + 10.0
	var side: float = minf(full.x * 0.66, bottom - room_top - 40.0)
	if side < 80.0:
		return
	var ctr: Vector2 = Vector2(full.x * 0.5, (room_top + bottom) * 0.5 + 4.0 * sin(_t * 1.1))
	var ang: float = deg_to_rad(1.6) * sin(_t * 0.7)
	var sc: float = 1.0 + 0.012 * sin(_t * 0.9)
	draw_set_transform(ctr, ang, Vector2(sc, sc))
	var r: Rect2 = Rect2(-Vector2(side, side) * 0.5, Vector2(side, side))
	for k in 6:
		draw_rect(Rect2(r.position + Vector2(0, 10), r.size).grow(14.0 - float(k) * 2.4), Color(0, 0, 0, 0.07))
	draw_texture_rect(_icon, r, false)
	draw_rect(r, Color(ACCENT, 0.75), false, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _wrap(font: Font, text: String, fs: int, width: float) -> PackedStringArray:
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
