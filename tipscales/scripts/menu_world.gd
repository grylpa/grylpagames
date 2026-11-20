extends Control

# THE OPENING POSTER (main.gd menu_backdrop(); the shared main_menu.gd puts it behind a slim panel at the
# foot -- level, PLAY, the links -- and leaves the rest of the screen to it). The user, 2026-11-17: the
# first screen "needs to create interest and elicit the player to continue and play the game. it needs to
# be beautiful, with something that is personal for each game". So: the game's name in brass type at the
# top, its one-line pitch under it, and THE BALANCE -- a big brass weigh-house scale on the counter, crates
# on both pans, rocking slowly as if someone had just set the last crate down, its needle swinging over a
# dial -- against the weigh-house wall: a tall arched window with the night outside, and a shelf of the
# house's brass standard weights, largest to smallest. (It stood in front of the game's rack of crates
# first; the user: no game scene behind a poster -- "put some interesting and relevant background".)
#
# MADE UP, NEVER THE BOARD: the menu also opens mid-game, so nothing here comes from the puzzle in play.
# Drawn with the game's own art (scales_art.gd, the shaders level.gd uses), its textures baked once.

const PUZZLE = preload("res://tipscales/scripts/puzzle.gd")
const ART = preload("res://tipscales/scripts/scales_art.gd")
const BG_SHADER: Shader = preload("res://tipscales/scripts/weighhouse.gdshader")
const CRATE_SHADER: Shader = preload("res://tipscales/scripts/crate.gdshader")
const BAKE_SCALE: float = 2.0

const ROWS: int = 2          # the balance's geometry is laid out from a rack's size (no rack is drawn)
const COLS: int = 5
const BRASS_LIGHT: Color = Color(1.0, 0.90, 0.62)

var scene_bottom: float = -1.0       # where the menu's panel starts (set_scene_bottom); the scene is above it

var _bg: DrawnOnce = null
var _fg: Control = null
var _cv: CanvasItem = null           # what the foreground's helpers draw on: _fg_back, _fg or _fg_title
var _fg_back: DrawnOnce = null       # the standard weights on the counter (still)
var _fg_title: DrawnOnce = null      # the name and its pitch (still)
var _white: ImageTexture = null
var _pan_hold: Array = []        # [Control, Control]: moved to the hooks each frame
var _pan_draw: Array = []        # [DrawnOnce, DrawnOnce]: each pan drawn once, at rest
var _pan_rest: Array = []        # the hooks at rest (the beam level)
var _pan_hang: float = 0.0
# THE BEAM: drawn once, level, and TURNED as a picture about the pivot each frame (drawn live as it rocked, its long
# polygon edges stepped and crawled -- "severe antialiasing issues", the user, 2026-11-20; a picture turned is filtered,
# its edges stay smooth). The knife-edge's cap, round, stays put over it
var _beam_hold: Control = null
var _beam_draw: DrawnOnce = null
var _cap: DrawnOnce = null
var _face: Font = null
var _crate_tex: Array = []
var _board: Rect2 = Rect2()
var _cell: Vector2 = Vector2()
var _gap: float = 10.0
var _counter_y: float = 0.0
var _title_y: float = 0.0
var _title_fs: int = 72
var _pitch_fs: int = 22
var _t: float = 0.0

func menu_draws_title() -> bool:
	return true

func set_scene_bottom(y: float) -> void:
	if absf(y - scene_bottom) > 0.5:
		scene_bottom = y
		_layout()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_face = MainGlobals.get_text_font()      # the crates' and weights' letters and figures: the font for clarity
	# THE BACKDROP: its shader is still (no TIME) -- rendered ONCE (DrawnOnce), where it ran on every pixel every frame
	# (11 ms a frame on a mid-range phone)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = BG_SHADER
	var wi: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	wi.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(wi)
	var bgd: DrawnOnce = DrawnOnce.make(func(d: Control) -> void:
		d.draw_texture_rect(_white, Rect2(Vector2.ZERO, Vector2(MainGlobals.full_screen_size)), false))
	bgd.inner_material = m
	_bg = bgd
	add_child(_bg)
	# THE WALL in three layers under the balance: the papered wall (drawn once), the view through the
	# window (moving: clouds over the moon), and the window's casing, the curtains and the pictures (once)
	# (the still two drawn ONCE, DrawnOnce: kept as plain layers, their thousands of shapes were still rendered every frame)
	for k in 3:
		var which: int = k
		var layer_c: Control = null
		if k == 1:
			layer_c = Control.new()
			layer_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer_c.set_anchors_preset(Control.PRESET_FULL_RECT)
			var live_c: Control = layer_c
			layer_c.draw.connect(func() -> void: _draw_wall_layer(live_c, which))
		else:
			layer_c = DrawnOnce.make(func(d: Control) -> void: _draw_wall_layer(d, which))
		add_child(layer_c)
		_wall_layers.append(layer_c)
	# THE FOREGROUND: the weights (once), the balance (live: it rocks), the name (once), in that order
	_fg_back = DrawnOnce.make(func(d: Control) -> void:
		if _cell.x > 0.0:
			_cv = d
			_draw_wall(Vector2(MainGlobals.full_screen_size))
			_draw_balance(Vector2(MainGlobals.full_screen_size), true))
	add_child(_fg_back)
	# THE PANS: each hangs upright from its end of the beam, so the whole of it -- chains, bowl, crates, weight -- only
	# MOVES as the beam rocks: drawn once at rest (DrawnOnce) and carried to its hook each frame. Drawn every frame, its
	# ninety small chain links and the crates cost a phone several ms; carried, the picture may soften a hair as it
	# slides between pixels (the user, 2026-11-20: simplify only what is small and unnoticed). Under the beam, which
	# lies over the chains' hooks.
	for k in 2:
		var hold: Control = Control.new()
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hold)
		var which: int = k
		var pan_d: DrawnOnce = DrawnOnce.make(func(d: Control) -> void:
			if _cell.x > 0.0 and _pan_rest.size() == 2:
				_cv = d
				_draw_pan(_pan_rest[which], _pan_hang, which, MainGlobals.is_mobile()))
		hold.add_child(pan_d)
		_pan_hold.append(hold)
		_pan_draw.append(pan_d)
	_fg = Control.new()
	_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg.draw.connect(_draw_fg)
	add_child(_fg)
	_beam_hold = Control.new()
	_beam_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_beam_hold)
	_beam_draw = DrawnOnce.make(func(d: Control) -> void:
		if _cell.x > 0.0:
			_cv = d
			_draw_beam_level())
	_beam_hold.add_child(_beam_draw)
	_cap = DrawnOnce.make(func(d: Control) -> void:
		if _cell.x > 0.0:
			_cv = d
			_draw_cap())
	add_child(_cap)
	_fg_title = DrawnOnce.make(func(d: Control) -> void:
		if _cell.x > 0.0:
			_cv = d
			_draw_title(Vector2(MainGlobals.full_screen_size)))
	add_child(_fg_title)
	resized.connect(_layout)
	_layout.call_deferred()

