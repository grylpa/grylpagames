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

# Every name this level ever passes to game.tutorial_notify. Kept as a list so the tutorial's
# awaited events can be checked against it: a step waiting on an event nothing emits is not a
# broken caption, it is a dead end the player cannot get out of except by the timeout.
const TUTORIAL_EVENTS: Array = ["menu_opened", "tip_shown", "obstacle_placed", "bait_placed",
	"obstacle_removed", "bait_taken", "crumb_through", "sprayed"]

signal sig_level_is_done(didwin: bool)
signal started_playing

const SCREEN_UNITS: float = 680.0     # the canvas is this wide on every device
const CONTACT_D: float = 9.0          # ants are solid to each other at this distance, at desktop
									  # scale; a bigger ant needs proportionally more room, or a
									  # colony drawn at double size is a heap of overlapping bodies
# A shove used to be applied in full, the instant it was computed -- up to 4.5 units in one tick,
# half an ant's length, which is a teleport and not a nudge. The more ants shared the trail the
# more often it happened, which is the other half of why the movement got jumpier as the colony
# organised itself. Separation is now a SPEED: an overlap still clears, over two or three ticks.
const MAX_PUSH_RATE: float = 90.0     # units/s at PUSH_REF pace
# The pace this rate was tuned against -- the fastest an ant could be when it was chosen. Two ants
# closing head-on approach at twice their own speed, so the separation has to be able to undo in a
# tick what a tick of walking created: at 1.25x that is 2.9 units a tick against a 1.5-unit push,
# which clears in two or three ticks as intended, and at 4.4x it is 10 units against the same 1.5
# and the overlap simply persists. So the rate scales with the level's top speed and the geometry
# holds at any pace -- the same reasoning as Ant.turn_scale().
const PUSH_REF: float = 1.25
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
const NEST_INSET: float = 0.16        # nests sit this far in from the world's edge

const COLONY_TINTS: Array = [
	Color(0.92, 0.72, 0.30), Color(0.47, 0.76, 0.93),
	Color(0.90, 0.51, 0.52), Color(0.62, 0.86, 0.56),
]

var game: GenericGameUtil

var current_level_id: int = 1
var world: Rect2 = Rect2(0, 0, SCREEN_UNITS, SCREEN_UNITS)
# Where ants may actually be: the world less its wall. Every rule that used to be stated against
# `world` is stated against this instead, so the border is a place and not a painted line.
var walkable: Rect2 = Rect2(0, 0, SCREEN_UNITS, SCREEN_UNITS)
var colonies: Array[AntColony] = []
var food: Array = []                  # {"pos": Vector2, "crumbs": int, "start": int}

var obstacles: Array[AntObstacle] = []
# The spray. One can for the level, with a large number of presses; what it lays down fades.
var spray: Repellent = Repellent.new()
var spray_left: int = 0
var spray_presses_total: int = 0
# What the player is still holding, by AntObstacle.Kind. A budget for the level, not a rate:
# placing one spends it and picking it up again puts it back.
var stock: Dictionary = {}
var _solid: Array[AntObstacle] = []   # the ones an ant has to walk around, rebuilt when they change
var _all: Array[Ant] = []             # every ant of every colony, for the contact pass
var _grid: AntGrid = AntGrid.new(CONTACT_D)
var contact_d: float = CONTACT_D
var push_rate: float = MAX_PUSH_RATE
var _cam: Camera2D = null
var _zoom: float = 1.0
var _can_pan: bool = false
var _running: bool = false
var _evap_accum: float = 0.0
var _clock: float = 0.0               # seconds of level time, for the colonies' emergence
var _art_seed: int = 0
# THREE LAYERS, SPLIT BY HOW OFTEN THEY CHANGE.
#
# Everything used to be drawn in one _draw() that ran every frame because the ants had moved. The
# GROUND went with it: at a phone viewport that is 4,795 draw_circle calls rebuilt sixty times a
# second, 288,000 a second, for a surface that does not change at all until the camera moves. It
# was the single biggest cost in the game and none of it was doing anything.
#
# Godot keeps each CanvasItem's command list and re-issues it without running _draw() again, so a
# layer that is not marked dirty is free. The ground is built ONCE PER LEVEL and never again -- it
# covers the whole world, so no amount of panning can make it stale; the trail, which changes
# slowly, redraws at TRAIL_HZ; only the things that actually move redraw every frame.
var _bg: Node2D = null
var _trail_layer: Node2D = null
var _fg: Node2D = null
var _trail_accum: float = 0.0
# The tool menu is a CanvasLayer over the viewport, not a PopupPanel. A Window clips everything to
# its own rect, which left a tooltip either cropped inside the ring or forced the whole menu to grow
# around it; an overlay has no rect to be clipped by.
var _menu: CanvasLayer = null
var _press_at: Vector2 = Vector2.ZERO
var _press_world: Vector2 = Vector2.ZERO
var _dragged: bool = false
# Which pointer owns the gesture: -2 none, -1 the mouse, >= 0 a touch index. A second finger --
# or a palm resting on the glass -- used to add its own drag to the same camera, so the view shot
# off at twice the speed or fought itself. Only the finger that started the press may pan.
var _press_index: int = -2
var _tap_dead_until: int = 0
# Drag is GATHERED here and applied once in _process. Applying each event as it arrived moved the
# camera several times a frame and asked for a redraw each time, so how far the view travelled
# depended on how many touch events the device happened to deliver -- which on a phone is neither
# steady nor in step with the frame. That is what made panning judder.
var _pan_accum: Vector2 = Vector2.ZERO
const TAP_SLOP: float = 14.0          # screen px of movement that turns a tap into a pan
# Hiding the menu clears MainGlobals.popup_open, and the button RELEASE that follows then reaches
# _end_press with nothing open and opens a fresh menu -- which looks exactly like a menu that
# refuses to close. The gesture has to be swallowed, not just the press. It is armed on the menu's
# own popup_hide rather than on the choice, because the commonest way to close one is a tap
# OUTSIDE it: the popup closes itself on the press, and without this the release then opened a new
# menu at the very spot the player was trying to dismiss to.
const TAP_DEADTIME: float = 0.35
const SPRAY_PICK: int = -2            # the menu's code for "the can", not an AntObstacle.Kind

