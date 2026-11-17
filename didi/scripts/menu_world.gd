extends "res://scripts/menu_poster.gd"

# PINPOINT'S OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): a STAKEOUT, seen from a
# high window at night -- through glass streaming with rain (the drops running down it, the window's dark
# frame round the view) a wet street corner below: a lamp pouring a cone of warm light on the cobbles and
# their reflections, a doorway, the kerb; the game's own people under umbrellas (agent.gd) crossing slowly
# along the pavement; and every few seconds lightning, and in its flash the LOOKOUT stands out in the
# doorway -- the yellow raincoat under the clear umbrella -- gone into the dark again a moment later.
# Not the game's square (a picture, not the board). Made up, never the board.

const AGENT: PackedScene = preload("res://didi/scenes/agent.tscn")
const WALKERS: int = 4
const FLASH_EVERY: float = 6.0

var _walkers: Array = []
var _lookout: Node2D = null
var _layer: Node2D = null
var _clip: Control = null
var _drops: Array = []

func _setup() -> void:
	# the people are clipped to the glass: walking in and out, they passed over the window frame
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_layer = Node2D.new()
	_clip.add_child(_layer)
	for k in WALKERS:
		var a: Node2D = _agent(0, k % 7, [Color(0.85, 0.25, 0.25), Color(0.25, 0.45, 0.85), Color(0.95, 0.75, 0.25), Color(0.30, 0.65, 0.40)][k])
		_walkers.append(a)
	_lookout = _agent(1, 0, Color(1, 1, 1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	for _i in 46:
		_drops.append([rng.randf(), rng.randf(), rng.randf_range(2.5, 6.0), rng.randf_range(0.03, 0.12)])

func _agent(kind: int, print_i: int, col: Color) -> Node2D:
	var a: Node2D = AGENT.instantiate()
	_layer.add_child(a)
	a.set("time_to_hide_ms", 1.0e15)
	a.call("set_kind", kind)
	a.call("set_texture", print_i)
	a.call("set_colors", [col, col.lightened(0.35)])
	return a

func _flash() -> float:
	var u: float = fmod(t + 4.6, FLASH_EVERY)      # the first flash 1.4 s in (at 4 s a player could miss it)
	if u > 0.8:
		return 0.0
	return maxf(exp(-u * 14.0), 0.6 * exp(-absf(u - 0.18) * 16.0))

func _geom() -> Dictionary:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	var view: Rect2 = Rect2(34.0, (230.0 if mobile else 150.0), full.x - 68.0, bottom - (230.0 if mobile else 150.0) - 30.0)
	return {"full": full, "bottom": bottom, "view": view}

func _tick(_delta: float) -> void:
	var g: Dictionary = _geom()
	var view: Rect2 = g["view"]
	var fl: float = _flash()
	_clip.position = view.position
	_clip.size = view.size
	_layer.position = -view.position
	var walk_y: float = view.position.y + view.size.y * 0.72
	var sc: float = view.size.x / 680.0 * 1.15
	# WALKING, not carried (the user: "as if on conveyor belts"): each keeps its own easy pace, a little
	# faster and slower by turns; every step lifts the umbrella a touch and sways it side to side, and the
	# canopy turns a little in the hand
	for k in _walkers.size():
		var a: Node2D = _walkers[k]
		var dirx: float = 1.0 if k % 2 == 0 else -1.0
		var span: float = view.size.x + 160.0
		var pace: float = 24.0 + 8.0 * h01(k + 5)
		# distance walked: the pace with a slow surge and ease, integrated (so no jumps)
		var walked: float = pace * t + pace * 0.9 * sin(t * 0.35 + float(k)) / 0.35 * 0.15
		var x: float = fmod(float(k) / float(WALKERS) * span + walked, span)     # spaced evenly: two walked as one clump
		# a planted foot travels 16 units back (2 x 8) over half a cycle: the body moves that far per half
		# cycle, so the feet do not slide
		var stride: float = 16.0 * sc
		var ph: float = walked / stride * PI
		var bob: float = absf(sin(ph)) * 3.0 * sc
		a.position = Vector2((view.position.x - 80.0 + x) if dirx > 0.0 else (view.end.x + 80.0 - x),
			walk_y + (12.0 if k % 2 == 0 else 34.0) - bob)
		a.rotation = sin(ph) * 0.045
		a.set("step_phase", fmod(ph, TAU))
		a.set("step_dir", dirx)
		a.scale = Vector2(sc, sc)
		a.set("spin", h01(k + 9) * TAU + sin(t * 0.4 + float(k)) * 0.35)
		a.call("set_light", Color(0.62, 0.60, 0.66).lerp(Color(1.6, 1.6, 1.8), fl))
		a.queue_redraw()
	# the lookout in the doorway: barely there in the dark, plain in the flash
	_lookout.position = Vector2(view.position.x + view.size.x * 0.20, view.position.y + view.size.y * 0.50)
	_lookout.scale = Vector2(sc * 0.9, sc * 0.9)
	# seen ONLY in the flash (at a fifth between flashes it read as a phantom umbrella, the user)
	_lookout.modulate.a = clampf(fl * 1.6, 0.0, 1.0)
	_lookout.call("set_light", Color(0.5, 0.5, 0.55).lerp(Color(1.7, 1.7, 1.9), fl))
	_lookout.queue_redraw()

# THE HOTEL'S FRONT (it was one flat orange slab, the user): a lobby seen through its glass -- the warm back wall
# under a chandelier's glow, the reception desk with its lamp, a potted palm, a doorway to the stairs -- behind a
# dark frame of mullions with a pair of glass doors and brass handles in the middle, light streaks on the wet
# glass, a striped green awning with a scalloped edge above, and the lobby's light spilling out onto the pavement
func _hotel_front(r: Rect2, lit: float, pave_y: float) -> void:
	var frame_c: Color = Color(0.10, 0.09, 0.08).lerp(Color(0.6, 0.6, 0.62), lit)
	var glass: Rect2 = Rect2(r.position.x, r.position.y, r.size.x, pave_y - r.position.y)
	# the lobby inside: the back wall, warm, brightest under the chandelier
	vgrad(glass, Color(0.62, 0.40, 0.20), Color(0.42, 0.25, 0.12))
	var ch: Vector2 = Vector2(glass.get_center().x, glass.position.y + glass.size.y * 0.16)
	glow_at(ch, glass.size.x * 0.42, Color(1.0, 0.82, 0.50, 0.30), 8)
	# wainscot and the floor, a checked tile
	var floor_y: float = glass.end.y - glass.size.y * 0.16
	cv.draw_rect(Rect2(glass.position.x, floor_y - glass.size.y * 0.20, glass.size.x, glass.size.y * 0.20), Color(0.30, 0.17, 0.09))
	cv.draw_rect(Rect2(glass.position.x, floor_y - glass.size.y * 0.20, glass.size.x, 2.0), Color(0.75, 0.55, 0.30, 0.6))
	cv.draw_rect(Rect2(glass.position.x, floor_y, glass.size.x, glass.end.y - floor_y), Color(0.34, 0.24, 0.16))
	var tile: float = glass.size.x / 14.0
	for i in 14:
		for j in 2:
			if (i + j) % 2 == 0:
				cv.draw_rect(Rect2(glass.position.x + tile * float(i), floor_y + (glass.end.y - floor_y) * 0.5 * float(j), tile, (glass.end.y - floor_y) * 0.5), Color(0.50, 0.40, 0.30))
	# the chandelier: a stem, a ring of small lights
	cv.draw_line(Vector2(ch.x, glass.position.y), ch, Color(0.25, 0.18, 0.10), 1.5)
	for k in 7:
		var cx: float = ch.x + (float(k) - 3.0) * glass.size.x * 0.035
		var cy: float = ch.y + absf(float(k) - 3.0) * -1.5
		cv.draw_circle(Vector2(cx, cy), 2.6, Color(1.0, 0.92, 0.70))
	cv.draw_line(ch + Vector2(-glass.size.x * 0.11, -1), ch + Vector2(glass.size.x * 0.11, -1), Color(0.55, 0.40, 0.18), 2.0)
	# a doorway at the back right, to the stairs
	var dw: Rect2 = Rect2(glass.position.x + glass.size.x * 0.70, floor_y - glass.size.y * 0.46, glass.size.x * 0.13, glass.size.y * 0.46)
	cv.draw_rect(dw.grow(2.0), Color(0.26, 0.15, 0.08))
	cv.draw_rect(dw, Color(0.20, 0.11, 0.06))
	# the reception desk at the left with its lamp, and a clerk's head behind it
	var desk: Rect2 = Rect2(glass.position.x + glass.size.x * 0.08, floor_y - glass.size.y * 0.17, glass.size.x * 0.30, glass.size.y * 0.17)
	cv.draw_circle(Vector2(desk.get_center().x + 6.0, desk.position.y - glass.size.y * 0.07), glass.size.y * 0.055, Color(0.18, 0.11, 0.07))
	cv.draw_rect(Rect2(desk.get_center().x - glass.size.y * 0.06 + 6.0, desk.position.y - glass.size.y * 0.04, glass.size.y * 0.12, glass.size.y * 0.04), Color(0.18, 0.11, 0.07))
	cv.draw_rect(desk, Color(0.30, 0.15, 0.07))
	cv.draw_rect(Rect2(desk.position.x - 3.0, desk.position.y - 3.0, desk.size.x + 6.0, 4.0), Color(0.55, 0.32, 0.14))
	for k in 3:
		cv.draw_rect(Rect2(desk.position.x + desk.size.x * (0.08 + 0.32 * float(k)), desk.position.y + 5.0, desk.size.x * 0.24, desk.size.y - 9.0), Color(0, 0, 0, 0.18), false, 1.0)
	var lamp: Vector2 = Vector2(desk.position.x + desk.size.x * 0.16, desk.position.y - 3.0)
	cv.draw_line(lamp, lamp + Vector2(0, -glass.size.y * 0.09), Color(0.55, 0.40, 0.18), 1.5)
	var shade_y: float = lamp.y - glass.size.y * 0.09
	cv.draw_colored_polygon(PackedVector2Array([Vector2(lamp.x - 6, shade_y + 6), Vector2(lamp.x + 6, shade_y + 6), Vector2(lamp.x + 3.5, shade_y - 2), Vector2(lamp.x - 3.5, shade_y - 2)]), Color(1.0, 0.88, 0.60))
	glow_at(Vector2(lamp.x, shade_y + 4), 22.0, Color(1.0, 0.85, 0.55, 0.35), 5)
	# a potted palm at the right of the doors
	var pot: Vector2 = Vector2(glass.position.x + glass.size.x * 0.90, floor_y)
	for k in 6:
		var a: float = -PI * 0.5 + (float(k) - 2.5) * 0.42
		var tip: Vector2 = pot + Vector2(0, -glass.size.y * 0.14) + Vector2.from_angle(a) * glass.size.y * 0.16
		cv.draw_line(pot + Vector2(0, -glass.size.y * 0.13), tip, Color(0.16, 0.30, 0.12), 3.0, true)
	cv.draw_colored_polygon(PackedVector2Array([pot + Vector2(-7, 0), pot + Vector2(7, 0), pot + Vector2(9, -glass.size.y * 0.13), pot + Vector2(-9, -glass.size.y * 0.13)]), Color(0.45, 0.22, 0.12))
	# THE GLASS FRONT: dark mullions, a pair of doors in the middle with brass push bars, a transom over them
	var dark_glass: Color = Color(0.05, 0.06, 0.10, 0.22)
	cv.draw_rect(glass, dark_glass)
	var doors: Rect2 = Rect2(glass.get_center().x - glass.size.x * 0.13, glass.position.y + glass.size.y * 0.30, glass.size.x * 0.26, glass.size.y * 0.70)
	for x in [glass.position.x + glass.size.x * 0.25, doors.position.x, doors.get_center().x, doors.end.x, glass.position.x + glass.size.x * 0.75]:
		cv.draw_rect(Rect2(float(x) - 2.0, glass.position.y, 4.0, glass.size.y), frame_c)
	cv.draw_rect(Rect2(glass.position.x, doors.position.y - 2.0, glass.size.x, 4.0), frame_c)
	for side in [-1.0, 1.0]:
		var hx: float = doors.get_center().x + side * doors.size.x * 0.12
		cv.draw_rect(Rect2(hx - 1.5, doors.position.y + doors.size.y * 0.38, 3.0, doors.size.y * 0.24), Color(0.95, 0.76, 0.36))
	# rain on the glass catching the light: a few long soft streaks
	for k in 5:
		var sx: float = glass.position.x + glass.size.x * (0.08 + 0.2 * float(k)) + 6.0 * h01(k + 700)
		cv.draw_line(Vector2(sx, glass.position.y + 4.0), Vector2(sx - glass.size.y * 0.25, glass.end.y - 4.0), Color(1, 1, 1, 0.06), 6.0)
	# the frame round it all: posts, a sill, a header
	cv.draw_rect(Rect2(glass.position.x - 5.0, glass.position.y - 5.0, glass.size.x + 10.0, 6.0), frame_c)
	cv.draw_rect(Rect2(glass.position.x - 5.0, glass.position.y, 5.0, glass.size.y), frame_c)
	cv.draw_rect(Rect2(glass.end.x, glass.position.y, 5.0, glass.size.y), frame_c)
	# THE AWNING: green and cream stripes, sloping out, a scalloped edge
	var aw_top: float = glass.position.y - 22.0
	var aw_bot: float = glass.position.y - 2.0
	var n_st: int = 12
	var sw: float = (glass.size.x + 16.0) / float(n_st)
	for k in n_st:
		var x0: float = glass.position.x - 8.0 + sw * float(k)
		var col: Color = Color(0.10, 0.32, 0.22) if k % 2 == 0 else Color(0.80, 0.76, 0.62)
		col = col.lerp(Color(0.9, 0.9, 0.92), lit * 0.6)
		cv.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 4.0, aw_top), Vector2(x0 + sw + 4.0, aw_top), Vector2(x0 + sw, aw_bot), Vector2(x0, aw_bot)]), col)
		cv.draw_circle(Vector2(x0 + sw * 0.5, aw_bot), sw * 0.5, col)
	cv.draw_line(Vector2(glass.position.x - 4.0, aw_top), Vector2(glass.end.x + 12.0, aw_top), Color(0.05, 0.10, 0.07), 2.0)
	# the lobby's light on the wet pavement in front
	cv.draw_colored_polygon(PackedVector2Array([Vector2(glass.position.x, pave_y), Vector2(glass.end.x, pave_y), Vector2(glass.end.x + 30.0, pave_y + 40.0), Vector2(glass.position.x - 30.0, pave_y + 40.0)]), Color(1.0, 0.75, 0.40, 0.10))