# ON SCREEN AT ONCE (the user: no menu may hold up before it shows): the crates' painted pictures render
# a frame or two in; until then the crates on the pans are simply not drawn (drawn flat and then swapped,
# they flickered), so they appear with the screen's first moments
var _wall_layers: Array = []

# the balance's frame: the pivot, the beam's half-length, the column's height
func _balance_geom(full: Vector2) -> Array:
	var mobile: bool = MainGlobals.is_mobile()
	var foot: float = _counter_y + (34.0 if mobile else 22.0)
	var top: float = _board.position.y + _board.size.y * 0.25
	var hs: float = foot - top
	var L: float = minf(full.x * 0.30, 210.0)
	return [Vector2(full.x * 0.5, top + hs * 0.10), L, hs]

func _place_pans() -> void:
	if _pan_rest.size() != 2:
		return
	var bg: Array = _balance_geom(Vector2(MainGlobals.full_screen_size))
	var pivot: Vector2 = bg[0]
	var L: float = bg[1]
	var a: float = _beam_angle()
	var ends: Array = [pivot + Vector2(-L, 0).rotated(a), pivot + Vector2(L, 0).rotated(a)]
	for k in 2:
		(_pan_hold[k] as Control).position = Vector2(ends[k]) - Vector2(_pan_rest[k])
	_beam_hold.pivot_offset = pivot
	_beam_hold.rotation = a

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		_place_pans()
		_fg.queue_redraw()
		if _wall_layers.size() == 3:
			(_wall_layers[1] as Control).queue_redraw()

func _layout() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	if full.x < 4.0:
		return
	var mobile: bool = MainGlobals.is_mobile()
	_bg.position = Vector2.ZERO
	_bg.size = full
	_fg.position = Vector2.ZERO
	_fg.size = full
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	_title_fs = 74 if mobile else 56
	_pitch_fs = 23 if mobile else 17
	_title_y = (64.0 if mobile else 40.0) + float(_title_fs) * 0.8
	var side: float = 14.0
	var cw: float = (full.x - side * 2.0 - _gap * float(COLS - 1)) / float(COLS)
	_cell = Vector2(cw, cw * 0.80)
	var rack_top: float = _title_y + float(_pitch_fs) * 2.4 + (26.0 if mobile else 14.0)
	_board = Rect2(side, rack_top, full.x - side * 2.0, float(ROWS) * _cell.y + float(ROWS - 1) * _gap)
	# the counter the balance stands on: just above the panel (it stood 70 / 34 above, an empty band the user asked to use,
	# 2026-11-19), so the balance grows down into the room
	_counter_y = maxf(_board.end.y + 20.0, bottom - (18.0 if mobile else 10.0))
	var m: ShaderMaterial = _bg.inner_material as ShaderMaterial
	m.set_shader_parameter("size", full)
	# the wall alone: no rack of crates behind the balance (the board is put out of sight)
	m.set_shader_parameter("board", Vector4(0.0, -5000.0, 0.0, 0.0))
	m.set_shader_parameter("rows", 0.0)
	m.set_shader_parameter("pitch", _cell.y + _gap)
	m.set_shader_parameter("cell_h", _cell.y)
	m.set_shader_parameter("counter_y", _counter_y)
	m.set_shader_parameter("lamp", Vector2(full.x * 0.5, _board.end.y))
	_bake()
	# the pans at rest, and the part of the screen each is drawn in (the crates stand above the bowl's rim)
	var bg2: Array = _balance_geom(full)
	var piv: Vector2 = bg2[0]
	var half_l: float = bg2[1]
	_pan_hang = float(bg2[2]) * 0.50
	_pan_rest = [piv + Vector2(-half_l, 0.0), piv + Vector2(half_l, 0.0)]
	var pw: float = 186.0 if mobile else 140.0
	for k in 2:
		(_pan_hold[k] as Control).size = full          # (a zero-sized holder's picture was never drawn)
		var hk: Vector2 = _pan_rest[k]
		var dd: DrawnOnce = _pan_draw[k]
		dd.area = Rect2(hk.x - pw * 0.5 - 24.0, hk.y - 24.0, pw + 48.0, _pan_hang + 70.0)
		dd.queue_redraw()
	_beam_hold.size = full
	_beam_draw.area = Rect2(piv.x - half_l - 40.0, piv.y - 40.0, half_l * 2.0 + 80.0, 80.0)
	_beam_draw.queue_redraw()
	_cap.queue_redraw()
	_place_pans()
	_fg.queue_redraw()
	for pd in _pan_draw:
		(pd as Control).queue_redraw()
	for dl in [_bg, _fg_back, _fg_title]:
		(dl as Control).queue_redraw()
	for l in _wall_layers:
		(l as Control).queue_redraw()

var _baked_for: Vector2 = Vector2.ZERO

func _bake() -> void:
	if _baked_for == _cell or not is_inside_tree():
		return
	_baked_for = _cell
	# ALL SIX AT ONCE, in one frame (one after another, a frame each, the crates appeared late)
	var vps: Array = []
	var px: Vector2i = Vector2i(maxi(4, int(_cell.x * BAKE_SCALE)), maxi(4, int(_cell.y * BAKE_SCALE)))
	for r in 3:
		for variant in 2:
			var vp: SubViewport = SubViewport.new()
			vp.size = px
			vp.transparent_bg = true
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			var cr: ColorRect = ColorRect.new()
			cr.size = Vector2(px)
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = CRATE_SHADER
			mat.set_shader_parameter("size", _cell)
			mat.set_shader_parameter("paint", ART.set_color(r))
			mat.set_shader_parameter("seed", float(r * 7 + variant * 3 + 1))
			cr.material = mat
			vp.add_child(cr)
			add_child(vp)
			vps.append(vp)
	await RenderingServer.frame_post_draw
	var crates: Array = []
	for vp in vps:
		var img: Image = (vp as SubViewport).get_texture().get_image()
		(vp as SubViewport).queue_free()
		if img != null:
			img.generate_mipmaps()
			crates.append(ImageTexture.create_from_image(img))
		else:
			crates.append(null)
	_crate_tex = crates
	_fg.queue_redraw()
	for pd in _pan_draw:
		(pd as Control).queue_redraw()

func _bake_one(shader: Shader, sz: Vector2, params: Dictionary) -> Texture2D:
	var px: Vector2i = Vector2i(maxi(4, int(sz.x * BAKE_SCALE)), maxi(4, int(sz.y * BAKE_SCALE)))
	var vp: SubViewport = SubViewport.new()
	vp.size = px
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cr: ColorRect = ColorRect.new()
	cr.size = Vector2(px)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("size", sz)
	for k in params.keys():
		mat.set_shader_parameter(k, params[k])
	cr.material = mat
	vp.add_child(cr)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _tex(row: int, col: int) -> Texture2D:
	var k: int = row * 2 + (col % 2)
	return _crate_tex[k] if k < _crate_tex.size() else null

# --- drawing --------------------------------------------------------------------------------------------

