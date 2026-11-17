extends "res://scripts/menu_poster.gd"

# SORTING ROBOTS' OPENING POSTER (main.gd menu_backdrop(); see scripts/menu_poster.gd): night in the parcel
# depot -- a dark ribbed wall under a hanging lamp, an amber beacon turning, hazard stripes -- and a
# crane's claw lowered on its cable, swinging one of the game's own parcels (scripts/parcel_art.gd: a real
# 3-D box with two cards on its lid) over a leaning stack of more; every few seconds the inspector's seal
# stamps the swinging box, green or red, and lifts again. Sorting by a rule you have to work out, as a
# picture. Made up, never the board.

const ITEMS: Array = [
	[{"shape": "●", "color": Sleek.PALETTE["RED"]}, {"shape": "▲", "color": Sleek.PALETTE["BLUE"]}],
	[{"shape": "■", "color": Sleek.PALETTE["GREEN"]}, {"shape": "■", "color": Sleek.PALETTE["RED"]}],
	[{"shape": "▲", "color": Sleek.PALETTE["BLUE"]}, {"shape": "●", "color": Sleek.PALETTE["BLUE"]}],
	[{"shape": "●", "color": Sleek.PALETTE["GREEN"]}, {"shape": "▲", "color": Sleek.PALETTE["RED"]}],
	[{"shape": "■", "color": Sleek.PALETTE["BLUE"]}, {"shape": "●", "color": Sleek.PALETTE["RED"]}],
]
const STAMP_EVERY: float = 3.4
# THE DEPOT IS A BAKED PICTURE (the user: "apply the same premade bk solution for a fast startup, which will also
# allow you to use more background crates"): the wall, the lamp, the floor and A BIG PILE of the game's parcels are
# rendered once by devtools/make_menu_stills.gd (this poster's `bake_whole`); at run time the picture is drawn at
# once, and only the beacon, the swinging parcel and its stamp are live. Without the picture, the old small pile.
# the pile when baked: [x as a share of the width, step up the pile, rotation, scale, item]
const PILE: Array = [
	[0.04, 0.0, -1.0, 0.80, 2], [0.24, 0.0, 2.0, 0.80, 3], [0.14, 1.0, -3.0, 0.78, 0],
	[0.56, 0.0, -1.0, 1.0, 0], [0.80, 0.0, 1.5, 1.0, 1], [0.68, 1.0, -2.5, 1.0, 2], [0.56, 2.0, 3.0, 0.96, 3],
	[0.80, 1.0, -1.5, 0.98, 4], [0.70, 2.0, 1.0, 0.92, 1]]

var _stack: Array = []
var _depot: Control = null
var _beacon: Control = null
var _baked_pic: bool = false
var _hung: Control = null
var _hung_size: Vector2 = Vector2.ZERO
var _made_for: float = -1.0
var _stamped: int = -1

func bake_whole() -> bool:
	return true

func bake_ready() -> bool:
	return _all_ready() and _shown >= 1.0

func _setup() -> void:
	_depot = add_still(func(d: Control) -> void: _paint_depot(d, Vector2(MainGlobals.full_screen_size)))
	_beacon = Control.new()
	_beacon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beacon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_beacon.draw.connect(func() -> void: _paint_beacon(_beacon, Vector2(MainGlobals.full_screen_size)))
	add_child(_beacon)
	_baked_pic = not bake_mode and _still_picture(0) != null

func _make(full: Vector2, _bottom: float) -> void:
	if absf(_made_for - full.x) < 0.5 and (not _stack.is_empty() or _hung != null):
		return
	# the swinging parcel is rendered a moment in (its 3-D render held the first frame up), and fades in
	if not bake_mode and t < 0.12:
		return
	_made_for = full.x
	for c in _stack:
		c.queue_free()
	_stack.clear()
	if _hung != null:
		_hung.queue_free()
	var sz: Vector2 = Vector2(full.x * 0.36, full.x * 0.36 * 0.62)
	# the pile: in the baked picture already (none to make), or the big one when baking, or the small one
	var n_pile: int = 0 if _baked_pic else (PILE.size() if bake_mode else 4)
	for k in n_pile:
		var it: Array = ITEMS[int(PILE[k][4]) if bake_mode else k]
		var psz: Vector2 = sz * (float(PILE[k][3]) if bake_mode else 1.0)
		var p: ParcelArt = ParcelArt.make(self, psz, it[0], it[1], 101 + k * 7)
		add_child(p)
		_stack.append(p)
	if bake_mode:
		if _top != null:
			move_child(_top, get_child_count() - 1)
		return
	var hs: Vector2 = sz * 1.15
	var it2: Array = ITEMS[4]
	_hung = ParcelArt.make(self, hs, it2[0], it2[1], 333)
	_hung_size = hs
	add_child(_hung)
	if _top != null:
		move_child(_top, get_child_count() - 1)