# The colony's tally, and the player's. `delivered` is what got home; the score on the HUD is the
# allowance minus that, so it reads as "how much more can I afford to let past".
var delivered: int = 0
var crumbs_through: int = 0
var stock_at_start: Dictionary = {}
# Every ant something was dropped on, left where it was dropped on. {pos, heading}.
# The counter on the top strip says how many; these say WHERE and on what, which is the part a
# player can act on. They are NOT cleared when the thing that crushed them is picked up again --
# taking the stone away does not bring the ants back, and the evidence is the point.
var corpses: Array = []

# --- what this game MEASURES ------------------------------------------------
#
# THE PROBLEM: this level is one continuous run. There are no rounds, no trials and no prompts, so
# there is nothing to time -- and until now the game recorded two end-of-session COUNTS (crumbs
# through, ants crushed) and no distribution at all. Counts say how it went; they cannot say
# whether the player is getting quicker at noticing, which is the thing worth watching.
#
# THE TRIALS ARE ALREADY THERE, they just have to be named. The colony re-forms a road within about
# a minute of losing one, and that is an EVENT with an onset: the moment a route's scent crosses
# from "nothing much" into "a road". The player's next action on that route is the response. So
# every road that matures is a trial and the gap is a reaction time -- which is exactly the
# vigilance this game trains, a forming road being a low-salience change in the corner of the board
# rather than a prompt that announces itself.
#
# Non-responses are counted SEPARATELY as roads_missed rather than folded in at some capped time: a
# cap would quietly inflate the mean with events the player never engaged with at all.
const ROAD_ON: float = 3.2            # scent at a sample point that counts as "a road"
const ROAD_OFF: float = 1.4           # and what it must fall back under to re-arm
const ROAD_NEAR: float = 150.0        # an action this close to a road answers it
const ROAD_WINDOW: float = 25.0       # past this, the road is missed rather than answered slowly
const ROAD_STEP: float = 70.0         # spacing of the sample points along a nest->pile corridor

var road_times_ms: Array = []         # one entry per road answered
var roads_missed: int = 0
var road_onsets: int = 0              # how many formed at all, answered or not
var roads_unseen: int = 0             # matured off-screen and never came into view
var obstacles_moved: int = 0          # picked up again, which is the whole loop
var placements_wasted: int = 0        # dropped where nothing was walking
var _road_pending: Array = []         # [{pos, at}] roads formed and not yet answered
var _road_armed: Array = []           # per sample point: ready to fire again?
var _road_pts: Array = []
var bait_taken: int = 0
# Crushing ants is not the way to win and is priced accordingly: an ant is worth several crumbs.
const KILL_PENALTY: int = 5

func _ready() -> void:
	game = AntsG.game
	# A tool menu is a CanvasLayer on this node, not a child of the board, so hiding the level does
	# not hide it: pressing M with one open left it floating over the main menu.
	visibility_changed.connect(func() -> void:
		if not visible:
			_close_menu())
	MainGlobals.sig_need_to_close_info_popups.connect(_close_menu)
	_bg = Node2D.new()
	_trail_layer = Node2D.new()
	_fg = Node2D.new()
	var z: int = 0
	for n: Node2D in [_bg, _trail_layer, _fg]:
		n.z_index = z
		z += 1
		add_child(n)
	_bg.draw.connect(_draw_bg)
	_trail_layer.draw.connect(_draw_trail)
	_fg.draw.connect(_draw_fg)

func new_game(_from_scratch: bool = true) -> void:
	current_level_id = AntsG.starting_level_id
	var cfg: Dictionary = AntsLevelConfig.get_level(current_level_id)
	_art_seed = randi()
	obstacles.clear()
	corpses.clear()
	_solid.clear()
	spray.clear()
	spray_left = int(cfg.get("spray_presses", 0))
	spray_presses_total = spray_left
	# One place decides how large an ant is on this device, and the two distances measured against
	# its body follow from it.
	Ant.draw_scale = AntsG.creature_scale
	contact_d = CONTACT_D * Ant.draw_scale
	push_rate = MAX_PUSH_RATE * Ant.draw_scale \
		* maxf(float(cfg["speed_scale"][1]) / PUSH_REF, 1.0)
	_grid = AntGrid.new(contact_d)
	_stock_up(cfg)
	_build_world(cfg)
	_place_colonies(cfg)
	_place_food(cfg)
	delivered = 0
	crumbs_through = 0
	road_times_ms.clear()
	roads_missed = 0
	road_onsets = 0
	roads_unseen = 0
	obstacles_moved = 0
	placements_wasted = 0
	_road_pending.clear()
	_build_road_samples()
	bait_taken = 0
	_evap_accum = 0.0
	_clock = 0.0
	_pan_accum = Vector2.ZERO
	game.set_time_left(0, 0, int(cfg["time_sec"]))
	_fit_camera()
	_running = true
	_redraw_all()
	# Which level this is, over the world and under the HUD -- the shared LevelLabel every other
	# game uses. Ants never called it, so during play there was nothing on screen that said where
	# you were, and the level is the whole difficulty ladder.
	game.level_label_changed("Level %d" % current_level_id)
	started_playing.emit()
	# Shown last, so the world behind it is already built. Nothing else has to gate on it:
	# GenericGameUtil.paused() is true while any screen is visible, and _process checks that, so
	# the colony stands still until the card is dismissed.
	#
	# Not during a tutorial: the coach is about to say all of this properly, and a wall of text to
	# dismiss first is exactly what the tutorial exists instead of.
	if not game.tutorial_mode:
		game.show_game_popup(self, "Level %d" % current_level_id, briefing_text())