func _draw_fg() -> void:
	if _cell.x <= 0.0:
		return
	var full: Vector2 = _fg.size
	_cv = _fg
	_draw_balance(full, false)

# the house's brass standard weights on the counter (the wall itself is _draw_wall_layer's)
func _draw_wall(full: Vector2) -> void:
	# the house's standard weights, standing on the counter in a row, largest to smallest
	var sx0: float = full.x * 0.70
	var sx1: float = full.x * 0.97
	var sy: float = _counter_y + 26.0
	var x: float = sx0
	var sizes: Array = [1.0, 0.82, 0.66, 0.52, 0.40, 0.30]
	var unit: float = (sx1 - sx0) / 4.2
	for k in 3:
		_cv.draw_set_transform(Vector2((sx0 + sx1) * 0.5, sy + 2.0), 0.0, Vector2(1.0, 0.16))
		_cv.draw_circle(Vector2.ZERO, (sx1 - sx0) * (0.55 - 0.08 * float(k)), Color(0, 0, 0, 0.12))
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in sizes.size():
		var ws: float = unit * float(sizes[k])
		var c: Vector2 = Vector2(x + ws * 0.5, sy - ws * 0.5)
		_cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-ws * 0.46, ws * 0.5), c + Vector2(ws * 0.46, ws * 0.5),
			c + Vector2(ws * 0.32, -ws * 0.28), c + Vector2(-ws * 0.32, -ws * 0.28)]), ART.BRASS_DARK)
		_cv.draw_colored_polygon(PackedVector2Array([c + Vector2(-ws * 0.40, ws * 0.44), c + Vector2(-ws * 0.02, ws * 0.44),
			c + Vector2(-ws * 0.06, -ws * 0.24), c + Vector2(-ws * 0.28, -ws * 0.24)]), ART.BRASS)
		_cv.draw_arc(c + Vector2(0.0, -ws * 0.36), ws * 0.13, PI, TAU, 10, ART.BRASS_DARK, maxf(2.0, ws * 0.06))
		x += ws + 6.0

# --- THE WALL (2026-11-17; the user: the window "somewhat strange and plain as are the curtains", a moon
# "too plain", the pictures to be improved "both inside, their frame and how they are hanged", "what about the
# wall?") ----------------------------------------------------------------------------------------------------

const EDGE: Color = Color(0.07, 0.04, 0.02, 0.85)     # the balance's dark edge, against the wall
const WOOD_D: Color = Color(0.16, 0.09, 0.04)
const WOOD: Color = Color(0.30, 0.18, 0.08)
const WOOD_L: Color = Color(0.46, 0.30, 0.15)
const VELVET_D: Color = Color(0.20, 0.03, 0.05)
const VELVET: Color = Color(0.44, 0.07, 0.10)
const VELVET_L: Color = Color(0.62, 0.16, 0.18)
const GILT_D: Color = Color(0.45, 0.32, 0.10)
const GILT: Color = Color(0.78, 0.60, 0.26)
const GILT_L: Color = Color(0.98, 0.86, 0.52)

func _wall_geom() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var top: float = _board.position.y
	var h: float = _counter_y - top - 20.0
	var ww: float = full.x * 0.34
	# all clear of the name and its pitch above: the rail and the pelmet ran into the pitch line
	var wr: Rect2 = Rect2((full.x - ww) * 0.5, top + h * 0.10, ww, h * 0.80)
	return {"full": full, "top": top, "h": h, "ww": ww, "wr": wr, "wy": top + h * 0.62, "rail": top - h * 0.02}

func _draw_wall_layer(d: Control, which: int) -> void:
	if _cell.x <= 0.0:
		return
	var g: Dictionary = _wall_geom()
	match which:
		0:
			_paper(d, g)
		1:
			_view(d, g)
		2:
			_window_dressing(d, g)
			_pictures(d, g)

# THE PAPERED WALL above the wainscot: muted olive stripes with a small gilt motif between them, aged
# toward the corners; a picture rail high up; the oak wainscot below with raised, lit panels
func _paper(d: Control, g: Dictionary) -> void:
	var full: Vector2 = g["full"]
	var wy: float = g["wy"]
	var stripe: float = 30.0
	var x: float = 0.0
	var k: int = 0
	while x < full.x:
		d.draw_rect(Rect2(x, 0.0, stripe * 0.5, wy), Color(0.30, 0.27, 0.14, 0.22))
		d.draw_line(Vector2(x, 0.0), Vector2(x, wy), Color(0.70, 0.56, 0.26, 0.10), 1.0)
		var y: float = 30.0 + float(k % 2) * 30.0
		while y < wy:
			var c: Vector2 = Vector2(x + stripe * 0.75, y)
			d.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 0), c + Vector2(0, 6), c + Vector2(-4, 0)]), Color(0.78, 0.62, 0.30, 0.14))
			d.draw_circle(c + Vector2(0, -10), 1.6, Color(0.78, 0.62, 0.30, 0.12))
			y += 60.0
		x += stripe
		k += 1
	# the picture rail
	var rail: float = g["rail"]
	d.draw_rect(Rect2(0.0, rail, full.x, 8.0), WOOD)
	d.draw_rect(Rect2(0.0, rail, full.x, 2.0), WOOD_L)
	d.draw_rect(Rect2(0.0, rail + 8.0, full.x, 4.0), Color(0, 0, 0, 0.25))
	# the wainscot: a chair rail, raised panels lit from the window's side
	d.draw_rect(Rect2(0.0, wy, full.x, _counter_y - wy), Color(0.19, 0.10, 0.05))
	d.draw_rect(Rect2(0.0, wy - 4.0, full.x, 12.0), WOOD)
	d.draw_rect(Rect2(0.0, wy - 4.0, full.x, 3.0), WOOD_L)
	d.draw_rect(Rect2(0.0, wy + 8.0, full.x, 3.0), Color(0, 0, 0, 0.35))
	var pw: float = full.x / 6.0
	for p in 6:
		var pr: Rect2 = Rect2(float(p) * pw + 10.0, wy + 22.0, pw - 20.0, _counter_y - wy - 34.0)
		if pr.size.y < 14.0:
			continue
		d.draw_rect(pr, Color(0.23, 0.13, 0.06))
		d.draw_rect(pr.grow(-7.0), Color(0.26, 0.15, 0.07))
		d.draw_line(pr.position, Vector2(pr.end.x, pr.position.y), WOOD_D, 3.0)
		d.draw_line(pr.position, Vector2(pr.position.x, pr.end.y), WOOD_D, 3.0)
		d.draw_line(Vector2(pr.position.x, pr.end.y), pr.end, WOOD_L, 2.0)
		d.draw_line(Vector2(pr.end.x, pr.position.y), pr.end, WOOD_L, 2.0)
	# age: the corners darker
	for side in [0.0, 1.0]:
		var x0: float = side * full.x
		var x1: float = x0 + (full.x * 0.25 if side == 0.0 else -full.x * 0.25)
		d.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, _counter_y), Vector2(x0, _counter_y)]),
			PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.35)]))