func _paint(full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	var view: Rect2 = g["view"]
	var fl: float = _flash()
	# the room around the window: near black
	cv.draw_rect(Rect2(Vector2.ZERO, full), Color(0.03, 0.03, 0.05))
	# THE STREET below, seen steeply: a building's face with its doorway at the left, the pavement, the
	# kerb, the wet road; all whitened in a flash
	var lit: float = fl * 0.85
	vgrad(view, Color(0.10, 0.11, 0.15).lerp(Color(0.70, 0.74, 0.84), lit), Color(0.06, 0.07, 0.10).lerp(Color(0.55, 0.58, 0.68), lit))
	var pave_y: float = view.position.y + view.size.y * 0.58
	var kerb_y: float = view.position.y + view.size.y * 0.86
	# the building: brick courses, a doorway with steps, a dark window
	var wall: Rect2 = Rect2(view.position, Vector2(view.size.x, pave_y - view.position.y))
	vgrad(wall, Color(0.16, 0.10, 0.09).lerp(Color(0.72, 0.62, 0.60), lit), Color(0.12, 0.08, 0.07).lerp(Color(0.62, 0.52, 0.50), lit))
	var by: float = wall.position.y + 10.0
	var row: int = 0
	while by < wall.end.y:
		cv.draw_line(Vector2(wall.position.x, by), Vector2(wall.end.x, by), Color(0, 0, 0, 0.25), 1.0)
		var bx: float = wall.position.x + (12.0 if row % 2 == 0 else 0.0)
		while bx < wall.end.x:
			cv.draw_line(Vector2(bx, by), Vector2(bx, by - 10.0), Color(0, 0, 0, 0.18), 1.0)
			bx += 24.0
		by += 10.0
		row += 1
	var door: Rect2 = Rect2(view.position.x + view.size.x * 0.12, wall.end.y - wall.size.y * 0.70, view.size.x * 0.16, wall.size.y * 0.70)
	# a deep doorway: a stone surround and lintel, the recess in shadow, a panelled door standing open into the dark
	cv.draw_rect(door.grow(7.0), Color(0.24, 0.20, 0.17).lerp(Color(0.8, 0.78, 0.76), lit))
	cv.draw_rect(Rect2(door.position.x - 11.0, door.position.y - 14.0, door.size.x + 22.0, 9.0), Color(0.30, 0.26, 0.22).lerp(Color(0.85, 0.83, 0.80), lit))
	cv.draw_rect(door, Color(0.05, 0.05, 0.06).lerp(Color(0.30, 0.30, 0.34), lit))
	var leaf: Rect2 = Rect2(door.position.x + door.size.x * 0.62, door.position.y + 3.0, door.size.x * 0.38, door.size.y - 3.0)
	cv.draw_rect(leaf, Color(0.14, 0.09, 0.07).lerp(Color(0.55, 0.45, 0.40), lit))
	for k in 3:
		cv.draw_rect(Rect2(leaf.position.x + 4.0, leaf.position.y + 6.0 + leaf.size.y * 0.32 * float(k), leaf.size.x - 8.0, leaf.size.y * 0.26), Color(0, 0, 0, 0.30), false, 1.5)
	cv.draw_circle(Vector2(leaf.position.x + 5.0, leaf.get_center().y), 2.2, Color(0.70, 0.55, 0.30))
	cv.draw_rect(Rect2(door.position.x - 8.0, door.end.y - 4.0, door.size.x + 16.0, 6.0), Color(0.30, 0.28, 0.26).lerp(Color(0.8, 0.8, 0.8), lit))
	var shop: Rect2 = Rect2(view.position.x + view.size.x * 0.48, wall.position.y + wall.size.y * 0.22, view.size.x * 0.40, wall.size.y * 0.50)
	_hotel_front(shop, lit, pave_y)
	# upper-floor windows, a few lit; a drainpipe
	# THE UPPER WINDOWS, only over the old building (none behind the hotel's sign): a stone sill and lintel,
	# sashes with glazing bars, the dark ones' glass catching a little of the night sky, the lit one with
	# curtains drawn half across (they were flat black boxes)
	for k in 2:
		var wx: float = view.position.x + view.size.x * (0.07 + 0.19 * float(k))
		var wrr: Rect2 = Rect2(wx, wall.position.y + 14.0, view.size.x * 0.12, wall.size.y * 0.15)
		var stone: Color = Color(0.36, 0.32, 0.28).lerp(Color(0.85, 0.83, 0.80), lit)
		cv.draw_rect(wrr.grow(3.0), Color(0.16, 0.12, 0.10))
		var lit_room: bool = k == 1
		if lit_room:
			vgrad(wrr, Color(1.0, 0.82, 0.50), Color(0.85, 0.58, 0.30))
			for side in [0.0, 1.0]:
				var cx0: float = wrr.position.x + (0.0 if side == 0.0 else wrr.size.x * 0.70)
				cv.draw_rect(Rect2(cx0, wrr.position.y, wrr.size.x * 0.30, wrr.size.y), Color(0.55, 0.16, 0.14))
				cv.draw_line(Vector2(cx0 + wrr.size.x * 0.15, wrr.position.y), Vector2(cx0 + wrr.size.x * 0.15, wrr.end.y), Color(0.40, 0.10, 0.09), 2.0)
		else:
			vgrad(wrr, Color(0.14, 0.17, 0.26).lerp(Color(0.55, 0.58, 0.68), lit), Color(0.05, 0.06, 0.09).lerp(Color(0.35, 0.36, 0.44), lit))
			cv.draw_colored_polygon(PackedVector2Array([wrr.position + Vector2(wrr.size.x * 0.15, 0), wrr.position + Vector2(wrr.size.x * 0.45, 0),
				wrr.position + Vector2(wrr.size.x * 0.10, wrr.size.y), wrr.position + Vector2(0, wrr.size.y)]), Color(1, 1, 1, 0.06))
		var bar: Color = Color(0.20, 0.16, 0.13)
		cv.draw_line(Vector2(wrr.get_center().x, wrr.position.y), Vector2(wrr.get_center().x, wrr.end.y), bar, 2.0)
		cv.draw_line(Vector2(wrr.position.x, wrr.get_center().y), Vector2(wrr.end.x, wrr.get_center().y), bar, 3.0)
		cv.draw_rect(Rect2(wrr.position.x - 6.0, wrr.position.y - 8.0, wrr.size.x + 12.0, 6.0), stone)
		cv.draw_rect(Rect2(wrr.position.x - 7.0, wrr.end.y + 2.0, wrr.size.x + 14.0, 5.0), stone)
		cv.draw_rect(Rect2(wrr.position.x - 7.0, wrr.end.y + 7.0, wrr.size.x + 14.0, 2.0), Color(0, 0, 0, 0.35))
	cv.draw_rect(Rect2(view.position.x + view.size.x * 0.40, wall.position.y, 5.0, wall.size.y), Color(0.18, 0.18, 0.20))
	# the neon sign over the shop, steady with a slow breath (no flicker)
	var sign_c: Vector2 = Vector2(shop.get_center().x, shop.position.y - 34.0)
	var neon: Color = Color(1.0, 0.30, 0.45)
	var breathe: float = 0.85 + 0.15 * sin(t * 0.9)
	glow_at(sign_c, 70.0, Color(neon, 0.30 * breathe), 8)
	var f: Font = get_theme_default_font()
	var fs: int = 26 if mobile else 20
	var tw: float = f.get_string_size("HOTEL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	cv.draw_string_outline(f, sign_c + Vector2(-tw * 0.5, fs * 0.36), "HOTEL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(neon, 0.45 * breathe))
	cv.draw_string(f, sign_c + Vector2(-tw * 0.5, fs * 0.36), "HOTEL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.80, 0.86))
	# the pavement and the road, wet
	cv.draw_rect(Rect2(view.position.x, pave_y, view.size.x, kerb_y - pave_y), Color(0.20, 0.20, 0.23).lerp(Color(0.72, 0.72, 0.78), lit))
	var sx: float = view.position.x
	while sx < view.end.x:
		cv.draw_line(Vector2(sx, pave_y), Vector2(sx - 10.0, kerb_y), Color(0, 0, 0, 0.18), 1.0)
		sx += 34.0
	cv.draw_rect(Rect2(view.position.x, kerb_y, view.size.x, 6.0), Color(0.42, 0.42, 0.46))
	cv.draw_rect(Rect2(view.position.x, kerb_y + 6.0, view.size.x, view.end.y - kerb_y - 6.0), Color(0.07, 0.08, 0.10).lerp(Color(0.5, 0.52, 0.6), lit))
	# the shop window's light and the lamp's, on the wet ground
	cv.draw_rect(Rect2(shop.position.x + 10.0, pave_y + 4.0, shop.size.x - 20.0, (kerb_y - pave_y) * 0.8), Color(0.95, 0.70, 0.36, 0.10))
	var lamp: Vector2 = Vector2(view.position.x + view.size.x * 0.82, pave_y - wall.size.y * 0.28)
	cv.draw_line(Vector2(lamp.x, kerb_y), lamp, Color(0.10, 0.10, 0.12), 6.0)
	cv.draw_polygon(PackedVector2Array([lamp + Vector2(-8, 6), lamp + Vector2(8, 6), Vector2(lamp.x + 90.0, kerb_y + 40.0), Vector2(lamp.x - 110.0, kerb_y + 40.0)]),
		PackedColorArray([Color(1.0, 0.85, 0.55, 0.22), Color(1.0, 0.85, 0.55, 0.22), Color(1.0, 0.85, 0.55, 0.0), Color(1.0, 0.85, 0.55, 0.0)]))
	glow_at(lamp, 40.0, Color(1.0, 0.86, 0.55, 0.55), 8)
	cv.draw_circle(lamp, 7.0, Color(1.0, 0.95, 0.8))
	# the lamp and the sign mirrored in the wet road, broken by the rain
	for k in 7:
		var ry: float = kerb_y + 10.0 + float(k) * (view.end.y - kerb_y - 14.0) / 7.0
		var wob: float = sin(t * 3.0 + float(k) * 1.7) * 4.0
		# soft streaks (hard bars read as ladders)
		ellipse(Vector2(lamp.x + wob, ry), 12.0, 3.0, Color(1.0, 0.85, 0.55, 0.14 - 0.015 * float(k)))
		ellipse(Vector2(sign_c.x - wob, ry + 2.0), 26.0, 2.5, Color(neon, 0.11 - 0.012 * float(k)))
	# rain falling outside, fine and slanted
	for k in 70:
		var rx2: float = view.position.x + h01(k * 3) * view.size.x
		var ry2: float = view.position.y + fmod(h01(k * 3 + 1) * view.size.y + t * 520.0 * (0.8 + 0.4 * h01(k)), view.size.y)
		cv.draw_line(Vector2(rx2, ry2), Vector2(rx2 - 4.0, ry2 + 14.0), Color(0.70, 0.76, 0.90, 0.25 + 0.3 * fl), 1.0)

func _paint_top(full: Vector2, _bottom: float) -> void:
	var g: Dictionary = _geom()
	var view: Rect2 = g["view"]
	var fl: float = _flash()
	# RAIN ON THE GLASS: drops sliding down, each leaving a faint trail
	for d in _drops:
		var x: float = view.position.x + float(d[0]) * view.size.x
		var y: float = view.position.y + fmod(float(d[1]) * view.size.y + t * float(d[2]) * 12.0, view.size.y)
		var r: float = 2.0 + float(d[3]) * 30.0
		cv.draw_line(Vector2(x, y - r * 6.0), Vector2(x, y), Color(0.75, 0.82, 0.95, 0.10 + 0.25 * fl), r * 0.5)
		cv.draw_circle(Vector2(x, y), r, Color(0.70, 0.78, 0.92, 0.22 + 0.3 * fl))
		cv.draw_circle(Vector2(x - r * 0.3, y - r * 0.3), r * 0.35, Color(1, 1, 1, 0.35))
	# the flash on the glass itself
	if fl > 0.02:
		cv.draw_rect(view, Color(0.85, 0.90, 1.0, 0.10 * fl))
	# THE WINDOW FRAME round the view, dark wood, a cross bar
	var fc: Color = Color(0.06, 0.05, 0.05)
	cv.draw_rect(Rect2(0.0, view.position.y - 18.0, full.x, 18.0), fc)
	cv.draw_rect(Rect2(0.0, view.end.y, full.x, 26.0), fc)
	cv.draw_rect(Rect2(0.0, view.position.y, view.position.x, view.size.y), fc)
	cv.draw_rect(Rect2(view.end.x, view.position.y, full.x - view.end.x, view.size.y), fc)
	cv.draw_rect(Rect2(view.position.x, view.position.y + view.size.y * 0.42, view.size.x, 10.0), fc)
	cv.draw_rect(Rect2(view.get_center().x - 5.0, view.position.y, 10.0, view.size.y), fc)
	cv.draw_line(Vector2(view.position.x, view.end.y + 2.0), Vector2(view.end.x, view.end.y + 2.0), Color(0.20, 0.17, 0.15), 2.0)
	title("Pinpoint", "Catch the courier and the lookout in a flash of lightning", Color(0.86, 0.92, 1.0).lerp(Color.WHITE, fl),
		Color(0.02, 0.03, 0.06), Color(0.5, 0.6, 1.0, 0.15 + 0.4 * fl))