# ALL THE BOXES AT ONCE (the user: "the crates appear gradually"): each parcel's picture is rendered in
# turn, so the boxes are kept hidden until every one is ready, then fade in together.
var _shown: float = 0.0

func _all_ready() -> bool:
	for c in _stack + ([_hung] if _hung != null else []):
		if c == null or (c.get("_info") as Dictionary).is_empty():
			return false
	return true

func _tick(delta: float) -> void:
	var full: Vector2 = Vector2(MainGlobals.full_screen_size)
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	_make(full, bottom)
	_beacon.queue_redraw()
	if _stack.is_empty() and _hung == null:
		return
	if _shown > 0.0 or _all_ready():
		_shown = minf(1.0, _shown + delta * 2.5)
	for c in _stack + ([_hung] if _hung != null else []):
		(c as CanvasItem).modulate.a = _shown
	var sz: Vector2 = Vector2(full.x * 0.36, full.x * 0.36 * 0.62)
	# THE PILE at the bottom right: two boxes on the floor, one across them, one more on top, each resting
	# on the ones below (a box's picture fills about the lower 0.62 of its rect; the rest is its lid's
	# perspective), slightly askew -- a column with gaps read as shelves
	var floor_y: float = bottom - 22.0
	var vis: float = sz.y * 0.60
	var x0: float = full.x * 0.98 - sz.x * 1.80
	var spots: Array = [Vector2(0.0, 0.0), Vector2(sz.x * 0.86, 0.0), Vector2(sz.x * 0.44, 1.0), Vector2(sz.x * 0.50, 2.0)]
	for k in _stack.size():
		var c: Control = _stack[k]
		if bake_mode:
			# the big pile: two stacks at the right, a smaller one further back on the left
			var pk: Array = PILE[k]
			var csz: Vector2 = c.size
			c.pivot_offset = Vector2(csz.x * 0.5, csz.y)
			c.position = Vector2(full.x * float(pk[0]) - csz.x * 0.1, floor_y - csz.y - csz.y * 0.60 * float(pk[1]) - (14.0 if float(pk[3]) < 0.9 else 0.0))
			c.rotation = deg_to_rad(float(pk[2]))
			continue
		var sp: Vector2 = spots[k]
		c.pivot_offset = Vector2(sz.x * 0.5, sz.y)
		c.position = Vector2(x0 + sp.x, floor_y - sz.y - vis * sp.y)
		c.rotation = deg_to_rad([-1.0, 1.5, -2.5, 3.0][k])
	if _hung == null:
		return
	# the hanging box, swinging from the claw
	var pivot: Vector2 = Vector2(full.x * 0.28, 0.0)
	var cable: float = clampf(bottom * 0.50, 160.0, 620.0)
	var sw: float = deg_to_rad(9.0) * sin(t * 0.9)
	var hook: Vector2 = pivot + Vector2(0.0, cable).rotated(-sw)
	_hung.pivot_offset = Vector2(_hung_size.x * 0.5, 0.0)
	_hung.position = hook + Vector2(-_hung_size.x * 0.5, 58.0)
	_hung.rotation = -sw
	_hung.scale = Vector2.ONE
	set_meta("hook", hook)
	set_meta("pivot", pivot)
	set_meta("sw", sw)
	# the seal: stamped every few seconds, green or red in turn, lifted again
	var n: int = int(t / STAMP_EVERY)
	var u: float = fmod(t, STAMP_EVERY) / STAMP_EVERY
	if u > 0.30 and u < 0.85 and _stamped != n:
		_stamped = n
		_hung.stamp(n % 3 != 2)
	elif u >= 0.85 and _stamped == n:
		_hung.clear_stamp()
		_stamped = -2