# the window's opening: an arch on a rectangle
func _arch_pts(r: Rect2, inset: float) -> PackedVector2Array:
	var rad: float = r.size.x * 0.5 - inset
	var c: Vector2 = Vector2(r.get_center().x, r.position.y + r.size.x * 0.5)
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2(r.position.x + inset, r.end.y - inset))
	for k in 25:
		var a: float = PI + PI * float(k) / 24.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	pts.append(Vector2(r.end.x - inset, r.end.y - inset))
	return pts

# THE VIEW through the window: a night sky deepening upward, a town's roofline with a spire and a few lit
# windows, slow clouds crossing the moon -- a moon with a halo, a lit limb and its seas
func _view(d: Control, g: Dictionary) -> void:
	var wr: Rect2 = g["wr"]
	var ww: float = g["ww"]
	var glass: PackedVector2Array = _arch_pts(wr, 10.0)
	var cols: PackedColorArray = PackedColorArray()
	for p in glass:
		var u: float = clampf((p.y - wr.position.y) / wr.size.y, 0.0, 1.0)
		cols.append(Color(0.04, 0.06, 0.16).lerp(Color(0.16, 0.24, 0.38), u))
	d.draw_polygon(glass, cols)
	var inner: Rect2 = wr.grow(-10.0)
	for k in 22:
		var sp: Vector2 = inner.position + Vector2(h01_local(k * 3 + 1) * inner.size.x, h01_local(k * 3 + 2) * inner.size.y * 0.55 + ww * 0.15)
		d.draw_circle(sp, 0.9 + h01_local(k * 7) * 0.9, Color(0.92, 0.94, 1.0, 0.35 + 0.35 * (0.5 + 0.5 * sin(_t * 0.4 + float(k)))))
	var moon: Vector2 = Vector2(wr.position.x + ww * 0.30, wr.position.y + ww * 0.62)
	var mr: float = ww * 0.13
	for k in 12:
		d.draw_circle(moon, mr * (3.0 - 2.0 * float(k) / 12.0), Color(0.85, 0.88, 1.0, 0.018))
	d.draw_circle(moon, mr, Color(0.86, 0.85, 0.76))
	for k in 10:
		var f: float = float(k + 1) / 10.0
		d.draw_circle(moon + Vector2(-mr, -mr) * 0.18 * f, mr * (1.0 - 0.35 * f), Color(0.86, 0.85, 0.76).lerp(Color(1.0, 0.99, 0.92), f))
	for cr in [Vector3(0.30, -0.20, 0.22), Vector3(-0.25, 0.25, 0.16), Vector3(0.05, 0.40, 0.12), Vector3(-0.35, -0.30, 0.10)]:
		d.draw_circle(moon + Vector2(cr.x, cr.y) * mr, mr * cr.z, Color(0.70, 0.70, 0.66, 0.55))
	# clouds drifting slowly across, soft
	for k in 3:
		var span: float = inner.size.x + 160.0
		var cx: float = inner.position.x - 80.0 + fmod(float(k) * 97.0 + _t * (5.0 + 2.0 * float(k)), span)
		var cy: float = inner.position.y + ww * (0.45 + 0.35 * float(k))
		for j in 4:
			for gg in 3:
				d.draw_circle(Vector2(cx + float(j) * 22.0 - 33.0, cy + 6.0 * sin(float(j + k))), (16.0 + 4.0 * float(j % 2)) * (1.2 - 0.2 * float(gg)),
					Color(0.40, 0.45, 0.60, 0.10))
	# the town's roofline at the bottom of the view, a spire, a few lit windows
	var base_y: float = wr.end.y - 10.0
	var roofs: PackedVector2Array = PackedVector2Array([Vector2(inner.position.x, base_y)])
	var x: float = inner.position.x
	var k2: int = 0
	while x < inner.end.x:
		var bh: float = 26.0 + 30.0 * h01_local(k2 * 5)
		var bw: float = 22.0 + 18.0 * h01_local(k2 * 5 + 1)
		roofs.append(Vector2(x, base_y - bh))
		roofs.append(Vector2(x + bw * 0.5, base_y - bh - 12.0))
		roofs.append(Vector2(minf(x + bw, inner.end.x), base_y - bh))
		x += bw
		k2 += 1
	roofs.append(Vector2(inner.end.x, base_y))
	d.draw_colored_polygon(roofs, Color(0.03, 0.04, 0.08))
	var spire: Vector2 = Vector2(inner.position.x + inner.size.x * 0.72, base_y - 60.0)
	d.draw_colored_polygon(PackedVector2Array([spire + Vector2(-9, 30), spire + Vector2(9, 30), spire + Vector2(0, -34)]), Color(0.03, 0.04, 0.08))
	for k in 6:
		var lp: Vector2 = Vector2(inner.position.x + h01_local(k * 11 + 3) * inner.size.x, base_y - 8.0 - 18.0 * h01_local(k * 11 + 4))
		d.draw_rect(Rect2(lp, Vector2(3.0, 4.0)), Color(1.0, 0.82, 0.45, 0.85))

