extends Node2D

# Ants: the world, the colonies and the tick.
#
# There is no board, no grid of cells and no tile. The world is a plain Rect2 in world units and an
# ant's position is a Vector2 anywhere inside it -- an ant is never "in" a cell, and nothing it
# does is quantised to one. The two Dictionaries in this game (AntGrid, ScentMarks) are lookup
# accelerators that decide which few neighbours are worth measuring; neither ever rounds a
# position, a heading or a scent strength.
#
# What the colony does is not programmed anywhere. Each ant reads the scent under its own antennae
# and walks; the route to the food is an accident that becomes a habit because returning ants
# reinforce it and evaporation erases everything they stop reinforcing.

signal sig_level_is_done(didwin: bool)
signal started_playing

const SCREEN_UNITS: float = 680.0     # "world": [1,1] means this many units square
const CONTACT_D: float = 9.0          # ants are solid to each other at this distance
# A shove used to be applied in full, the instant it was computed -- up to 4.5 units in one tick,
# half an ant's length, which is a teleport and not a nudge. The more ants shared the trail the
# more often it happened, which is the other half of why the movement got jumpier as the colony
# organised itself. Separation is now a SPEED: an overlap still clears, over two or three ticks.
const MAX_PUSH_RATE: float = 90.0     # units/s
const OPPOSITE_DOT: float = -0.25     # headings this far apart count as a head-on meeting
const EVAPORATE_HZ: float = 10.0
const EVAPORATE_DECAY: float = 0.985  # per evaporation tick, so ~0.86 a second
const FOOD_RADIUS: float = 30.0       # the FULL pile; what is edible shrinks with it, via
									  # AntsArt.pile_radius -- see the note there
# Food has a smell. Nothing used to attract an ant to a pile at all: the only thing drawing it in
# was the scent trail, which ENDS at the pile rather than pointing into it, so an ant passing at 31
# units had no reason to turn and sailed by. A pile a colony is working is the loudest thing in the
# neighbourhood, and this is the counterpart of the nest's own plume.
const FOOD_SENSE_R: float = 78.0
const MIN_FOOD_GAP: float = 240.0     # a pile is never dropped on top of a nest
const MIN_ZOOM: float = 0.42          # below this an ant is a smudge, so the camera pans instead
const NEST_INSET: float = 0.16        # nests sit this far in from the world's edge

const COLONY_TINTS: Array = [
	Color(0.92, 0.72, 0.30), Color(0.47, 0.76, 0.93),
	Color(0.90, 0.51, 0.52), Color(0.62, 0.86, 0.56),
]

var game: GenericGameUtil

var current_level_id: int = 1
var world: Rect2 = Rect2(0, 0, SCREEN_UNITS, SCREEN_UNITS)
var colonies: Array[AntColony] = []
var food: Array = []                  # {"pos": Vector2, "crumbs": int, "start": int}

var obstacles: Array[AntObstacle] = []
# What the player is still holding, by AntObstacle.Kind. A budget for the level, not a rate:
# placing one spends it and picking it up again puts it back.
var stock: Dictionary = {}
var _all: Array[Ant] = []             # every ant of every colony, for the contact pass
var _grid: AntGrid = AntGrid.new(CONTACT_D)
var _cam: Camera2D = null
var _zoom: float = 1.0
var _can_pan: bool = false
var _running: bool = false
var _evap_accum: float = 0.0
var _art_seed: int = 0
var _menu: PopupPanel = null
var _press_at: Vector2 = Vector2.ZERO
var _press_world: Vector2 = Vector2.ZERO
var _dragged: bool = false
var _tap_dead_until: int = 0
const TAP_SLOP: float = 14.0          # screen px of movement that turns a tap into a pan
# Hiding the menu clears MainGlobals.popup_open, and the button RELEASE that follows then reaches
# _end_press with nothing open and opens a fresh menu -- which looks exactly like a menu that
# refuses to close. The gesture has to be swallowed, not just the press. It is armed on the menu's
# own popup_hide rather than on the choice, because the commonest way to close one is a tap
# OUTSIDE it: the popup closes itself on the press, and without this the release then opened a new
# menu at the very spot the player was trying to dismiss to.
const TAP_DEADTIME: float = 0.35

# Watched only so the level knows when it is over and so the HUD can count. Nothing here is saved:
# what this game measures about a PLAYER is not decided yet, and the stats screen will not be told
# it measures something it does not. See ants/docs/design.md.
var delivered: int = 0

func _ready() -> void:
	game = AntsG.game