func _paint_depot(d: Control, full: Vector2) -> void:
	var bottom: float = scene_bottom if scene_bottom > 0.0 else full.y * 0.62
	# THE DEPOT WALL: ribbed steel in the dark, a lamp's cone, hazard stripes along the floor
	d.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(full.x, 0), full, Vector2(0, full.y)]),
		PackedColorArray([Color(0.10, 0.11, 0.13), Color(0.10, 0.11, 0.13), Color(0.05, 0.05, 0.06), Color(0.05, 0.05, 0.06)]))
	var x: float = 0.0
	while x < full.x:
		d.draw_rect(Rect2(x, 0.0, 6.0, full.y), Color(1, 1, 1, 0.035))
		d.draw_rect(Rect2(x + 6.0, 0.0, 3.0, full.y), Color(0, 0, 0, 0.25))
		x += 46.0
	var lamp: Vector2 = Vector2(full.x * 0.64, 150.0 if mobile else 100.0)
	var cone: PackedVector2Array = PackedVector2Array([lamp + Vector2(-30, 0), lamp + Vector2(30, 0), Vector2(full.x * 0.98, bottom), Vector2(full.x * 0.22, bottom)])
	d.draw_polygon(cone, PackedColorArray([Color(1.0, 0.90, 0.65, 0.20), Color(1.0, 0.90, 0.65, 0.20), Color(1.0, 0.90, 0.65, 0.02), Color(1.0, 0.90, 0.65, 0.02)]))
	d.draw_line(Vector2(lamp.x, 0.0), lamp, Color(0.2, 0.2, 0.22), 3.0)
	d.draw_colored_polygon(PackedVector2Array([lamp + Vector2(-34, 4), lamp + Vector2(34, 4), lamp + Vector2(16, -14), lamp + Vector2(-16, -14)]), Color(0.30, 0.32, 0.34))
	for g in 6:
		d.draw_circle(lamp + Vector2(0, 6), 46.0 * (1.0 - float(g) / 6.0), Color(1.0, 0.92, 0.70, 0.5 / 6.0))
	# the floor, and hazard stripes along its edge
	var floor_y: float = bottom - 22.0
	d.draw_rect(Rect2(0.0, floor_y, full.x, full.y - floor_y), Color(0.14, 0.14, 0.15))
	var sx: float = -40.0
	while sx < full.x:
		d.draw_colored_polygon(PackedVector2Array([Vector2(sx, floor_y), Vector2(sx + 22.0, floor_y), Vector2(sx + 34.0, floor_y + 12.0), Vector2(sx + 12.0, floor_y + 12.0)]), Color(0.95, 0.72, 0.10))
		sx += 44.0

# the amber beacon, turning (live, over the baked depot)
func _paint_beacon(d: Control, full: Vector2) -> void:
	if bake_mode:
		return
	var bc: Vector2 = Vector2(full.x * 0.90, (250.0 if mobile else 160.0))
	var beam_a: float = t * 2.4
	var reach: float = 220.0
	var bpts: PackedVector2Array = PackedVector2Array([bc, bc + Vector2(cos(beam_a - 0.25), sin(beam_a - 0.25)) * reach, bc + Vector2(cos(beam_a + 0.25), sin(beam_a + 0.25)) * reach])
	d.draw_polygon(bpts, PackedColorArray([Color(1.0, 0.65, 0.15, 0.35), Color(1.0, 0.65, 0.15, 0.0), Color(1.0, 0.65, 0.15, 0.0)]))
	for g in 6:
		d.draw_circle(bc, 30.0 * (1.0 - float(g) / 6.0), Color(1.0, 0.65, 0.15, 0.7 / 6.0))
	d.draw_circle(bc, 9.0, Color(1.0, 0.75, 0.30))

func _paint_top(_full: Vector2, _bottom: float) -> void:
	# THE RIG over the hanging box: the cable to a yellow spreader bar, and two straps from its ends down
	# to the box's lid corners -- turning with the box, so it is plainly holding it (a claw drawn over the
	# box's top did not reach it)
	if has_meta("hook") and _hung != null:
		var pivot: Vector2 = get_meta("pivot")
		var hook: Vector2 = get_meta("hook")
		var sw: float = float(get_meta("sw"))
		var a: float = _shown
		cv.draw_line(pivot, hook, Color(0.55, 0.56, 0.58), 3.0)
		var xf: Transform2D = _hung.get_transform()
		var lid_l: Vector2 = xf * Vector2(_hung_size.x * 0.20, _hung_size.y * 0.30)
		var lid_r: Vector2 = xf * Vector2(_hung_size.x * 0.80, _hung_size.y * 0.30)
		var bar_l: Vector2 = hook + Vector2(-_hung_size.x * 0.30, 22.0).rotated(-sw)
		var bar_r: Vector2 = hook + Vector2(_hung_size.x * 0.30, 22.0).rotated(-sw)
		cv.draw_line(hook, bar_l, Color(0.55, 0.56, 0.58), 2.0)
		cv.draw_line(hook, bar_r, Color(0.55, 0.56, 0.58), 2.0)
		cv.draw_line(bar_l, bar_r, Color(0.95, 0.72, 0.10), 10.0)
		cv.draw_line(bar_l, bar_r, Color(0.15, 0.12, 0.05), 1.5)
		cv.draw_line(bar_l, lid_l, Color(0.25, 0.30, 0.45, a), 6.0)
		cv.draw_line(bar_r, lid_r, Color(0.25, 0.30, 0.45, a), 6.0)
		cv.draw_circle(hook, 7.0, Color(0.35, 0.36, 0.38))
	title("Sorting Robots", "Sort items by hidden rules", Color(1.0, 0.78, 0.30), Color(0.10, 0.07, 0.02), Color(1.0, 0.6, 0.1, 0.22))