# THE WINDOW: a moulded casing with a keystone, a deep reveal, glazing bars (a fanlight in the arch, small
# panes below), faint reflections on the glass, a sill; THE CURTAINS: velvet in lit and shaded folds, a
# pelmet over a brass rod with finials, held back by gold cords with tassels
func _window_dressing(d: Control, g: Dictionary) -> void:
	var wr: Rect2 = g["wr"]
	var ww: float = g["ww"]
	var c_arch: Vector2 = Vector2(wr.get_center().x, wr.position.y + ww * 0.5)
	# the reveal: the opening's depth, in shade at the top and the left
	d.draw_polyline(_arch_pts(wr, 6.0), Color(0.08, 0.05, 0.03, 0.85), 8.0, true)
	# glazing bars
	var bar: Color = Color(0.20, 0.12, 0.06)
	var bar_l: Color = Color(0.42, 0.28, 0.14)
	var inner: Rect2 = wr.grow(-10.0)
	var spring: float = c_arch.y
	for k in 5:
		var a: float = PI + PI * float(k + 1) / 6.0
		d.draw_line(c_arch, c_arch + Vector2(cos(a), sin(a)) * (ww * 0.5 - 10.0), bar, 3.0, true)
	d.draw_arc(c_arch, ww * 0.20, PI, TAU, 20, bar, 3.0, true)
	d.draw_line(Vector2(inner.position.x, spring), Vector2(inner.end.x, spring), bar, 5.0)
	d.draw_line(Vector2(inner.position.x, spring - 2.0), Vector2(inner.end.x, spring - 2.0), bar_l, 1.0)
	for k in 2:
		var xx: float = inner.position.x + inner.size.x * float(k + 1) / 3.0
		d.draw_line(Vector2(xx, spring), Vector2(xx, inner.end.y), bar, 3.0)
		d.draw_line(Vector2(xx - 1.5, spring), Vector2(xx - 1.5, inner.end.y), bar_l, 1.0)
	for k in 4:
		var yy: float = spring + (inner.end.y - spring) * float(k + 1) / 5.0
		d.draw_line(Vector2(inner.position.x, yy), Vector2(inner.end.x, yy), bar, 3.0)
		d.draw_line(Vector2(inner.position.x, yy - 1.5), Vector2(inner.end.x, yy - 1.5), bar_l, 1.0)
	# reflections: two soft diagonal sheens on the glass
	for k in 2:
		var x0: float = inner.position.x + inner.size.x * (0.15 + 0.45 * float(k))
		d.draw_colored_polygon(PackedVector2Array([Vector2(x0, spring + 20.0), Vector2(x0 + 18.0, spring + 20.0),
			Vector2(x0 - 30.0, inner.end.y - 30.0), Vector2(x0 - 48.0, inner.end.y - 30.0)]), Color(1, 1, 1, 0.035))
	# the casing: a moulding round the arch and down the sides, lit at the top left
	var casing: PackedVector2Array = _arch_pts(wr.grow(10.0), 0.0)
	d.draw_polyline(casing, WOOD_D, 16.0, true)
	d.draw_polyline(_arch_pts(wr.grow(10.0), 4.0), WOOD, 8.0, true)
	d.draw_polyline(_arch_pts(wr.grow(10.0), 2.0), WOOD_L, 2.0, true)
	var key: Vector2 = Vector2(c_arch.x, wr.position.y - 10.0)
	d.draw_colored_polygon(PackedVector2Array([key + Vector2(-12, -10), key + Vector2(12, -10), key + Vector2(8, 16), key + Vector2(-8, 16)]), WOOD)
	d.draw_line(key + Vector2(-12, -10), key + Vector2(12, -10), WOOD_L, 2.0)
	# the sill
	var sill: Rect2 = Rect2(wr.position.x - 22.0, wr.end.y, wr.size.x + 44.0, 12.0)
	d.draw_rect(Rect2(sill.position + Vector2(0, 12), Vector2(sill.size.x, 8.0)), Color(0, 0, 0, 0.30))
	d.draw_rect(sill, WOOD)
	d.draw_rect(Rect2(sill.position, Vector2(sill.size.x, 3.0)), WOOD_L)
	# THE CURTAINS, one each side, gathered at a tie-back
	var rod_y: float = wr.position.y - 26.0
	for side in [-1.0, 1.0]:
		var edge: float = wr.get_center().x + side * (ww * 0.5 - 8.0)
		var outer: float = wr.get_center().x + side * (ww * 0.5 + 42.0)
		var tie_y: float = wr.position.y + wr.size.y * 0.58
		var foot: float = wr.end.y + 30.0
		var folds: int = 5
		for f in folds:
			var u0: float = float(f) / float(folds)
			var u1: float = float(f + 1) / float(folds)
			# top: spread across the rod; at the tie-back: pinched to the outside; below: spreading again
			var top0: float = lerpf(edge, outer, u0)
			var top1: float = lerpf(edge, outer, u1)
			var tie0: float = lerpf(outer - side * 30.0, outer, u0)
			var tie1: float = lerpf(outer - side * 30.0, outer, u1)
			var ft0: float = lerpf(edge + side * 10.0, outer + side * 6.0, u0)
			var ft1: float = lerpf(edge + side * 10.0, outer + side * 6.0, u1)
			var lit: Color = VELVET_L if f % 2 == 0 else VELVET
			var shade: Color = VELVET_D if f % 2 == 0 else VELVET_D.lerp(VELVET, 0.4)
			d.draw_polygon(PackedVector2Array([Vector2(top0, rod_y), Vector2(top1, rod_y), Vector2(tie1, tie_y), Vector2(tie0, tie_y)]),
				PackedColorArray([lit, shade, shade, lit]))
			d.draw_polygon(PackedVector2Array([Vector2(tie0, tie_y), Vector2(tie1, tie_y), Vector2(ft1, foot), Vector2(ft0, foot)]),
				PackedColorArray([lit, shade, shade.darkened(0.2), lit.darkened(0.2)]))
		# the tie-back: a gold cord round the gathered folds, and a tassel
		var tie_c: Vector2 = Vector2(outer - side * 15.0, tie_y)
		d.draw_line(tie_c + Vector2(-20, -2), tie_c + Vector2(20, 2), GILT, 4.0, true)
		d.draw_line(tie_c + Vector2(-20, -3), tie_c + Vector2(20, 1), GILT_L, 1.0, true)
		var tas: Vector2 = tie_c + Vector2(side * 4.0, 6.0)
		d.draw_circle(tas, 5.0, GILT)
		d.draw_colored_polygon(PackedVector2Array([tas + Vector2(-5, 2), tas + Vector2(5, 2), tas + Vector2(7, 24), tas + Vector2(-7, 24)]), GILT_D)
		for f2 in 4:
			d.draw_line(tas + Vector2(-5.0 + 3.3 * float(f2), 4.0), tas + Vector2(-6.0 + 4.0 * float(f2), 24.0), GILT_L, 1.0)
	# the rod and its finials, then the pelmet over the curtains' heads
	var rl: float = wr.position.x - 62.0
	var rr: float = wr.end.x + 62.0
	d.draw_line(Vector2(rl, rod_y), Vector2(rr, rod_y), GILT_D, 6.0)
	d.draw_line(Vector2(rl, rod_y - 1.5), Vector2(rr, rod_y - 1.5), GILT_L, 1.5)
	for fx in [rl, rr]:
		d.draw_circle(Vector2(fx, rod_y), 8.0, GILT_D)
		d.draw_circle(Vector2(fx - 2.0, rod_y - 2.0), 5.0, GILT)
	var pel: PackedVector2Array = PackedVector2Array([Vector2(rl + 8.0, rod_y - 14.0), Vector2(rr - 8.0, rod_y - 14.0)])
	var n_sc: int = 6
	for k in range(n_sc * 4, -1, -1):
		var u: float = float(k) / float(n_sc * 4)
		var xx: float = lerpf(rl + 8.0, rr - 8.0, u)
		pel.append(Vector2(xx, rod_y + 16.0 + 10.0 * absf(sin(u * PI * float(n_sc)))))
	d.draw_colored_polygon(pel, VELVET)
	d.draw_polyline(pel.slice(2), VELVET_D, 2.0, true)
	d.draw_line(Vector2(rl + 8.0, rod_y - 14.0), Vector2(rr - 8.0, rod_y - 14.0), GILT, 3.0)