func new_game(_from_scratch: bool = true) -> void:
	current_level_id = AntsG.starting_level_id
	var cfg: Dictionary = AntsLevelConfig.get_level(current_level_id)
	_art_seed = randi()
	obstacles.clear()
	_stock_up(cfg)
	_build_world(cfg)
	_place_colonies(cfg)
	_place_food(cfg)
	delivered = 0
	_evap_accum = 0.0
	game.set_time_left(0, 0, int(cfg["time_sec"]))
	_fit_camera()
	_running = true
	queue_redraw()
	started_playing.emit()

func _stock_up(cfg: Dictionary) -> void:
	stock.clear()
	var have: Array = cfg.get("stock", [])
	for i in AntObstacle.KINDS.size():
		stock[int(AntObstacle.KINDS[i])] = int(have[i]) if i < have.size() else 0

func stock_of(kind: int) -> int:
	return int(stock.get(kind, 0))

func _build_world(cfg: Dictionary) -> void:
	var w: Array = cfg["world"]
	world = Rect2(Vector2.ZERO, Vector2(float(w[0]) * SCREEN_UNITS, float(w[1]) * SCREEN_UNITS))

func _place_colonies(cfg: Dictionary) -> void:
	colonies.clear()
	_all.clear()
	var n: int = int(cfg["colonies"])
	var sp: Array = cfg["speed_scale"]
	for i in n:
		var at: Vector2 = _nest_position(i, n)
		var c: AntColony = AntColony.new(at, i, COLONY_TINTS[i % COLONY_TINTS.size()])
		c.populate(int(cfg["ants_per_colony"]), float(sp[0]), float(sp[1]))
		colonies.append(c)
		_all.append_array(c.ants)

# One nest goes near a corner so the food can sit at the far one and the first crossing is a real
# journey. Several are spread round a ring, which keeps them apart without any of them owning the
# center.
func _nest_position(i: int, n: int) -> Vector2:
	if n == 1:
		return world.position + Vector2(world.size.x * NEST_INSET, world.size.y * NEST_INSET)
	var mid: Vector2 = world.position + world.size * 0.5
	var a: float = TAU * float(i) / float(n) - PI * 0.75
	var r: Vector2 = world.size * (0.5 - NEST_INSET)
	return mid + Vector2(cos(a) * r.x, sin(a) * r.y)

func _place_food(cfg: Dictionary) -> void:
	food.clear()
	var n: int = int(cfg["food_piles"])
	var crumbs: int = int(cfg["crumbs_per_pile"])
	for i in n:
		var at: Vector2 = _food_position(i, n)
		food.append({"pos": at, "crumbs": crumbs, "start": crumbs, "seed": _art_seed + i * 977})

func _food_position(i: int, n: int) -> Vector2:
	# With one colony and one pile the answer is the opposite corner -- the brief was to watch ants
	# cross the world to find it.
	if colonies.size() == 1 and n == 1:
		return world.position + world.size * (1.0 - NEST_INSET)
	var best: Vector2 = world.get_center()
	var best_gap: float = -1.0
	# Rejection sampling rather than a formula: the constraint is only "far from every nest", and
	# 24 throws land well inside it without needing the placement to be solved.
	for _attempt in 24:
		var p: Vector2 = world.position + Vector2(
			randf_range(world.size.x * 0.08, world.size.x * 0.92),
			randf_range(world.size.y * 0.08, world.size.y * 0.92))
		var gap: float = INF
		for c: AntColony in colonies:
			gap = minf(gap, p.distance_to(c.nest))
		for f: Dictionary in food:
			gap = minf(gap, p.distance_to(f["pos"] as Vector2) * 0.7)
		if gap > best_gap:
			best_gap = gap
			best = p
		if gap > MIN_FOOD_GAP:
			break
	return best

# --- the tick ---------------------------------------------------------------

# _process, NOT _physics_process. There is no physics engine in this game -- no bodies, no shapes,
# no collision server -- so the physics tick buys nothing, and stepping at 60 Hz while DRAWING at
# the display's refresh rate means the two cadences disagree: every ant repeats a position or skips
# one whenever they drift apart, which is visible as a fine stutter on everything at once. Stepped
# here, a drawn frame is always the frame that was just simulated.
func _process(delta: float) -> void:
	if not _running or not game.playing or game.paused():
		return
	# A long frame must not teleport ants through each other: the contact pass only separates
	# overlaps it can see, and a 0.5s step moves an ant 28 units, three whole body widths.
	var dt: float = minf(delta, 0.05)
	sim_step(dt)
	queue_redraw()