# What the player is told before the level starts. Built as "Label: value" lines, which the shared
# briefing card lays out as a table.
#
# Three of the four lines can be withheld (tell_world / tell_colonies / tell_food) and read
# "Unknown" instead. The ants' pace is always given: it is the one fact a player can check for
# themselves by watching, so hiding it would only be a nuisance.
# Screen-space boxes for the tutorial's spotlights. MEASURED, never authored: everything here is
# drawn through a camera, so a radius in screen units means something different at another creature
# scale, and the gorilla tutorial has the scars to prove it (see gorilla/docs/design.md).
func _to_screen(at: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * at

func tutorial_nest_rect() -> Rect2:
	if colonies.is_empty():
		return Rect2()
	var r: float = AntColony.NEST_RADIUS * 1.5 * _zoom
	return Rect2(_to_screen(colonies[0].nest) - Vector2(r, r), Vector2(r, r) * 2.0)

func tutorial_pile_rect() -> Rect2:
	if food.is_empty():
		return Rect2()
	var r: float = (FOOD_RADIUS + 12.0) * _zoom
	return Rect2(_to_screen(food[0]["pos"]) - Vector2(r, r), Vector2(r, r) * 2.0)

# The middle of the road, which is where a wall wants to go. Screen space, so the caption's
# spotlight sits on it wherever the camera happens to be.
func tutorial_trail_rect() -> Rect2:
	if colonies.is_empty() or food.is_empty():
		return Rect2()
	var mid: Vector2 = colonies[0].nest + ((food[0]["pos"] as Vector2) - colonies[0].nest) * 0.5
	var r: float = 70.0 * _zoom
	return Rect2(_to_screen(mid) - Vector2(r, r), Vector2(r, r) * 2.0)

# The open tool menu, for the coach to keep off. A step that says "tap the thing you placed and
# choose the red cross" is unusable if the balloon is sitting on the red cross.
# A menu that has been PICKED FROM is gone, even though it is still in the tree for the rest of the
# frame. ObstacleMenu's cell calls close() and then on_pick(), and on_pick is what notifies the
# tutorial -- so a step entering on that notification ran its setup while queue_free() was still
# pending, saw a live node, and decided a menu was already open. The bait step then showed its
# caption over nothing. is_instance_valid() is true for a queued node; this is the question that
# actually wanted asking.
func _menu_open() -> bool:
	return _menu != null and is_instance_valid(_menu) and not _menu.is_queued_for_deletion()

func tutorial_menu_rect():
	if not _menu_open() or not _menu.has_meta("ring_rect"):
		return null
	return _menu.get_meta("ring_rect")

# One tool at a time, so burying any single one is enough to move the coach off it.
func tutorial_menu_cell(i: int):
	if not _menu_open() or not _menu.has_meta("cell_rects"):
		return null
	var cells: Array = _menu.get_meta("cell_rects")
	return cells[i] if i < cells.size() else null

# The cell for ONE named tool, so a step that talks about bait can point at the bait rather than at
# the ring. Asked by kind, never by slot: which boxes exist depends on what the player has left.
# AntObstacle.Kind.* for a tool, SPRAY_PICK for the can, -1 for the red cross.
func tutorial_menu_cell_of(kind: int):
	if not _menu_open() or not _menu.has_meta("cell_kinds"):
		return null
	var kinds: Array = _menu.get_meta("cell_kinds")
	var cells: Array = _menu.get_meta("cell_rects")
	var i: int = kinds.find(kind)
	return cells[i] if i >= 0 and i < cells.size() else null

# Open the tool menu FOR the player, so a step about a tool can show the tool instead of describing
# it and hoping. `on_placed` opens it over the last thing put down (the only way the red cross is
# there at all); otherwise it opens on the road, which is where a wall wants to go anyway -- and
# where the pick will land, since a pick acts at the point the menu was opened from.
#
# Idempotent: a menu the player already has open is left exactly as it is. Re-opening it would move
# it out from under a finger already on its way to a box.
func tutorial_open_menu(on_placed: bool = false) -> void:
	if _menu_open():
		return
	var at: Vector2 = Vector2.ZERO
	if on_placed:
		if obstacles.is_empty():
			return
		at = obstacles[obstacles.size() - 1].pos
	else:
		if colonies.is_empty() or food.is_empty():
			return
		at = colonies[0].nest + ((food[0]["pos"] as Vector2) - colonies[0].nest) * 0.5
	_open_obstacle_menu(_to_screen(at), at)

# The last thing the player put down -- which is the thing a step asking them to pick it up again
# needs them to be able to see.
func tutorial_last_placed_rect():
	if obstacles.is_empty():
		return null
	var o: AntObstacle = obstacles[obstacles.size() - 1]
	var r: float = o.bound_radius() * _zoom
	return Rect2(_to_screen(o.pos) - Vector2(r, r), Vector2(r, r) * 2.0)

func tutorial_has_placed() -> bool:
	return not obstacles.is_empty()

# How well the colony has organised itself, for a watch-and-see step to end on.
func tutorial_trail_strength() -> float:
	if colonies.is_empty() or food.is_empty():
		return 0.0
	var mid: Vector2 = colonies[0].nest + ((food[0]["pos"] as Vector2) - colonies[0].nest) * 0.5
	return colonies[0].marks.sense(mid)

func briefing_text() -> String:
	var cfg: Dictionary = AntsLevelConfig.get_level(current_level_id)
	var sp: Array = cfg["speed_scale"]
	var wsz: Array = cfg["world"]
	var lines: Array = []
	lines.append("Nests: " + (str(int(cfg["colonies"])) if bool(cfg.get("tell_colonies", true)) else "Unknown"))
	lines.append("Food piles: " + (str(int(cfg["food_piles"])) if bool(cfg.get("tell_food", true)) else "Unknown"))
	lines.append("Ant speed: %d-%d%%" % [int(round(float(sp[0]) * 100.0)), int(round(float(sp[1]) * 100.0))])
	var world_txt: String = "Unknown"
	if bool(cfg.get("tell_world", true)):
		world_txt = "%d%% x %d%%" % [int(round(float(wsz[0]) * 100.0)), int(round(float(wsz[1]) * 100.0))]
	lines.append("World size: " + world_txt)
	lines.append("Let through at most: %d crumbs" % int(cfg["allowance"]))
	lines.append("Hold out for: %d s" % int(cfg["time_sec"]))
	return "\n".join(lines)

func _stock_up(cfg: Dictionary) -> void:
	stock.clear()
	stock_at_start.clear()
	var have: Array = cfg.get("stock", [])
	for i in AntObstacle.KINDS.size():
		var n: int = int(have[i]) if i < have.size() else 0
		stock[int(AntObstacle.KINDS[i])] = n
		# Kept so a tool can show how much of its supply is left as a LEVEL and not only a count --
		# the jug does, the way the spray can does.
		stock_at_start[int(AntObstacle.KINDS[i])] = n

func stock_of(kind: int) -> int:
	return int(stock.get(kind, 0))

func _build_world(cfg: Dictionary) -> void:
	var w: Array = cfg["world"]
	# A SCREENFUL, and a screenful is not square. The height unit used to be the canvas WIDTH for
	# both axes, which made every world square by accident of one constant -- and on a phone, whose
	# canvas is 680x1200, that left about 420 units of perfectly good ground unused below the
	# colony. One unit of height is the usable band: the canvas less the HUD above and the button
	# bar below, which is what the camera already clamps to.
	world = Rect2(Vector2.ZERO, Vector2(float(w[0]) * SCREEN_UNITS, float(w[1]) * screen_units_h()))
	walkable = world.grow(-AntsArt.WALL_W)

func screen_units_h() -> float:
	# The WALL is part of what has to fit. It is drawn inside the world rect, so the world's own
	# edge is the wall's outer face -- set the world flush to the band and the border ends up
	# touching the button bar, which is the thing it was drawn to be clearly separate from.
	# Reserving it on both sides leaves a wall's width of clear ground either end.
	var band: float = float(MainGlobals.full_screen_size.y) - float(MainGlobals.header_height) \
		- bottom_bar_units() - AntsArt.WALL_W * 2.0
	# Before init_globals has run there is no screen to measure; fall back to the desktop band.
	return band if band > 100.0 else 670.0

# The app's bottom button bar is TALLER than MainGlobals.footer_height reserves -- 70 units on a
# phone and 44 on a desktop, against a footer of 40 -- so a band measured from the footer puts the
# world's bottom edge under the buttons, by 30 units on a phone and 4 on a desktop.
#
# couples/scripts/level.gd and change/scripts/level.gd each carry this same pair of numbers for the
# same reason. Three copies is enough to want it somewhere shared; that is the user's call, not one
# to make while passing through.
func bottom_bar_units() -> float:
	return 70.0 if MainGlobals.is_mobile() else 44.0

func _place_colonies(cfg: Dictionary) -> void:
	colonies.clear()
	_all.clear()
	var n: int = int(cfg["colonies"])
	var sp: Array = cfg["speed_scale"]
	# WHICH KINDS OF COLONY THIS LEVEL MAY HAVE. An empty list means all of them; anything else is
	# the allow-list. Dealt ROUND-ROBIN rather than rolled per colony, so a level that names two
	# kinds actually gets both -- rolling twice from a list of two comes up the same about half the
	# time, and a player cannot learn to tell two colonies apart when there is only one kind on the
	# board. The list is shuffled first so which NEST is which kind still varies between runs.
	var kinds: Array = []
	for v in (cfg.get("behaviors", []) as Array):
		kinds.append(clampi(int(v), 0, Ant.BEHAVIORS.size() - 1))
	if kinds.is_empty():
		for k in Ant.BEHAVIORS.size():
			kinds.append(k)
	kinds.shuffle()
	for i in n:
		var at: Vector2 = _nest_position(i, n)
		var c: AntColony = AntColony.new(at, i, COLONY_TINTS[i % COLONY_TINTS.size()])
		c.behavior = int(kinds[i % kinds.size()])
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

func _food_position(_i: int, n: int) -> Vector2:
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
	if _pan_accum != Vector2.ZERO and _can_pan:
		_cam.position -= _pan_accum / _zoom
		_pan_accum = Vector2.ZERO
		_clamp_cam()
	var dt: float = minf(delta, 0.05)
	sim_step(dt)
	_refresh_layers(dt)

# Split out so a headless probe can run the colony forward without a display or a clock.
# The corridor a road can form in: the straight run from each nest to each pile, sampled every
# ROAD_STEP. It is not where the ants WILL go -- they wander, and they go round whatever you put
# down -- but a road that carries crumbs has to get from one end to the other, so it passes near
# this line somewhere.
# Pools shrink the whole time they are down and then go. Handled here rather than in the ant loop
# because it changes the SET of obstacles, which _resolid() and the drawing both cache.
func _dry_water(dt: float) -> void:
	var gone: bool = false
	for i in range(obstacles.size() - 1, -1, -1):
		if obstacles[i].dry(dt):
			obstacles.remove_at(i)
			gone = true
	if gone:
		_resolid()
		_redraw_all()

func _build_road_samples() -> void:
	_road_pts.clear()
	_road_armed.clear()
	for c: AntColony in colonies:
		for f: Dictionary in food:
			var a: Vector2 = c.nest
			var b: Vector2 = f["pos"]
			var n: int = maxi(1, int(a.distance_to(b) / ROAD_STEP))
			for i in range(1, n):
				_road_pts.append({"p": a.lerp(b, float(i) / float(n)), "c": c})
				_road_armed.append(true)

# One road maturing is one trial onset. A point fires when its scent crosses ROAD_ON and cannot
# fire again until it has fallen back under ROAD_OFF -- hysteresis, because a route hovering at a
# single threshold would emit a trial every tick and the distribution would be noise.
# TIMED ON THE LEVEL'S OWN CLOCK, not on the wall.
#
# `_clock` only advances inside sim_step, which only runs while the game is playing -- so a player
# who opens the tool menu, reads a tooltip or takes a phone call in the middle of a road forming is
# not charged for it. A wall clock would file all of that as a slow reaction. It also makes the
# measurement independent of frame rate, which is what let a probe stepping the simulation by hand
# record every reaction as 0 ms.
func _watch_roads() -> void:
	var now: float = _clock
	for i in _road_pts.size():
		var pt: Dictionary = _road_pts[i]
		var v: float = (pt["c"] as AntColony).marks.sense(pt["p"])
		if bool(_road_armed[i]):
			if v >= ROAD_ON:
				_road_armed[i] = false
				_road_pending.append({"pos": pt["p"], "at": now, "seen": -1.0})
				road_onsets += 1
		elif v <= ROAD_OFF:
			_road_armed[i] = true
	# THE CLOCK STARTS WHEN THE ROAD IS VISIBLE, NOT WHEN IT MATURES.
	#
	# From level 3 the world is larger than the screen and the camera does not zoom out, so a road
	# can form somewhere the player is not looking. Timing that from maturation measures where the
	# camera happened to be pointing, not how quickly the player noticed anything -- the same
	# player, panning in a moment later, would post a "slow reaction" to something they could not
	# have seen. So each road waits for its first frame ON SCREEN, and the reaction is measured
	# from there. On level 1, where the whole world is in view, the two are the same thing.
	#
	# What that leaves out is worth its own number: a road that matured off-screen and never came
	# into view at all is `roads_unseen` -- not a slow response, but board the player never covered.
	var view: Rect2 = visible_world()
	for e in _road_pending:
		if float(e["seen"]) < 0.0 and view.has_point(e["pos"]):
			e["seen"] = now
	for k in range(_road_pending.size() - 1, -1, -1):
		if now - float(_road_pending[k]["at"]) > ROAD_WINDOW:
			if float(_road_pending[k]["seen"]) < 0.0:
				roads_unseen += 1
			else:
				roads_missed += 1
			_road_pending.remove_at(k)

# The player acted at `at`. Any road within reach of it counts as answered.
func _answer_roads(at: Vector2) -> void:
	for k in range(_road_pending.size() - 1, -1, -1):
		if (_road_pending[k]["pos"] as Vector2).distance_to(at) <= ROAD_NEAR:
			# Acting on it proves it was visible, so a road answered before _watch_roads had a
			# chance to mark it seen is timed from now -- which is a reaction of zero, and rare.
			var seen: float = float(_road_pending[k]["seen"])
			if seen < 0.0:
				seen = _clock
			road_times_ms.append(int(round(maxf(_clock - seen, 0.0) * 1000.0)))
			_road_pending.remove_at(k)

# Was anything actually using this spot? A stone dropped on empty ground costs a tool and changes
# nothing, and telling those from useful placements is most of what separates acting from acting
# usefully.
func _traffic_at(at: Vector2) -> bool:
	for c: AntColony in colonies:
		if c.marks.sense(at) >= ROAD_OFF:
			return true
	# Tighter than ROAD_NEAR: answering a road is about the road's neighbourhood, but "was anything
	# walking HERE" is about the spot. On a busy level a wandering ant is within 90 units of almost
	# anywhere, which would make nothing ever count as wasted.
	for a: Ant in _all:
		if a.pos.distance_to(at) <= 55.0:
			return true
	return false

func sim_step(dt: float) -> void:
	_clock += dt
	_dry_water(dt)
	if game.playing:
		_watch_roads()
	var came_up: int = 0
	for c: AntColony in colonies:
		came_up += c.release_due(_clock)
	if came_up > 0:
		_rebuild_all()
	_smell_food()
	for c: AntColony in colonies:
		for a: Ant in c.ants:
			a.step(dt, c.marks, walkable, _solid, spray)
	_resolve_contacts(dt)
	_resolve_obstacles(dt)
	_resolve_sites()
	_evap_accum += dt
	var period: float = 1.0 / EVAPORATE_HZ
	while _evap_accum >= period:
		_evap_accum -= period
		for c: AntColony in colonies:
			c.marks.evaporate(EVAPORATE_DECAY)
		spray.fade()

# Nothing may be left standing inside a stone. The antennae (see Ant._edge_turn) keep an ant from
# walking in, but a shallow clip is always possible, so this is the backstop. Rate-limited like
# every other correction here: a full-size teleport out of a twig would be the same jumpiness the
# separation pass was fixed for.
func _resolve_obstacles(dt: float) -> void:
	if obstacles.is_empty():
		return
	var cap: float = push_rate * dt
	for a: Ant in _all:
		for o: AntObstacle in obstacles:
			if not o.solid() or not o.contains(a.pos):
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
	var angle: float = rot
	if is_inf(rot):
		angle = randf_range(-PI, PI)
		# A twig is 152 units long and 18 wide, so its angle is nearly all of what it does -- and
		# dropped at random it lands parallel to the trail as often as across it, doing nothing at
		# all. A tap says where, and where is enough to work out which way: it goes across whatever
		# road is under it.
		if AntObstacle.SHAPE[kind][0].x > AntObstacle.SHAPE[kind][0].y * 2.0:
			angle = trail_axis(at) + PI * 0.5
	var o: AntObstacle = AntObstacle.new(kind, at, angle, randi())
	if not _spot_ok(o):
		# Tapping the SIDE of something you have already put down is a perfectly reasonable thing
		# to mean "another one, here". It used to do nothing at all: the menu closed, the stock was
		# untouched, and no obstacle appeared, with no way for the player to tell why. So a drop
		# that is blocked by another obstacle slides outward until it clears, ALONG THE LINE FROM
		# THAT OBSTACLE'S CENTRE THROUGH THE TAP -- which puts it against the side that was tapped,
		# where the player was pointing.
		var block: AntObstacle = _blocking(o)
		# Only an overlap slides. A drop refused for sitting on a nest or a pile stays refused:
		# sliding it would put an obstacle somewhere the player never indicated.
		if block == null or not _slide_clear(o, at, block):
			return false
	obstacles.append(o)
	if game.playing:
		if _traffic_at(at):
			_answer_roads(at)
		else:
			placements_wasted += 1
	_resolid()
	stock[kind] = stock_of(kind) - 1
	game.tutorial_notify("obstacle_placed")
	if kind == AntObstacle.Kind.LURE:
		game.tutorial_notify("bait_placed")

	# Ants standing where it lands are crushed. That is the whole reason a tally exists: dropping
	# something on a busy trail cannot be free.
	for c: AntColony in colonies:
		var survivors: Array[Ant] = []
		for a: Ant in c.ants:
			if o.contains(a.pos):
				c.killed += 1
				# Where it died and which way it faced -- it is drawn as an ordinary ant in red.
				corpses.append({"pos": a.pos, "heading": a.heading})
				if game.playing:
					game.add_score_and_time(-KILL_PENALTY, 0, true)
			else:
				survivors.append(a)
		c.ants = survivors
		# The scent under it is under it.
		c.marks.erase_if(func(p: Vector2) -> bool: return o.contains(p))
	_rebuild_all()
	_redraw_all()
	return true

# Every reason a spot can be unusable, in one place, so the slide below can ask the same question
# of each position it tries.
# Which way the road under a point runs. Sampled as an AXIS rather than a direction -- a trail has
# no preferred end -- by scoring each bearing against the scent a little way along it and a little
# way back. Falls back to the line from the nearest nest to the nearest pile, which is the road the
# colony is going to want even if it has not worn one yet.
const AXIS_RAYS: int = 12
const AXIS_REACH: float = 34.0

func trail_axis(at: Vector2) -> float:
	var best: float = -1.0
	var best_a: float = 0.0
	for i in AXIS_RAYS:
		var a: float = PI * float(i) / float(AXIS_RAYS)
		var d: Vector2 = Vector2.from_angle(a) * AXIS_REACH
		var score: float = 0.0
		for c: AntColony in colonies:
			score += c.marks.sense(at + d) + c.marks.sense(at - d)
		if score > best:
			best = score
			best_a = a
	if best > 0.5:
		return best_a
	# No road here yet: use the one they are bound to want.
	var from: Vector2 = at
	var to: Vector2 = at + Vector2.RIGHT
	if not colonies.is_empty():
		from = colonies[0].nest
		for c: AntColony in colonies:
			if c.nest.distance_to(at) < from.distance_to(at):
				from = c.nest
	if not food.is_empty():
		to = food[0]["pos"]
		for f: Dictionary in food:
			if (f["pos"] as Vector2).distance_to(at) < to.distance_to(at):
				to = f["pos"]
	if from.distance_to(to) < 1.0:
		return randf_range(-PI, PI)
	return (to - from).angle()

func _spot_ok(o: AntObstacle) -> bool:
	# Walkable, not world: the wall is not ground, so nothing may be dropped into it.
	if not walkable.has_point(o.pos):
		return false
	# THE SHAPE, NOT ITS BOUNDING CIRCLE. This used to compare the distance from the nest to the
	# obstacle's CENTRE against bound_radius(), which is the longest half-extent -- so a twig, 152
	# units end to end, carried a 100-unit exclusion circle round every nest and pile whichever way
	# it pointed. Laid neatly across a road with both ends pointing away from a nest it was still
	# refused, and nothing on screen explained why: the rule was reading a number the player cannot
	# see instead of the outline they can.
	#
	# contains_margin() grows the real outline by the clearance wanted, so orientation counts. A
	# twig side-on to a nest now fits; one pointing into it still does not.
	for c: AntColony in colonies:
		if o.contains_margin(c.nest, AntColony.NEST_RADIUS):
			return false
	for f: Dictionary in food:
		if o.contains_margin(f["pos"] as Vector2, FOOD_RADIUS):
			return false
	# Two of these may not share ground: the combined shape would have an outline that is neither
	# one's outline, and edge following reads exactly that outline to get round.
	if o.solid():
		for other: AntObstacle in _solid:
			if o.overlaps(other):
				return false
	return true

# The obstacle in the way, nearest first when several are.
func _blocking(o: AntObstacle) -> AntObstacle:
	var best: AntObstacle = null
	var best_d: float = INF
	for other: AntObstacle in _solid:
		if o.overlaps(other):
			var d: float = o.pos.distance_to(other.pos)
			if d < best_d:
				best_d = d
				best = other
	return best

# Walk it out until it fits, keeping its angle. Steps are small so it comes to rest ADJACENT to
# what blocked it rather than a shape's width away.
func _slide_clear(o: AntObstacle, toward: Vector2, block: AntObstacle) -> bool:
	var dir: Vector2 = toward - block.pos
	if dir.length_squared() < 0.01:
		# Tapped dead centre, so the tap says nothing about a direction. Off the obstacle's own
		# seed, so the same tap always puts it in the same place instead of somewhere new each try.
		dir = Vector2.from_angle(float(o.seed_val % 628) * 0.01)
	dir = dir.normalized()
	var limit: float = (o.bound_radius() + block.bound_radius()) * 1.6
	var start: Vector2 = o.pos
	var moved: float = 0.0
	while moved <= limit:
		moved += 3.0
		o.pos = start + dir * moved
		if _spot_ok(o):
			return true
	o.pos = start
	return false

# Picked back up, and returned to the stock. Gives the kind that was taken, or -1.
# One press of the can, at a point. Returns false when the can is empty.
func use_spray(at: Vector2) -> bool:
	if spray_left <= 0 or not walkable.has_point(at):
		return false
	spray_left -= 1
	if game.playing:
		_answer_roads(at)
	spray.spray(at)
	game.tutorial_notify("sprayed")
	_redraw_all()
	return true

func remove_obstacle_at(at: Vector2) -> int:
	for i in range(obstacles.size() - 1, -1, -1):
		if obstacles[i].contains(at):
			var kind: int = obstacles[i].kind
			obstacles.remove_at(i)
			# Picking something up to use it elsewhere is the action the whole game runs on, and
			# the one the tutorial says nobody discovers unaided. A player who never does it has
			# four decisions rather than four tools.
			if game.playing:
				obstacles_moved += 1
			_resolid()
			# Only what can be carried away comes back. Water poured out is gone.
			if AntObstacle.is_reusable(kind):
				stock[kind] = stock_of(kind) + 1
			_redraw_all()
			game.tutorial_notify("obstacle_removed")
			return kind
	return -1

func obstacle_at(at: Vector2) -> bool:
	for o: AntObstacle in obstacles:
		if o.contains(at):
			return true
	return false

func _resolid() -> void:
	_solid.clear()
	for o: AntObstacle in obstacles:
		if o.solid():
			_solid.append(o)


func _rebuild_all() -> void:
	_all.clear()
	for c: AntColony in colonies:
		_all.append_array(c.ants)

func ants_killed() -> int:
	var n: int = 0
	for c: AntColony in colonies:
		n += c.killed
	return n

# The two tools that touch the colony's memory rather than its path. Run on the evaporation tick
# rather than every frame, because both are field work and the field only moves at that rate.
# Bait is food, so nothing here has to persuade the ants of anything: they find it, recruit to it,
# and carry it away by exactly the machinery they use on a real pile. What it costs the colony is
# trips; what it costs the player is nothing.

# Bait, taken like anything else. Spent bait is gone -- it was eaten, so it does not come back to
# the stock and it does not sit there as an empty plate.
func _try_bait(a: Ant) -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var o: AntObstacle = obstacles[i]
		if o.kind != AntObstacle.Kind.LURE or o.crumbs <= 0:
			continue
		if not o.contains(a.head_pos()):
			continue
		o.crumbs -= 1
		a.pick_up_food()
		a.carrying_bait = true
		if o.crumbs <= 0:
			obstacles.remove_at(i)
			_resolid()
			_redraw_all()
		return

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
		# Bait smells like food because it IS food. Nothing here tells the ant it is a trick.
		for o: AntObstacle in obstacles:
			if o.kind != AntObstacle.Kind.LURE or o.crumbs <= 0:
				continue
			var d3: float = a.pos.distance_squared_to(o.pos)
			if d3 < best:
				best = d3
				a.smelled_food = o.pos
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
	var d2_max: float = contact_d * contact_d
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
			var half: Vector2 = off / dist * ((contact_d - dist) * 0.5)
			push[i] -= half
			push[j] += half
			if a.contact_cd <= 0.0 and b.contact_cd <= 0.0 \
					and a.stop_timer <= 0.0 and b.stop_timer <= 0.0 \
					and cos(a.heading - b.heading) < OPPOSITE_DOT:
				# The cooldown is not decoration. Without it a busy trail is a standing crowd:
				# every pair re-greets the moment the last greeting ends, and nothing moves again.
				a.greet()
				b.greet()
	var cap: float = push_rate * dt
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
					var off: Vector2 = a.head_pos() - (f["pos"] as Vector2)
					# Against the pile's REAL lobed edge at the ant's own bearing, and against its
					# current size -- the same two functions that draw it. A crumb can only be taken
					# from where a crumb can be seen.
					var rr: float = AntsArt.pile_radius(FOOD_RADIUS,
						float(f["crumbs"]) / maxf(float(f["start"]), 1.0))
					if off.length() <= AntsArt.pile_edge(rr, off.angle(), int(f["seed"])):
						f["crumbs"] = int(f["crumbs"]) - 1
						a.pick_up_food()
						a.carrying_bait = false
						break
				if a.state == Ant.State.SEARCHING:
					_try_bait(a)
			elif c.at_hole(a.head_pos()):
				var was_bait: bool = a.carrying_bait
				a.drop_food()
				a.carrying_bait = false
				c.delivered += 1
				delivered += 1
				if was_bait:
					game.tutorial_notify("bait_taken")
					# Food the player was never defending. The trip is spent either way, which is
					# the whole point of bait -- but the allowance is untouched.
					bait_taken += 1
					continue
				crumbs_through += 1
				game.tutorial_notify("crumb_through")
				# Down, not up: the score IS the allowance, and this eats it. At zero the colony has
				# had what it came for and game_over_on_zero_score ends the round -- after which the
				# colony may go on eating but the player is no longer being charged for it.
				if game.playing:
					game.add_score_and_time(-1, 0, true)
	if _is_finished():
		# Every crumb in the world is in the nest. The colony has taken the lot, which is the
		# player's loss however much allowance happens to be left.
		_running = false
		sig_level_is_done.emit(false)

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
	# NOT a fit. The camera used to shrink the world until it fitted the screen, stopping only at a
	# legibility floor -- so the big levels silently drew every ant smaller instead of letting the
	# player move around a full-size world. The zoom is the level's own `cam_zoom_out`, which is
	# 1.0 everywhere: an ant is drawn at its true size and anything larger than the screen is
	# panned. Level 1 is sized so that nothing has to be.
	var out: float = float(AntsLevelConfig.get_level(current_level_id).get("cam_zoom_out", 1.0))
	_zoom = 1.0 / maxf(out, 0.01)
	var span: Vector2 = get_viewport_rect().size / _zoom
	_can_pan = world.size.x > span.x + 1.0 or world.size.y > span.y + 1.0
	_cam.zoom = Vector2(_zoom, _zoom)
	_cam.position = colonies[0].nest if (_can_pan and colonies.size() > 0) else world.get_center()
	_clamp_cam()
	_cam.enabled = true
	_cam.make_current()

const PAN_OVERSHOOT: float = 20.0
const TRAIL_HZ: float = 12.0

# The camera may travel until each edge of the world reaches the edge of the USABLE band -- which
# is the viewport less the HUD at the top and the button bar at the bottom, not the raw viewport.
# Clamping against the raw viewport is why the top wall could never be seen above level 1: the
# camera stopped with the world's top edge at screen y = 0, underneath the HUD.
func _clamp_cam() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var top_ui: float = float(MainGlobals.header_height)
	var bot_ui: float = bottom_bar_units()
	# Camera positions that put each world edge exactly at the edge of the usable band. Computed
	# WITHOUT the overshoot, because this pair is also the test for whether the world is big enough
	# to pan at all -- fold the overshoot in first and a world that only just fits gains a spurious
	# range to slide about in, which is how level 1 ended up able to tuck its top edge under the HUD.
	var lo: Vector2 = Vector2(
		world.position.x + vp.x * 0.5 / _zoom,
		world.position.y + (vp.y * 0.5 - top_ui) / _zoom)
	var hi: Vector2 = Vector2(
		world.position.x + world.size.x - vp.x * 0.5 / _zoom,
		world.position.y + world.size.y - (vp.y * 0.5 - bot_ui) / _zoom)
	# A world too small to fill the band is centred IN THE BAND, not in the viewport, so it sits
	# clear of the HUD rather than partly behind it.
	var mid: Vector2 = world.get_center()
	mid.y -= (top_ui - bot_ui) * 0.5 / _zoom
	# The overshoot applies only where there is genuinely somewhere to pan. A world that exactly
	# fills the band has lo == hi: no range at all, and handing it 20 units either way let it drift
	# its top edge back under the HUD -- which is precisely what happened the moment a world's
	# height became the band's height rather than the canvas width.
	var over: float = PAN_OVERSHOOT / _zoom
	var p: Vector2 = _cam.position
	p.x = clampf(p.x, lo.x - over, hi.x + over) if lo.x < hi.x else mid.x
	p.y = clampf(p.y, lo.y - over, hi.y + over) if lo.y < hi.y else mid.y
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
			if _press_index == -2:
				_begin_press(st.position, st.index)
		elif st.index == _press_index:
			_end_press()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _press_index == -2:
					_begin_press(mb.position, -1)
			elif _press_index == -1:
				_end_press()
		return

	var moved: Vector2 = Vector2.ZERO
	var here: Vector2 = Vector2.ZERO
	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index != _press_index:
			return
		moved = sd.relative
		here = sd.position
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _press_index != -1 or (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		moved = mm.relative
		here = mm.position
	else:
		return
	# Measured against the EVENT's own position. It used to ask the viewport for the mouse
	# position, which on a touch screen is not where the finger is -- so on a phone the test that
	# decides tap-or-pan was reading a number with nothing to do with the gesture.
	if not _dragged and _press_at.distance_to(here) < TAP_SLOP:
		return
	_dragged = true
	if _can_pan:
		_pan_accum += moved

func _begin_press(at: Vector2, idx: int) -> void:
	_press_at = at
	_press_world = _screen_to_world(at)
	_press_index = idx
	_pan_accum = Vector2.ZERO
	_dragged = false

func _end_press() -> void:
	_press_index = -2
	if _dragged or MainGlobals.popup_open or Time.get_ticks_msec() < _tap_dead_until:
		return
	_open_obstacle_menu(_press_at, _press_world)

func _screen_to_world(at: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * at

func _close_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		# Told it is over BEFORE it is freed. queue_free defers the teardown to the end of the
		# frame, and during that teardown Godot emits mouse_exited for whichever cell the pointer
		# was over -- which calls the menu's hide_tip lambda, whose captured tip and connector line
		# are by then freed ("Lambda capture at index 1 was freed"). The menu also sets this from
		# its own tree_exiting, but that is emitted during the teardown rather than now, so a menu
		# closed from out here would be told too late.
		if _menu.has_meta("acted"):
			(_menu.get_meta("acted") as Array)[0] = true
		_menu.queue_free()
		MainGlobals.set_popup_open(false)
	_menu = null

func _open_obstacle_menu(screen_at: Vector2, world_at: Vector2) -> void:
	_close_menu()
	var here: Vector2 = world_at
	game.tutorial_notify("menu_opened")
	_menu = ObstacleMenu.open(self, screen_at,
		func(kind: int, is_remove: bool) -> void:
			if is_remove:
				remove_obstacle_at(here)
			elif kind == SPRAY_PICK:
				# One squirt where the menu was opened, exactly like every other tool. A "spray
				# mode" was tried and thrown away: it had no way out, and a tool you cannot put
				# down needs a real inventory to live in, not a popup.
				use_spray(here)
			else:
				place_obstacle(kind, here),
		obstacle_at(world_at), self,
		func() -> void: game.tutorial_notify("tip_shown"))
	if _menu != null:
		# Armed whenever the menu goes, however it went -- a choice, or a tap outside it. The press
		# that dismisses one is followed by a RELEASE, and without this that release lands on the
		# world and opens a fresh menu at the very spot the player was dismissing to.
		_menu.tree_exited.connect(func() -> void:
			_tap_dead_until = Time.get_ticks_msec() + int(TAP_DEADTIME * 1000.0))

# --- drawing ----------------------------------------------------------------

func _redraw_all() -> void:
	if _bg != null:
		_bg.queue_redraw()
		_trail_layer.queue_redraw()
		_fg.queue_redraw()

# Which layers are stale this frame. The ants always; the trail a dozen times a second; the ground
# only once the camera has moved far enough to be looking past what was drawn for it.
func _refresh_layers(dt: float) -> void:
	_fg.queue_redraw()
	_trail_accum += dt
	if _trail_accum >= 1.0 / TRAIL_HZ:
		_trail_accum = 0.0
		_trail_layer.queue_redraw()

func _draw_bg() -> void:
	if colonies.is_empty():
		return
	AntsArt.draw_ground(_bg, world, _zoom, _art_seed)
	AntsArt.draw_border(_bg, world, AntsArt.WALL_W)

func _draw_trail() -> void:
	var vis: Rect2 = visible_world().grow(40.0)
	for c: AntColony in colonies:
		AntsArt.draw_marks(_trail_layer, c.marks.marks_in(vis), _zoom)
	AntsArt.draw_spray(_trail_layer, spray.marks_in(vis), _zoom)


func _draw_fg() -> void:
	if colonies.is_empty():
		return
	var vis: Rect2 = visible_world()
	for f: Dictionary in food:
		var p: Vector2 = f["pos"]
		if vis.has_point(p):
			AntsArt.draw_food(self._fg, p, FOOD_RADIUS,
				float(f["crumbs"]) / maxf(float(f["start"]), 1.0), int(f["seed"]))
	for o: AntObstacle in obstacles:
		if vis.intersects(Rect2(o.pos - Vector2.ONE * o.bound_radius(),
				Vector2.ONE * o.bound_radius() * 2.0)):
			AntsArt.draw_obstacle(_fg, o)
	# On top of whatever crushed them, and under anything still walking.
	for cp: Dictionary in corpses:
		if vis.has_point(cp["pos"]):
			AntsArt.draw_dead_ant(_fg, cp["pos"], cp["heading"])
	for c: AntColony in colonies:
		if vis.has_point(c.nest):
			AntsArt.draw_nest(_fg, c.nest, AntColony.NEST_RADIUS, c.tint)
	for a: Ant in _all:
		if vis.has_point(a.pos):
			AntsArt.draw_ant(_fg, a, _zoom)

# --- reporting (probe / design; nothing here is written to the player's record) ---

# Ants out of the nest and working. Not the same as the colony's size while it is still turning
# out -- see population().
func ant_count() -> int:
	return _all.size()

func population() -> int:
	var n: int = 0
	for c: AntColony in colonies:
		n += c.population()
	return n

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
			if contact_d - d > worst:
				worst = contact_d - d
	return worst

# For the probe: how far the worst-placed ant is inside something solid.
func worst_intrusion() -> float:
	var worst: float = 0.0
	for a: Ant in _all:
		# Solid ones only. An ant standing in a fan or a lure is not an intrusion, it is the point.
		for o: AntObstacle in _solid:
			if o.contains(a.pos):
				worst = maxf(worst, (o.push_out(a.pos, 0.0) - a.pos).length())
	return worst

# How near the world's edge the closest ant has got -- measured to the WORLD, not the walkable
# area, so it answers the question the wall makes: does anything ever stand on the border?
func closest_to_edge() -> float:
	var nearest: float = INF
	for a: Ant in _all:
		nearest = minf(nearest, minf(
			minf(a.pos.x - world.position.x, world.position.x + world.size.x - a.pos.x),
			minf(a.pos.y - world.position.y, world.position.y + world.size.y - a.pos.y)))
	return nearest

func all_inside_world() -> bool:
	for a: Ant in _all:
		if not walkable.grow(1.0).has_point(a.pos):
			return false
	return true