# THE PICTURES: two engravings in gilt frames, hung from the picture rail by a cord on two screw eyes, each a
# touch askew, casting a shadow on the paper
func _pictures(d: Control, g: Dictionary) -> void:
	var full: Vector2 = g["full"]
	var rail: float = g["rail"]
	var top: float = g["top"]
	var h: float = g["h"]
	for side in [-1.0, 1.0]:
		var fw: float = full.x * 0.15
		var fh: float = fw * 1.28
		var ctr: Vector2 = Vector2(full.x * 0.5 + side * full.x * 0.39, top + h * 0.14 + fh * 0.5)
		var tilt: float = deg_to_rad(1.6 * side)
		var hook: Vector2 = Vector2(ctr.x, rail + 6.0)
		var eye_l: Vector2 = ctr + Vector2(-fw * 0.32, -fh * 0.5 + 6.0).rotated(tilt)
		var eye_r: Vector2 = ctr + Vector2(fw * 0.32, -fh * 0.5 + 6.0).rotated(tilt)
		# the cord, and the hook on the rail
		d.draw_line(hook, eye_l, Color(0.55, 0.45, 0.30), 1.5, true)
		d.draw_line(hook, eye_r, Color(0.55, 0.45, 0.30), 1.5, true)
		d.draw_colored_polygon(PackedVector2Array([hook + Vector2(-5, -6), hook + Vector2(5, -6), hook + Vector2(2, 3), hook + Vector2(-2, 3)]), GILT)
		# the shadow, the frame (moulded: dark outside, a gilt slope lit at the top left, a dark lip), the mat
		d.draw_set_transform(ctr + Vector2(5.0, 8.0), tilt, Vector2.ONE)
		d.draw_rect(Rect2(-fw * 0.5, -fh * 0.5, fw, fh), Color(0, 0, 0, 0.30))
		d.draw_set_transform(ctr, tilt, Vector2.ONE)
		var fr: Rect2 = Rect2(-fw * 0.5, -fh * 0.5, fw, fh)
		d.draw_rect(fr, GILT_D)
		var o: float = 10.0
		d.draw_polygon(PackedVector2Array([fr.position, Vector2(fr.end.x, fr.position.y), Vector2(fr.end.x - o, fr.position.y + o), fr.position + Vector2(o, o)]),
			PackedColorArray([GILT_L, GILT, GILT, GILT_L]))
		d.draw_polygon(PackedVector2Array([fr.position, fr.position + Vector2(o, o), Vector2(fr.position.x + o, fr.end.y - o), Vector2(fr.position.x, fr.end.y)]),
			PackedColorArray([GILT_L, GILT_L, GILT, GILT]))
		d.draw_rect(fr.grow(-o), Color(0.20, 0.13, 0.05))
		var mat: Rect2 = fr.grow(-o - 2.0)
		d.draw_rect(mat, Color(0.90, 0.85, 0.72))
		var pic: Rect2 = mat.grow(-7.0)
		d.draw_rect(pic, Color(0.84, 0.78, 0.64))
		d.draw_rect(pic, Color(0.45, 0.36, 0.22, 0.7), false, 1.0)
		_engraving(d, pic, side < 0.0)
		d.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# an engraving inside a picture: hatched sky, a horizon, and the subject in ink -- a steelyard with a sack
# on its hook, or a pair of scales on a stand
func _engraving(d: Control, r: Rect2, steelyard: bool) -> void:
	var ink: Color = Color(0.22, 0.15, 0.08, 0.85)
	var faint: Color = Color(0.30, 0.22, 0.12, 0.28)
	var y: float = r.position.y + 3.0
	while y < r.position.y + r.size.y * 0.55:
		d.draw_line(Vector2(r.position.x + 2.0, y), Vector2(r.end.x - 2.0, y), faint, 1.0)
		y += 3.0
	var hz: float = r.position.y + r.size.y * 0.78
	d.draw_line(Vector2(r.position.x, hz), Vector2(r.end.x, hz), ink, 1.0)
	var x: float = r.position.x + 2.0
	while x < r.end.x - 2.0:
		d.draw_line(Vector2(x, hz + 2.0), Vector2(x - 4.0, r.end.y - 2.0), faint, 1.0)
		x += 4.0
	var c: Vector2 = r.get_center()
	var s: float = r.size.x
	if steelyard:
		d.draw_line(c + Vector2(0.0, -s * 0.50), c + Vector2(0.0, -s * 0.30), ink, 1.5)
		d.draw_line(c + Vector2(-s * 0.36, -s * 0.24), c + Vector2(s * 0.38, -s * 0.34), ink, 2.0)
		d.draw_line(c + Vector2(-s * 0.30, -s * 0.25), c + Vector2(-s * 0.30, s * 0.02), ink, 1.0)
		d.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.40, s * 0.02), c + Vector2(-s * 0.20, s * 0.02),
			c + Vector2(-s * 0.16, s * 0.30), c + Vector2(-s * 0.44, s * 0.30)]), ink)
		d.draw_circle(c + Vector2(s * 0.24, -s * 0.24), s * 0.06, ink)
		d.draw_line(c + Vector2(s * 0.24, -s * 0.32), c + Vector2(s * 0.24, -s * 0.30), ink, 1.0)
	else:
		d.draw_line(c + Vector2(0.0, -s * 0.48), c + Vector2(0.0, s * 0.30), ink, 2.0)
		d.draw_line(c + Vector2(-s * 0.18, s * 0.30), c + Vector2(s * 0.18, s * 0.30), ink, 2.0)
		d.draw_line(c + Vector2(-s * 0.38, -s * 0.38), c + Vector2(s * 0.38, -s * 0.38), ink, 2.0)
		for sx in [-1.0, 1.0]:
			d.draw_line(c + Vector2(sx * s * 0.38, -s * 0.38), c + Vector2(sx * s * 0.28, -s * 0.04), ink, 1.0)
			d.draw_line(c + Vector2(sx * s * 0.38, -s * 0.38), c + Vector2(sx * s * 0.48, -s * 0.04), ink, 1.0)
			d.draw_arc(c + Vector2(sx * s * 0.38, -s * 0.06), s * 0.12, 0.0, PI, 10, ink, 1.5)

static func h01_local(i: int) -> float:
	var v: int = (i * 0x9E3779B1) & 0xffffffff
	v ^= v >> 15
	v = (v * 0x2C1B3C6D) & 0xffffffff
	v ^= v >> 12
	return float(v & 0xffff) / 65536.0