# Split out so a headless probe can run the colony forward without a display or a clock.
func sim_step(dt: float) -> void:
	_smell_food()
	for c: AntColony in colonies:
		for a: Ant in c.ants:
			a.step(dt, c.marks, world, obstacles)
	_resolve_contacts(dt)
	_resolve_obstacles(dt)
	_resolve_sites()
	_evap_accum += dt
	var period: float = 1.0 / EVAPORATE_HZ
	while _evap_accum >= period:
		_evap_accum -= period
		for c: AntColony in colonies:
			c.marks.evaporate(EVAPORATE_DECAY)

# Nothing may be left standing inside a stone. The antennae (see Ant._edge_turn) keep an ant from
# walking in, but a shallow clip is always possible, so this is the backstop. Rate-limited like
# every other correction here: a full-size teleport out of a twig would be the same jumpiness the
# separation pass was fixed for.
func _resolve_obstacles(dt: float) -> void:
	if obstacles.is_empty():
		return
	var cap: float = MAX_PUSH_RATE * dt
	for a: Ant in _all:
		for o: AntObstacle in obstacles:
			if not o.contains(a.pos):
				continue
			var d: Vector2 = o.push_out(a.pos, 1.0) - a.pos
			if d.length_squared() > cap * cap:
				d = d.normalized() * cap
			a.pos += d
			break

# An obstacle dropped on a colony's road. Returns false if it would sit on a nest or a pile, which
# would strand a colony for good rather than making it work.
# `rot` defaults to INF, meaning "pick one" -- a tap gives no orientation, and a random angle per
# drop is what keeps a field of stones from looking stamped. It is a parameter because a twig is
# 152 units long and 18 wide, so its angle is most of what it does, and anything that wants to lay
# a deliberate wall (a probe today, orientation control tomorrow) has to be able to say.
func place_obstacle(kind: int, at: Vector2, rot: float = INF) -> bool:
	if stock_of(kind) <= 0:
		return false
	var angle: float = randf_range(-PI, PI) if is_inf(rot) else rot
	var o: AntObstacle = AntObstacle.new(kind, at, angle, randi())
	for c: AntColony in colonies:
		if o.contains(c.nest) or c.nest.distance_to(at) < o.bound_radius() + AntColony.NEST_RADIUS:
			return false
	for f: Dictionary in food:
		if o.contains(f["pos"] as Vector2) or (f["pos"] as Vector2).distance_to(at) < o.bound_radius() + FOOD_RADIUS:
			return false
	# Two of these may not share ground. Overlapping pairs would also make a shape whose outline is
	# not either obstacle's outline, and edge following reads exactly that outline to get round.
	for other: AntObstacle in obstacles:
		if o.overlaps(other):
			return false
	obstacles.append(o)
	stock[kind] = stock_of(kind) - 1

	# Ants standing where it lands are crushed. That is the whole reason a tally exists: dropping
	# something on a busy trail cannot be free.
	for c: AntColony in colonies:
		var survivors: Array[Ant] = []
		for a: Ant in c.ants:
			if o.contains(a.pos):
				c.killed += 1
			else:
				survivors.append(a)
		c.ants = survivors
		# The scent under it is under it.
		c.marks.erase_if(func(p: Vector2) -> bool: return o.contains(p))
	_rebuild_all()
	queue_redraw()
	return true

# Picked back up, and returned to the stock. Gives the kind that was taken, or -1.
func remove_obstacle_at(at: Vector2) -> int:
	for i in range(obstacles.size() - 1, -1, -1):
		if obstacles[i].contains(at):
			var kind: int = obstacles[i].kind
			obstacles.remove_at(i)
			stock[kind] = stock_of(kind) + 1
			queue_redraw()
			return kind
	return -1

func obstacle_at(at: Vector2) -> bool:
	for o: AntObstacle in obstacles:
		if o.contains(at):
			return true
	return false

func _rebuild_all() -> void:
	_all.clear()
	for c: AntColony in colonies:
		_all.append_array(c.ants)

func ants_killed() -> int:
	var n: int = 0
	for c: AntColony in colonies:
		n += c.killed
	return n

# Which pile, if any, each searching ant can smell. Done here rather than inside the ant because
# the food is the level's to know about; the ant is only told there is something over there.
func _smell_food() -> void:
	for a: Ant in _all:
		a.has_smelled_food = false
		if a.state != Ant.State.SEARCHING:
			continue
		var best: float = FOOD_SENSE_R * FOOD_SENSE_R
		for f: Dictionary in food:
			if int(f["crumbs"]) <= 0:
				continue
			var d2: float = a.pos.distance_squared_to(f["pos"] as Vector2)
			if d2 < best:
				best = d2
				a.smelled_food = f["pos"]
				a.has_smelled_food = true

# Ants are solid, and two meeting head-on stop and touch antennae. Both fall out of the same pass,
# because both are answers to "who is next to me" and the spatial hash is the expensive part.
func _resolve_contacts(dt: float) -> void:
	_grid.clear()
	var n: int = _all.size()
	for i in n:
		_grid.add(_all[i].pos, i)
	# Gathered first and applied after, so an ant caught between two neighbours gets ONE bounded
	# move rather than being knocked twice in the same tick by whichever pairs happened to be
	# visited -- and so the order ants appear in the array stops mattering.
	var push: PackedVector2Array = PackedVector2Array()
	push.resize(n)
	var d2_max: float = CONTACT_D * CONTACT_D
	for i in n:
		var a: Ant = _all[i]
		for j in _grid.near(a.pos):
			if j <= i:
				continue
			var b: Ant = _all[j]
			var off: Vector2 = b.pos - a.pos
			var d2: float = off.length_squared()
			if d2 >= d2_max or d2 < 0.0001:
				continue
			var dist: float = sqrt(d2)
			var half: Vector2 = off / dist * ((CONTACT_D - dist) * 0.5)
			push[i] -= half
			push[j] += half
			if a.contact_cd <= 0.0 and b.contact_cd <= 0.0 \
					and a.stop_timer <= 0.0 and b.stop_timer <= 0.0 \
					and cos(a.heading - b.heading) < OPPOSITE_DOT:
				# The cooldown is not decoration. Without it a busy trail is a standing crowd:
				# every pair re-greets the moment the last greeting ends, and nothing moves again.
				a.greet()
				b.greet()
	var cap: float = MAX_PUSH_RATE * dt
	for i in n:
		var p: Vector2 = push[i]
		if p.length_squared() > cap * cap:
			p = p.normalized() * cap
		_all[i].shove(p, dt)

func _resolve_sites() -> void:
	for c: AntColony in colonies:
		for a: Ant in c.ants:
			if a.state == Ant.State.SEARCHING:
				for f: Dictionary in food:
					if int(f["crumbs"]) <= 0:
						continue
					var off: Vector2 = a.pos - (f["pos"] as Vector2)
					# Against the pile's REAL lobed edge at the ant's own bearing, and against its
					# current size -- the same two functions that draw it. A crumb can only be taken
					# from where a crumb can be seen.
					var rr: float = AntsArt.pile_radius(FOOD_RADIUS,
						float(f["crumbs"]) / maxf(float(f["start"]), 1.0))
					if off.length() <= AntsArt.pile_edge(rr, off.angle(), int(f["seed"])):
						f["crumbs"] = int(f["crumbs"]) - 1
						a.pick_up_food()
						break
			elif c.at_hole(a.pos):
				a.drop_food()
				c.delivered += 1
				delivered += 1
				# is_actual_score = false: the HUD counts the crumbs, and nothing is written to the
				# player's record. Until this is a game with a task in it, there is no score to save.
				game.add_score_and_time(1, 0, false)
	if _is_finished():
		_running = false
		sig_level_is_done.emit(true)

func _is_finished() -> bool:
	for f: Dictionary in food:
		if int(f["crumbs"]) > 0:
			return false
	for a: Ant in _all:
		if a.state == Ant.State.HOMING:
			return false
	return true

# --- camera -----------------------------------------------------------------

func _fit_camera() -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = Camera2D.new()
		_cam.position_smoothing_enabled = false
		add_child(_cam)
	var vp: Vector2 = get_viewport_rect().size
	var fit: float = minf(vp.x / world.size.x, vp.y / world.size.y)
	# A 10x10 world fits the screen at zoom 0.1, where an 11-unit ant is one pixel and there is
	# nothing to watch. Legibility wins over completeness: past MIN_ZOOM the camera shows part of
	# the world and pans. Level 1 is sized so this never triggers.
	_zoom = maxf(fit, MIN_ZOOM)
	_can_pan = _zoom > fit + 0.0001
	_cam.zoom = Vector2(_zoom, _zoom)
	_cam.position = colonies[0].nest if (_can_pan and colonies.size() > 0) else world.get_center()
	_clamp_cam()
	_cam.enabled = true
	_cam.make_current()

func _clamp_cam() -> void:
	var half: Vector2 = get_viewport_rect().size * 0.5 / _zoom
	var lo: Vector2 = world.position + half
	var hi: Vector2 = world.position + world.size - half
	var p: Vector2 = _cam.position
	p.x = clampf(p.x, lo.x, hi.x) if lo.x <= hi.x else world.get_center().x
	p.y = clampf(p.y, lo.y, hi.y) if lo.y <= hi.y else world.get_center().y
	_cam.position = p