func _draw_title(full: Vector2) -> void:
	var t: String = "Tip the Scales"
	var title_font: Font = _display_font()        # its name in the app's display font, as every poster's
	var tw: float = title_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_fs).x
	var p: Vector2 = Vector2((full.x - tw) * 0.5, _title_y)
	# cast brass: a shadow, a dark edge, the face, and the lamp's sheen on its upper half
	_cv.draw_string(title_font, p + Vector2(0, 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_fs, Color(0, 0, 0, 0.55))
	_cv.draw_string_outline(title_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_fs, 8, Color(0.22, 0.13, 0.05))
	_cv.draw_string(title_font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_fs, ART.BRASS)
	_cv.draw_string(title_font, p + Vector2(0, -2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, _title_fs, Color(BRASS_LIGHT, 0.35))
	# the pitch, as a line of copperplate under it, between two short rules
	var sub: String = "Weigh the crates with nothing but balance scales"
	var font: Font = MainGlobals.get_text_font()
	var sw: float = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, _pitch_fs).x
	var sy: float = _title_y + float(_pitch_fs) * 1.9
	_cv.draw_string(font, Vector2((full.x - sw) * 0.5, sy + 2.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, _pitch_fs, Color(0, 0, 0, 0.5))
	_cv.draw_string(font, Vector2((full.x - sw) * 0.5, sy), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, _pitch_fs, Color(0.97, 0.92, 0.82))
	var ry: float = sy - float(_pitch_fs) * 0.35
	var rl: float = minf(60.0, (full.x - sw) * 0.5 - 24.0)
	if rl > 10.0:
		_cv.draw_line(Vector2((full.x - sw) * 0.5 - 14.0 - rl, ry), Vector2((full.x - sw) * 0.5 - 14.0, ry), Color(ART.BRASS, 0.7), 2.0)
		_cv.draw_line(Vector2((full.x + sw) * 0.5 + 14.0, ry), Vector2((full.x + sw) * 0.5 + 14.0 + rl, ry), Color(ART.BRASS, 0.7), 2.0)

# THE BALANCE: a column on a plinth, a beam on a knife-edge, two pans on chains. It rocks the way a scale
# does when a crate has just been set down -- a slow swing that dies away, then another crate, again.
func _beam_angle() -> float:
	# NO JUMP between cycles (the user saw "some sudden jump"): each cycle starts exactly where the last
	# came to rest (-side * REST) and swings, damped, to its own rest (+side * REST)
	var period: float = 7.0
	var rest: float = 0.07
	var u: float = fmod(_t, period)
	var side: float = 1.0 if int(_t / period) % 2 == 0 else -1.0
	return side * rest - side * 2.0 * rest * exp(-u * 0.75) * cos(u * 2.6)

# `still`: the shadow, the plinth, the column and the dial's face (drawn once, under the live part); otherwise the
# needle, the pans on their chains, the beam and its cap (every frame: it rocks)
func _draw_balance(full: Vector2, still: bool) -> void:
	var mobile: bool = MainGlobals.is_mobile()
	var cx: float = full.x * 0.5
	var foot: float = _counter_y + (34.0 if mobile else 22.0)
	var top: float = _board.position.y + _board.size.y * 0.25
	var hs: float = foot - top
	var L: float = minf(full.x * 0.30, 210.0)
	var pivot: Vector2 = Vector2(cx, top + hs * 0.10)
	var a: float = _beam_angle()
	var dr: float = L * 0.30
	if not still:
		_balance_live(pivot, a, dr)
		return
	# shadow on the counter
	for k in 4:
		_cv.draw_set_transform(Vector2(cx, foot + 4.0), 0.0, Vector2(1.0, 0.18))
		_cv.draw_circle(Vector2.ZERO, 150.0 - float(k) * 22.0, Color(0, 0, 0, 0.10 + 0.04 * float(k)))
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the plinth and the column
	# HEAVIER THAN IT WAS (the user: hard to see on a phone over the paintings and the paneling): a broader plinth,
	# a thicker column and beam, bigger chain links -- and a dark edge round each, so it stands off the wall
	var pw: float = 230.0 if mobile else 170.0
	var ph: float = 36.0 if mobile else 26.0
	_cv.draw_colored_polygon(PackedVector2Array([Vector2(cx - pw * 0.5 - 3.0, foot + 2.0), Vector2(cx + pw * 0.5 + 3.0, foot + 2.0),
		Vector2(cx + pw * 0.36 + 3.0, foot - ph - 3.0), Vector2(cx - pw * 0.36 - 3.0, foot - ph - 3.0)]), EDGE)
	_cv.draw_colored_polygon(PackedVector2Array([Vector2(cx - pw * 0.5, foot), Vector2(cx + pw * 0.5, foot),
		Vector2(cx + pw * 0.36, foot - ph), Vector2(cx - pw * 0.36, foot - ph)]), Color(0.30, 0.17, 0.08))
	_cv.draw_line(Vector2(cx - pw * 0.36, foot - ph), Vector2(cx + pw * 0.36, foot - ph), Color(0.55, 0.36, 0.18), 2.0)
	var collar: float = 16.0 if mobile else 12.0
	_cv.draw_rect(Rect2(cx - pw * 0.30 - 2.0, foot - ph - collar - 2.0, pw * 0.60 + 4.0, collar + 2.0), EDGE)
	_cv.draw_rect(Rect2(cx - pw * 0.30, foot - ph - collar, pw * 0.60, collar), ART.BRASS_DARK)
	_cv.draw_rect(Rect2(cx - pw * 0.30, foot - ph - collar, pw * 0.60, 4.0), ART.BRASS)
	var cw: float = 32.0 if mobile else 24.0
	var col: Rect2 = Rect2(cx - cw * 0.5, pivot.y, cw, foot - ph - collar - pivot.y)
	_cv.draw_rect(col.grow_individual(2.5, 0.0, 2.5, 0.0), EDGE)
	_cv.draw_rect(col, ART.BRASS_DARK)
	_cv.draw_rect(Rect2(col.position.x + cw * 0.18, col.position.y, cw * 0.28, col.size.y), ART.BRASS)
	_cv.draw_rect(Rect2(col.position.x + cw * 0.24, col.position.y, cw * 0.10, col.size.y), Color(BRASS_LIGHT, 0.7))
	# the dial over the pivot (its needle, which stands up from the beam, is live)
	_cv.draw_arc(pivot, dr, PI * 1.25, PI * 1.75, 32, ART.BRASS_DARK, 8.0, true)
	_cv.draw_arc(pivot, dr, PI * 1.25, PI * 1.75, 32, ART.BRASS, 3.0, true)
	for k in 9:
		var ang: float = PI * 1.25 + PI * 0.5 * float(k) / 8.0
		var d: Vector2 = Vector2(cos(ang), sin(ang))
		_cv.draw_line(pivot + d * (dr - 9.0), pivot + d * (dr - (16.0 if k % 4 == 0 else 12.0)), Color(0.22, 0.13, 0.05), 2.0)

func _balance_live(pivot: Vector2, a: float, dr: float) -> void:
	var nd: Vector2 = Vector2(sin(a), -cos(a))
	_cv.draw_line(pivot, pivot + nd * (dr - 6.0), Color(0.22, 0.13, 0.05), 4.0, true)
	_cv.draw_line(pivot, pivot + nd * (dr - 6.0), BRASS_LIGHT, 1.5, true)
	# (the pans hang from the beam's ends, upright whatever its angle: _pan_hold / _pan_draw, carried by _place_pans)
	# (the beam over the chains' hooks: _beam_hold, turned to `a` by _place_pans; its cap: _cap)

# THE BEAM, LEVEL (turned as a picture): a tapered bar with its dark edge, a brass face with the light along its top,
# the bosses at its ends
func _draw_beam_level() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bg: Array = _balance_geom(full)
	var pivot: Vector2 = bg[0]
	var L: float = bg[1]
	var bh: float = 22.0 if MainGlobals.is_mobile() else 16.0
	_cv.draw_set_transform(pivot, 0.0, Vector2.ONE)
	var beam: PackedVector2Array = PackedVector2Array([Vector2(-L - 6.0, -bh * 0.35), Vector2(-30.0, -bh * 0.5),
		Vector2(30.0, -bh * 0.5), Vector2(L + 6.0, -bh * 0.35), Vector2(L + 6.0, bh * 0.35), Vector2(30.0, bh * 0.5),
		Vector2(-30.0, bh * 0.5), Vector2(-L - 6.0, bh * 0.35)])
	var ring: PackedVector2Array = beam.duplicate()
	ring.append(beam[0])
	_cv.draw_polyline(ring, EDGE, 5.0, true)
	_cv.draw_colored_polygon(beam, ART.BRASS_DARK)
	_cv.draw_line(Vector2(-L - 4.0, -bh * 0.18), Vector2(L + 4.0, -bh * 0.18), ART.BRASS, bh * 0.30, true)
	_cv.draw_line(Vector2(-L, -bh * 0.26), Vector2(L, -bh * 0.26), Color(BRASS_LIGHT, 0.6), 1.5, true)
	for e in [-L, L]:
		_cv.draw_circle(Vector2(e, 0.0), bh * 0.55, ART.BRASS_DARK, true, -1.0, true)
		_cv.draw_circle(Vector2(e, 0.0), bh * 0.32, ART.BRASS, true, -1.0, true)
	_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# THE KNIFE-EDGE'S CAP over the pivot (round: it does not turn with the beam)
func _draw_cap() -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var pivot: Vector2 = _balance_geom(full)[0]
	var bh: float = 22.0 if MainGlobals.is_mobile() else 16.0
	_cv.draw_circle(pivot, bh * 0.95, ART.BRASS_DARK, true, -1.0, true)
	_cv.draw_circle(pivot, bh * 0.65, ART.BRASS, true, -1.0, true)
	_cv.draw_circle(pivot + Vector2(-bh * 0.2, -bh * 0.2), bh * 0.25, Color(BRASS_LIGHT, 0.8), true, -1.0, true)

func _draw_pan(hook: Vector2, hang: float, k: int, mobile: bool) -> void:
	var pw: float = 186.0 if mobile else 140.0
	var depth: float = 26.0 if mobile else 19.0
	var rim: Vector2 = hook + Vector2(0.0, hang)
	# the crates on it, first: the pan's front lip is drawn over their feet
	var cs: Vector2 = Vector2(_cell.x * 0.80, _cell.y * 0.80)
	if k == 0:
		_crate_on_pan(Rect2(rim + Vector2(-cs.x - 2.0, -cs.y + 4.0), cs), 0, 2, 0b10110, 0)
		_crate_on_pan(Rect2(rim + Vector2(2.0, -cs.y + 4.0), cs), 2, 0, 0, 4)
	else:
		_crate_on_pan(Rect2(rim + Vector2(-cs.x * 0.80, -cs.y + 4.0), cs), 1, 3, 0b01011, 0)
		# and a brass weight beside it
		var ws: float = cs.y * 0.70
		_cv.draw_set_transform(rim + Vector2(cs.x * 0.42, -ws * 0.5 + 4.0), 0.0, Vector2.ONE)
		_cv.draw_colored_polygon(PackedVector2Array([Vector2(-ws * 0.42, ws * 0.5), Vector2(ws * 0.42, ws * 0.5),
			Vector2(ws * 0.30, -ws * 0.30), Vector2(-ws * 0.30, -ws * 0.30)]), ART.BRASS_DARK)
		_cv.draw_colored_polygon(PackedVector2Array([Vector2(-ws * 0.36, ws * 0.44), Vector2(ws * 0.10, ws * 0.44),
			Vector2(ws * 0.02, -ws * 0.26), Vector2(-ws * 0.26, -ws * 0.26)]), ART.BRASS)
		_cv.draw_arc(Vector2(0.0, -ws * 0.38), ws * 0.14, PI, TAU, 12, ART.BRASS_DARK, 3.0)
		var fs: int = int(ws * 0.46)
		var t: String = "2"
		var tw: float = _face.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_cv.draw_string(_face, Vector2(-tw * 0.5, ws * 0.30), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.22, 0.13, 0.05))
		_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# three chains from the hook to the rim
	for x in [-pw * 0.5, 0.0, pw * 0.5]:
		var to: Vector2 = rim + Vector2(x, -2.0 if x == 0.0 else 0.0)
		if x == 0.0:
			to = rim + Vector2(0.0, -cs.y - 2.0)   # the middle one stops on the load
		var link: float = 4.2 if mobile else 3.2
		_cv.draw_line(hook, to, EDGE, link * 2.0 + 3.0, true)
		var n: int = int(hook.distance_to(to) / (link * 3.2))
		var along: float = (to - hook).angle()
		for j in n:
			var p: Vector2 = hook.lerp(to, (float(j) + 0.5) / float(maxi(1, n)))
			# links alternate: one seen flat (an oval ring), the next edge-on (a bar)
			if j % 2 == 0:
				_cv.draw_set_transform(p, along, Vector2(1.0, 0.62))
				_cv.draw_arc(Vector2.ZERO, link, 0.0, TAU, 14, ART.BRASS, link * 0.55, true)
				_cv.draw_arc(Vector2.ZERO, link, PI * 1.1, PI * 1.6, 6, BRASS_LIGHT, link * 0.3, true)
				_cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var dv: Vector2 = Vector2.from_angle(along) * link * 1.1
				_cv.draw_line(p - dv, p + dv, ART.BRASS_DARK, link * 0.75, true)
	# the bowl: a shallow dish, its far rim then its front
	var pts: PackedVector2Array = PackedVector2Array()
	for j in 17:
		var u: float = PI * float(j) / 16.0
		pts.append(rim + Vector2(-cos(u) * pw * 0.5, sin(u) * depth))
	var pring: PackedVector2Array = pts.duplicate()
	pring.append(pts[0])
	_cv.draw_polyline(pring, EDGE, 4.0, true)
	_cv.draw_colored_polygon(pts, ART.BRASS_DARK)
	var lit: PackedVector2Array = PackedVector2Array()
	for j in 17:
		var u: float = PI * float(j) / 16.0
		lit.append(rim + Vector2(-cos(u) * pw * 0.44, sin(u) * depth * 0.55))
	_cv.draw_polyline(lit, Color(ART.BRASS, 0.9), 3.0, true)
	_cv.draw_line(rim + Vector2(-pw * 0.5, 0.0), rim + Vector2(pw * 0.5, 0.0), BRASS_LIGHT, 3.0)

func _crate_on_pan(r: Rect2, row: int, col: int, mask: int, placed: int) -> void:
	if _crate_tex.is_empty():
		return
	ART.draw_crate(_cv, r, _tex(row, col), row, col, COLS, mask if placed == 0 else PUZZLE.bit(placed), 0, placed, 0, 1.0, _face)

# the app's DISPLAY font -- the one the player picked (MainGlobals.GAME_FONTS) -- for the poster's NAME only, as every
# poster's (this game had a serif of its own, Noto Serif Bold: the user, 2026-11-20 -- never a font of a game's own;
# whatever must read clearly is in the text font)
func _display_font() -> Font:
	return ThemeDB.get_default_theme().default_font