func visible_world() -> Rect2:
	if _cam == null or not is_instance_valid(_cam):
		return world
	var span: Vector2 = get_viewport_rect().size / _zoom
	return Rect2(_cam.position - span * 0.5, span).grow(24.0)

# A press that does not travel is a TAP and opens the obstacle menu; one that travels is a pan.
# They share the same gesture because the world is bigger than the screen on most levels and both
# have to be available without a mode switch.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _running:
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_begin_press(st.position)
		else:
			_end_press()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_press(mb.position)
			else:
				_end_press()
		return
	var moved: Vector2 = Vector2.ZERO
	if event is InputEventScreenDrag:
		moved = (event as InputEventScreenDrag).relative
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		moved = mm.relative
	else:
		return
	if not _dragged and _press_at.distance_to(get_viewport().get_mouse_position()) < TAP_SLOP \
			and moved.length() < TAP_SLOP:
		return
	_dragged = true
	if _can_pan:
		_cam.position -= moved / _zoom
		_clamp_cam()
		queue_redraw()

func _begin_press(at: Vector2) -> void:
	_press_at = at
	_press_world = _screen_to_world(at)
	_dragged = false

func _end_press() -> void:
	if _dragged or MainGlobals.popup_open or Time.get_ticks_msec() < _tap_dead_until:
		return
	_open_obstacle_menu(_press_at, _press_world)

func _screen_to_world(at: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * at

func _open_obstacle_menu(screen_at: Vector2, world_at: Vector2) -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
	var here: Vector2 = world_at
	_menu = ObstacleMenu.open(self, screen_at,
		func(kind: int, is_remove: bool) -> void:
			if is_remove:
				remove_obstacle_at(here)
			else:
				place_obstacle(kind, here),
		obstacle_at(world_at), self)
	if _menu != null:
		_menu.popup_hide.connect(func() -> void:
			_tap_dead_until = Time.get_ticks_msec() + int(TAP_DEADTIME * 1000.0))

# --- drawing ----------------------------------------------------------------

func _draw() -> void:
	if colonies.is_empty():
		return
	var vis: Rect2 = visible_world()
	AntsArt.draw_ground(self, vis, world, _zoom, _art_seed)
	for c: AntColony in colonies:
		AntsArt.draw_marks(self, c.marks.marks_in(vis), _zoom)
	for f: Dictionary in food:
		var p: Vector2 = f["pos"]
		if vis.has_point(p):
			AntsArt.draw_food(self, p, FOOD_RADIUS,
				float(f["crumbs"]) / maxf(float(f["start"]), 1.0), int(f["seed"]))
	for o: AntObstacle in obstacles:
		if vis.intersects(Rect2(o.pos - Vector2.ONE * o.bound_radius(),
				Vector2.ONE * o.bound_radius() * 2.0)):
			AntsArt.draw_obstacle(self, o)
	for c: AntColony in colonies:
		if vis.has_point(c.nest):
			AntsArt.draw_nest(self, c.nest, AntColony.NEST_RADIUS, c.tint)
	for a: Ant in _all:
		if vis.has_point(a.pos):
			AntsArt.draw_ant(self, a, _zoom)

# --- reporting (probe / design; nothing here is written to the player's record) ---

func ant_count() -> int:
	return _all.size()

func crumbs_left() -> int:
	var n: int = 0
	for f: Dictionary in food:
		n += int(f["crumbs"])
	return n

func carrying_count() -> int:
	var n: int = 0
	for a: Ant in _all:
		if a.state == Ant.State.HOMING:
			n += 1
	return n

func mark_count() -> int:
	var n: int = 0
	for c: AntColony in colonies:
		n += c.marks.count()
	return n

func worst_overlap() -> float:
	var worst: float = 0.0
	for i in _all.size():
		for j in range(i + 1, _all.size()):
			var d: float = _all[i].pos.distance_to(_all[j].pos)
			if CONTACT_D - d > worst:
				worst = CONTACT_D - d
	return worst

# For the probe: how far the worst-placed ant is inside something solid.
func worst_intrusion() -> float:
	var worst: float = 0.0
	for a: Ant in _all:
		for o: AntObstacle in obstacles:
			if o.contains(a.pos):
				worst = maxf(worst, (o.push_out(a.pos, 0.0) - a.pos).length())
	return worst

func all_inside_world() -> bool:
	for a: Ant in _all:
		if not world.grow(1.0).has_point(a.pos):
			return false
	return true
