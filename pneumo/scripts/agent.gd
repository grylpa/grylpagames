extends Area2D

# signal hit(id)
signal remove_agent(id)
signal agent_pressed(_transaction_id, _board_pos)
signal sig_agent_started_moving(_transaction_id)
# A leg is done and the next is due NOW (see _process): the level hands it out at once instead of on
# its 50 ms tick.
signal sig_leg_done

var board_pos: Vector2i
var direction: int
var target_position: Vector2
var starting_position: Vector2
var time_from_start_to_target_ms: int = 0
var set_target_once: bool = false
var arrived: bool = false
var was_hit: bool = false
var agent_type: int = 1
var agent_id: int = 0
var last_major_tick_ms: int = -10000
var speed_scale: float = 1.0
var is_moving: bool = false
var transaction_id: int = -1
var time_created_ms: int = 0

var nbody_parts = 0
var bodies = []
var time_back_positions = []
var back_total_len = 0
var body_dist = 34
var head_dist = 34
var tail_dist_back = body_dist
var angles = []
var body_ids = [1,2,3]
var body_scene: PackedScene = load("res://pneumo/scenes/tube_animation.tscn")

var color
var isready = false

var game:GenericGameUtil

func _ready() -> void:
	game = PneumoG.game
	# color = game.next_color()
	set_type(agent_type)
	$Head.set_modulate(color)
	$Head.rotation = PI/2
	$Head.play("HeadEyes")
	$Head.speed_scale = 0.5
	$Skeleton.modulate = color.darkened(0.1)
	$Skeleton.add_point(Vector2.ZERO)
	angles.append(0)
	angles.append(0)
	nbody_parts = body_ids.size()
	tail_dist_back = body_dist * nbody_parts + head_dist
	# Starts BEHIND the gates and rises above them once it has left the mouth (see _rise_above).
	z_index = Z_IN_GATE
	# z_index is RELATIVE here, so a child's effective z is the agent's plus its own. The
	# head keeps the 1 the scene gives it (effective 91 in the gate), which is what keeps it
	# under the dispatchers at 100. The skeleton used to be set to z_index-10, i.e. 80
	# relative -- effective 170, straight over the head and over the dispatchers. It has to
	# be NEGATIVE to sit under the train without lifting anything else.
	$Skeleton.z_index = -20
	# var dsc = (1.0 - 0.4) / nbody_parts
	for i in nbody_parts:
		var body = body_scene.instantiate()
		var anim = body.get_node("animation")
		body.mouse_click.connect(_on_body_input_event)
		anim.play("main")
		# Stagger each tube a third of a cycle apart, as the old 3-frame animation did with
		# (i+2)%3. The sheet is 24 frames now, so a third of it is 8.
		anim.frame = ((i+2) % 3) * 8
		# anim.speed_scale = 1.0 - dsc * (i + 1)
		anim.speed_scale = 0.5
		body.modulate = color
		# Relative, like the head: -(i+1) puts tube i just behind the head (effective 89, 88,
		# ...) and still above the skeleton. The old z_index-i-1 was 89 RELATIVE, i.e.
		# effective 179, which drew the tubes over the dispatchers at 100.
		body.z_index = -(i+1)
		add_child(body)
		bodies.append(body)
		body.hide()
		angles.append(0)
		PneumoCapsuleArt.attach(body, anim, false)
	# the drawn canisters (capsule_art.gd): the lead capsule's own, with its nose
	PneumoCapsuleArt.attach($Head, $Head, true)
	$Skeleton.width = 3.0
	isready = true
	time_created_ms = MainGlobals.timems()

func set_id(_id):
	agent_id = _id

func set_color(_color):
	color = _color
	$Head.set_modulate(color)
	$Skeleton.modulate = color.darkened(0.1)
	for body in bodies:
		body.modulate = color

func set_type(_agent_type):
	agent_type = _agent_type
	var coloridx = agent_type-1
	# the color tells the speed band; the bands follow the speeds' range (0.8 .. 2.2 since 2026-11-12,
	# when the top speed came down from 4.0 -- they were 1.8 and 2.6, and the third color would never show)
	if speed_scale < 1.3:
		coloridx = 0
	elif speed_scale < 1.75:
		coloridx = 1
	else:
		coloridx = 2
	color = game.color_by_index(coloridx)
	set_color(color)
	
# THE WHOLE CAPSULE EXISTS FROM THE START, coiled back inside its dispatcher (2026-11-12, after Detour):
# the trail is laid straight back through the dispatcher at spawn (seed_in_dock), so every tube has its
# place and heading from the first move and slides out in turn; a tube still behind the dispatcher's
# center waits there, hidden. Before, a tube only appeared once the capsule had moved far enough to lay
# a trail for it -- a gap, then the tube popping in with its link. The waiting stops for good once the
# whole capsule has come out (_out_of_dock): "behind" is measured across the dispatcher's whole edge
# line, and a capsule going into a receiver on the same edge would otherwise count as back inside.
var _dock_center: Vector2 = Vector2.INF
var _out_dir: Vector2 = Vector2.ZERO
var _out_of_dock: bool = false

func seed_in_dock(dock_px: Vector2, out_dir: Vector2) -> void:
	_dock_center = dock_px
	_out_dir = out_dir
	var back: float = float(tail_dist_back) * 1.5 + float(game.tile_size)
	time_back_positions = [position - out_dir * back, position]
	back_total_len = back

# EACH TUBE STAYS UNDER THE DISPATCHER UNTIL IT HAS ITSELF PASSED ITS MOUTH: the capsule rises above the
# gates once the HEAD is clear (_rise_above_gate_once_clear), which lifted the tubes still in the mouth
# over the dispatcher too. A tube in the mouth keeps an effective z under the gates' 100.
func _hide_in_dock() -> void:
	# BACKING UP, its last tube leads it home: the tubes go back INTO the dispatcher and must hide there
	# all the while (they used to be re-hidden only once the head was back at the mouth, by when the
	# leading tubes had driven out through the dispatcher and past the board's edge)
	if (_out_of_dock and not reversed) or _dock_center == Vector2.INF or bodies.is_empty():
		return
	var tile: float = float(game.tile_size)
	if not reversed and (position + (bodies[-1] as Node2D).position - _dock_center).dot(_out_dir) > tile * 0.9:
		_out_of_dock = true
		for i in bodies.size():
			bodies[i].z_index = -(i + 1)
			bodies[i].modulate.a = 1.0
		return
	var parked: Vector2 = _dock_center - position
	var mouth: float = tile * 0.5
	# the mouth's edge on the capsule's axis, local: the link line starts here, never inside
	var lip: Vector2 = _dock_center + _out_dir * mouth - position
	for i in bodies.size():
		var depth: float = (position + (bodies[i] as Node2D).position - _dock_center).dot(_out_dir)
		var inside: bool = depth < 0.0
		bodies[i].visible = not inside      # the tube's drawing follows its carrier's visibility
		# in the mouth (center .. a half tile out, and a tube's half length more): under the gate
		var in_mouth: bool = depth < mouth + float(body_dist) * 0.5
		bodies[i].z_index = (Z_IN_GATE - z_index - (i + 1)) if in_mouth else -(i + 1)
		# AND FADED IN across the mouth: once the capsule is thrown, its dispatcher fades to 40%
		# (level.activate_transaction), and a tube under it showed straight through, a ghost on the
		# chevrons with its link across them (the level 9 run, 2026-11-12)
		var a: float = clampf(depth / mouth, 0.0, 1.0)
		bodies[i].modulate.a = a * a * (3.0 - 2.0 * a)
		if inside:
			bodies[i].position = parked
		if depth < mouth and i + 1 < $Skeleton.get_point_count():
			$Skeleton.set_point_position(i + 1, lip)

func set_pos(p, dir):
	direction = dir
	_spawn_pos = p
	_emerged = false
	angles[0] = dir * PI/2
	if not _head_angle_set:
		# The heading a capsule is BORN with is not a turn — face that way at once, or it swings
		# into place in full view the moment it appears.
		_head_angle = angles[0]
		_head_angle_set = true
	set_rots()
	if !isready:
		return
	position = p
			
var time_set_target_pos = MainGlobals.timems()

# --- One arc through the door ------------------------------------------------------------------
#
# The capsule runs dead straight — horizontal or vertical, never anything else — right up to
# `TURN_RADIUS` short of the door's center, takes ONE quarter-arc through the door tile, and leaves
# straight along the new axis. The leg deliberately ENDS past the door center, at the far end of
# the arc, so the next leg is a plain axis-aligned run to the next tile center.
#
# Two earlier attempts are worth remembering, because both looked wrong in ways the numbers did
# not show at first:
#   1. Curving the WHOLE leg (control point a tile away) took the capsule off the straight run
#      entirely and set it oscillating.
#   2. Rounding each joint of the level's own three-leg turn — it used to aim at a point offset a
#      quarter tile DIAGONALLY inside the door — gave three small arcs curving alternate ways: a
#      harsh turn, a correction back, then another. The offsets are gone from level.gd now, which
#      is what makes a single arc possible.
#
# The level says a turn is coming (`turn_dir`) when it sets the target, one tick BEFORE the capsule
# reaches the door, because an arc has to begin before the corner.
# Of a tile, the arc's reach either side of the door's center. At 1.0 the turn is a single quarter
# circle from one tile center to the next, which is as wide as the geometry allows: it passes
# 0.414 tiles from the door's center (a circular arc of radius R clears the corner it rounds by
# 0.414 R), so a capsule swings around the flap rather than over it, and two capsules turning at
# the same door from opposite sides keep about 0.83 tiles between their paths.
const TURN_RADIUS_FRAC: float = 1.0

# The arc is deliberately split across the TWO legs of the turn — into the door and out of it —
# rather than crammed into one. Each leg then carries half of it and is the same length as the
# other, so the capsule holds one speed all the way round. Packed into a single leg (the first
# attempt at this) the leg into the door was 1.49 tiles and the one out of it 0.15, both given a
# tick apiece: the capsule sprinted through the turn and then crawled.
#
# A CIRCLE, not a Bezier: constant curvature is what makes the whole thing read as one movement.
# A quadratic Bezier bends hardest in its middle — the "harsh, then correcting" look — and passes
# closer to the corner (0.354 R) for the same reach.
var _arc_center: Vector2 = Vector2.ZERO
var _arc_from: Vector2 = Vector2.ZERO    # the arc's start, relative to its center
var _arc_sweep: float = 0.0              # +/- PI/2 for the whole turn; each leg takes half
var _arc_a: Vector2 = Vector2.ZERO       # where the straight run ends and the arc begins
var _arc_frac: float = 0.0               # share of THIS leg spent on the straight part
var _arc_half: int = 0                   # 0 = no arc, 1 = first half of one, 2 = second half
var _legs_done: int = 0                  # how many targets this capsule has been given

# --- Bouncing off a wrong receiver ----------------------------------------------------------
#
# A capsule that arrives somewhere it cannot go is sent back the way it came. Turning round on the
# spot read as a mistake rather than as an impact, so it now takes the hit: it COMPRESSES along the
# axis it was traveling, holds for an instant, then springs back out and leaves in the other
# direction. The squash is drawn only — `direction` has already been reversed by the level, and the
# level's tick keeps its own time.
const BOUNCE_SQUASH: float = 0.55        # how far it compresses, as a share of its length
const BOUNCE_BULGE: float = 0.5          # how much of that it gives back across the axis

var _bounce_ms: float = -1.0
var _bounce_axis: Vector2 = Vector2.RIGHT
var _bounce_last_ms: float = 0.0

# THE BOUNCE IS AN ELASTIC CHAIN (2026-11-12). The capsule runs on until its NOSE meets the face it hit
# (the cell's edge), and from there it is a small simulation along the track (_sim_step): the head and
# each tube are equal masses joined by springs at their usual spacing, all coming on at the capsule's
# speed; the head stops against the face and rebounds, the compression runs down the chain -- each tube
# decelerating into the one in front and squashing by how compressed its springs are -- and the chain
# springs back out, the last tube leading as it backs away. Nothing turns and nothing passes through
# anything. A first version was a fixed timeline (each tube slid in at constant speed and stopped dead,
# the head held a third of a second) and did not look natural.
# The head holds the level's clock while the chain is in the air (_process), and the backing-up leg the
# level has already set is started fresh when the simulation ends.
# TWO KINDS OF SPRING (2026-11-12, "more compressed -- you don't compress the links"). The LINKS are soft
# (SPRING_K): the chain closes up until the tubes TOUCH end to end, every link gone. The TUBES are firm
# but squishy (CONTACT_K): past touching a part is squashed only by how far it is pressed into its
# neighbor (or into the face), so the ends stay together. Squashing a tube by its springs' compression,
# as before, shortened it while its center closed up only a quarter of the spacing, so the gaps -- the
# links -- came out no shorter than at rest. (Stiffer still, at 2600, the chain was a rigid rod.)
const SPRING_K: float = 500.0            # the links, per unit mass
const SPRING_DAMP: float = 5.0
const CONTACT_K: float = 4000.0          # a tube pressed into its neighbor or the face
const CONTACT_DAMP: float = 14.0
const SIM_MIN_SPEED: float = 260.0       # px per second: the slowest impact the chain is given
const MIN_ALONG: float = 0.6             # the most a part is squashed along its length
const SIM_MAX_MS: float = 900.0
const POST_RELAX_MS: float = 160.0       # leftover spacing eases back to normal after
var _sim_on: bool = false
var _sim_s: PackedFloat32Array = PackedFloat32Array()   # positions along the track, + toward the face
var _sim_v: PackedFloat32Array = PackedFloat32Array()
var _sim_rest: PackedFloat32Array = PackedFloat32Array()
var _sim_wall: float = 0.0
var _sim_t: float = 0.0
var _sim_head_at: float = 0.0           # how far the head has been moved along the track so far
var _sim_dir: Vector2 = Vector2.RIGHT
var _post_off: PackedFloat32Array = PackedFloat32Array()
var _post_ms: float = -1.0

# Called by the level the moment it turns a capsule back (and only when it starts backing up).
func start_bounce(axis: Vector2) -> void:
	_sim_dir = axis.normalized() if axis != Vector2.ZERO else Vector2.RIGHT
	# the face: the cell's edge ahead of the cell the head is in, less the nose
	var cell_c: Vector2 = game.board_to_px(board_pos)
	var wall: float = (cell_c + _sim_dir * float(game.tile_size) * 0.5 - position).dot(_sim_dir) \
		- PneumoCapsuleArt.LEN
	_start_sim(1.0, maxf(0.0, wall))

# BACKING UP INTO ITS OWN DISPATCHER IT BOUNCES OFF ITS EDGE (2026-11-12): its last tube leads, so that is
# what meets the dispatcher's face, and the wave runs the other way, tail to head; then it goes forward
# again (the level turns it round: level.gd, tail_at_sender). It used to slide into the dispatcher.
# How far the leading part (the last tube, or the head with none) still has to go to meet the
# dispatcher's face, along the way it is backing; INF when it is not on the dispatcher's line.
func room_to_sender() -> float:
	if _dock_center == Vector2.INF:
		return INF
	var lead: Vector2 = position + ((bodies[-1] as Node2D).position if not bodies.is_empty() else Vector2.ZERO)
	var face: Vector2 = _dock_center + _out_dir * float(game.tile_size) * 0.5
	var rel: Vector2 = lead - face
	if absf(rel.cross(_out_dir)) > float(game.tile_size) * 0.5:
		return INF
	return rel.dot(_out_dir) - PneumoCapsuleArt.LEN

func start_tail_bounce() -> void:
	var lead_d: float = _tube_dist(bodies.size()) if not bodies.is_empty() else 0.0
	_sim_dir = -_out_dir                      # the way it is backing, toward the face
	_start_sim(-1.0, lead_d + maxf(0.0, room_to_sender()))

# THE ELASTIC CHAIN, either way round. Positions run along the track, + toward the face. `sign` +1: the
# face is ahead of the HEAD (it hit something going forward) and the head leads, s_0 > s_1 > ...; -1: the
# face is ahead of the LAST TUBE (it backed into its dispatcher), s_n > ... > s_0. The part at the face is
# index 0 or n.
var _sim_sign: float = 1.0

func _start_sim(sign_v: float, wall: float) -> void:
	_bounce_ms = MainGlobals.timems()
	_bounce_last_ms = _bounce_ms
	_sim_sign = sign_v
	var n: int = bodies.size()
	var leg_ms: float = maxf(1.0, game.major_tick_time_ms * game.time_scale / speed_scale)
	var v0: float = maxf(SIM_MIN_SPEED, float(game.tile_size) / leg_ms * 1000.0)   # px per second
	_sim_s.resize(n + 1)
	_sim_v.resize(n + 1)
	_sim_rest.resize(n + 1)
	_sim_s[0] = 0.0
	_sim_v[0] = v0
	_sim_rest[0] = 0.0
	for i in range(1, n + 1):
		_sim_rest[i] = float(head_dist) if i == 1 else float(body_dist)
		_sim_s[i] = -sign_v * _tube_dist(i)          # where the tubes are now
		_sim_v[i] = v0
	_sim_wall = wall
	_sim_t = 0.0
	_sim_head_at = 0.0
	_sim_on = true
	_post_ms = -1.0

func _gap(i: int) -> float:              # the spring between parts i-1 and i, its current length
	return _sim_sign * (_sim_s[i - 1] - _sim_s[i])

# One frame of the elastic chain, in small steps; then the head moved along the track, the tubes placed
# at the simulated distances, and every part squashed by its springs' compression.
func _sim_step(delta: float) -> void:
	var n: int = _sim_s.size()
	var w: int = 0 if _sim_sign > 0.0 else n - 1        # the part at the face
	var left: float = minf(delta, 0.05)
	while left > 0.0:
		var h: float = minf(left, 0.002)
		left -= h
		var acc: PackedFloat32Array = PackedFloat32Array()
		acc.resize(n)
		var touch: float = 2.0 * PneumoCapsuleArt.LEN
		for i in range(1, n):
			var g: float = _gap(i)
			var rv: float = _sim_sign * (_sim_v[i - 1] - _sim_v[i])
			var f: float = SPRING_K * (g - _sim_rest[i]) + SPRING_DAMP * rv      # < 0 pushes apart
			if g < touch:
				f -= CONTACT_K * (touch - g) - CONTACT_DAMP * rv
			acc[i - 1] -= _sim_sign * f
			acc[i] += _sim_sign * f
		# the face: the part at it is pressed into it
		var pen: float = _sim_s[w] - _sim_wall
		if pen > 0.0:
			acc[w] -= CONTACT_K * pen + CONTACT_DAMP * maxf(0.0, _sim_v[w])
		for i in n:
			_sim_v[i] += acc[i] * h
			_sim_s[i] += _sim_v[i] * h
	_sim_t += delta * 1000.0
	# the head along the track. Head at the face: forward (laying trail) up to it, back along its own
	# trail after. Tail at the face: + is the way it backs, so the reverse.
	var ds: float = (_sim_s[0] - _sim_head_at) * _sim_sign
	if ds > 0.0:
		# forward: toward the face, or (tail at the face) the way the head points
		position += (_sim_dir if _sim_sign > 0.0 else Vector2.from_angle(_head_angle)) * ds
		time_back_positions.push_back(position)
		if time_back_positions.size() > 1:
			back_total_len += (time_back_positions[-1] - time_back_positions[-2]).length()
	elif ds < 0.0:
		_retreat(-ds)
	_sim_head_at = _sim_s[0]
	# squash: each part by how far it is pressed into what it touches (its neighbors, the face)
	var touch_l: float = 2.0 * PneumoCapsuleArt.LEN
	for i in n:
		var p_in: float = 0.0
		if i >= 1:
			p_in = maxf(p_in, touch_l - _gap(i))
		if i + 1 < n:
			p_in = maxf(p_in, touch_l - _gap(i + 1))
		if i == w:
			p_in = maxf(p_in, 2.0 * (_sim_s[w] - _sim_wall))
		var along: float = maxf(MIN_ALONG, 1.0 - maxf(0.0, p_in) / touch_l)
		_set_squash(i, (1.0 - along) / (1.0 - BOUNCE_SQUASH))
	_place_tubes()
	# done once every part is moving away from the face and the spacing has settled, or after SIM_MAX_MS
	var all_back: bool = true
	var settled: bool = true
	for i in n:
		if _sim_v[i] >= 0.0:
			all_back = false
		if i >= 1 and absf(_gap(i) - _sim_rest[i]) > 3.0:
			settled = false
	if (all_back and settled and _sim_s[w] < _sim_wall - 1.0) or _sim_t > SIM_MAX_MS:
		_end_sim()

func _end_sim() -> void:
	_sim_on = false
	_bounce_ms = -1.0
	var n: int = _sim_s.size()
	# leftover spacing eases back to normal (_tube_dist)
	_post_off.resize(n)
	for i in range(1, n):
		_post_off[i] = _sim_sign * (_sim_s[0] - _sim_s[i]) - _nominal_dist(i)
	_post_ms = float(MainGlobals.timems())
	for i in n:
		_set_squash(i, 0.0)
	# the leg the level set at the bounce starts now, from where the head is
	if reversed:
		_rev_len = _trail_dist_to(target_position)
		_rev_done = 0.0
	else:
		# planned again from where the head is NOW: planned at the bounce, its curve through a door
		# started from where the head stood then and steered it off its line for a moment
		_arc_half = 0
		_legs_done = maxi(0, _legs_done - 1)
		set_target_once = false             # so _leg_start_ms does not backdate it
		set_target_pos(target_position, _last_turn_dir)
	time_set_target_pos = MainGlobals.timems()
	last_major_tick_ms = time_set_target_pos
	_leg_done_sent = false
	# the rebound can carry the head PAST the leg's target: that leg is then done, and the next is asked
	# for at once from where the head is (driven back to the target it turned round to face it, and
	# turned round again for the leg after)
	if not reversed and (target_position - position).dot(Vector2.from_angle(_head_angle)) <= 0.5:
		target_position = position
		starting_position = position
		var leg: int = int(time_from_start_to_target_ms * game.time_scale / speed_scale)
		time_set_target_pos = MainGlobals.timems() - leg - 1
		last_major_tick_ms = time_set_target_pos

# A part is squashed in its OWN frame: it is rotated to point along the track, so local x is always the
# axis of the impact (compress x, bulge y). The squash is on the parts, never the agent: scaling the agent
# scales every child's position too and telescoped the whole train toward the head. (Choosing the axis
# from a WORLD vector once compressed 382 of 435 frames across the tube instead of along it.)
func _set_squash(i: int, amt: float) -> void:
	var along: float = 1.0 - (1.0 - BOUNCE_SQUASH) * amt
	var across: float = 1.0 + (1.0 - BOUNCE_SQUASH) * amt * BOUNCE_BULGE
	if i == 0:
		$Head.scale = Vector2(along, across)
		return
	var b: Node2D = bodies[i - 1]
	if not b.has_meta("base_scale"):
		b.set_meta("base_scale", b.scale)
	var base: Vector2 = b.get_meta("base_scale")
	b.scale = Vector2(base.x * along, base.y * across)

func _nominal_dist(i: int) -> float:      # tube i is 1-based here: 1 = the one behind the head
	return float((i - 1) * body_dist + head_dist)

# Tube i's distance from the head along the track right now (1-based).
func _tube_dist(i: int) -> float:
	if _sim_on and i < _sim_s.size():
		return _sim_sign * (_sim_s[0] - _sim_s[i])
	var nominal: float = _nominal_dist(i)
	if _post_ms >= 0.0 and i < _post_off.size():
		var u: float = clampf((MainGlobals.timems() - _post_ms) / POST_RELAX_MS, 0.0, 1.0)
		if u >= 1.0:
			return nominal
		return nominal + _post_off[i] * (1.0 - u * u * (3.0 - 2.0 * u))
	return nominal

# A capsule's FIRST leg is the one place there is not enough room: it starts at a cell center, so a
# door directly in front leaves exactly one tile of run-up, and an arc needs a full radius of that
# before the door's center. At the full tile it would curve from the instant it appeared; at 0.75
# it runs a quarter tile straight out of the gate first and still clears the door's center by 0.31
# tiles, against 0.41 on an ordinary turn.
const FIRST_LEG_RADIUS_FRAC: float = 0.75

# Gates (senders and receivers) are drawn at z 100. A capsule waiting in a gate's mouth sits BELOW
# them so it looks like it is coming from inside; once it is clear of the mouth it rises above, so
# that arriving at a receiver — and bouncing off the wrong one — happens in plain view.
const Z_IN_GATE: int = 90
const Z_ON_BOARD: int = 110
# A capsule is dispatched a whole tile clear of its gate, so only its tail overlaps: a third of a
# tile of travel is enough to be free of the sprite. Any longer and it stays behind the gate after
# it has visibly left, which is what "most of it is hidden" looked like.
const EMERGED_FRAC: float = 0.33

var _spawn_pos: Vector2 = Vector2.ZERO
var _emerged: bool = false

# NO TURN AT A BOUNCE (2026-11-12): "when hitting a place that demands turning back there shouldn't be
# a 180 turn -- some elastic reaction, a compression/decompression/bounce". The capsule bounces off the
# face elastically (start_bounce, _sim_step: a compression wave down the chain) and BACKS UP: the level
# sends it back through the cells it came by (`cells`, level.gd), its nose still to the wall and its last
# tube leading, every part sliding back along the very trail it laid (_retreat), so nothing turns and
# nothing passes through anything. It used to turn the head round at the deepest point of the squash,
# and each tube then ran on to the wall, spun 180 degrees in a frame and came back through the tubes
# still arriving. Backing up into its own dispatcher, its tubes slide back in (hidden there all the
# while, _hide_in_dock) and it comes out forward again.
var reversed: bool = false
var cells: Array[Vector2i] = []
var _rev_len: float = 0.0          # trail length this backing-up leg covers
var _rev_done: float = 0.0         # and has covered so far
const TRAIL_KEEP_PX: float = 4000.0  # trail kept beyond the capsule's length, to back up along

func back_at_dispatcher() -> void:
	_out_of_dock = false

# The trail distance from the head back to the trail's nearest point to `p` (a cell center), within
# a couple of tiles.
func _trail_dist_to(p: Vector2) -> float:
	var best: float = INF
	var best_s: float = 0.0
	var s_acc: float = 0.0
	var b: Vector2 = position
	if b.distance_to(p) < best:
		best = b.distance_to(p)
	for i in range(time_back_positions.size() - 1, -1, -1):
		var a: Vector2 = time_back_positions[i]
		s_acc += a.distance_to(b)
		b = a
		var d: float = a.distance_to(p)
		if d < best:
			best = d
			best_s = s_acc
		if s_acc > float(game.tile_size) * 2.5:
			break
	return best_s

# Moves the head `dist` back along its own trail, dropping the samples it passes.
func _retreat(dist: float) -> void:
	var left: float = dist
	while left > 0.0 and time_back_positions.size() > 2:
		var a: Vector2 = time_back_positions[-1]
		var seg: float = position.distance_to(a)
		if seg <= left:
			position = a
			left -= seg
			back_total_len -= (time_back_positions[-1] - time_back_positions[-2]).length()
			time_back_positions.pop_back()
		else:
			position = position.move_toward(a, left)
			left = 0.0


# NO STOP BETWEEN TILES (2026-11-12, "the whole capsule chain moves in jumps" at level 9). The level
# hands out legs on a 50 ms tick, so a capsule that finished one between two ticks stood still until
# the next -- at 4x speed a leg is ~150 ms, and a quarter of the time was spent standing: stop, go, stop.
# Now a finished leg asks for the next at once (sig_leg_done), and the new leg's clock is backdated to
# when the old one was due to end -- by at most one frame, so a capsule that was legitimately waiting
# is never thrown forward (Delemfp's MAX_LEG_CATCHUP_MS lesson).
const MAX_LEG_CATCHUP_MS: int = 17
var _leg_done_sent: bool = false

func _leg_start_ms() -> int:
	var now_ms: int = MainGlobals.timems()
	_leg_done_sent = false
	if not set_target_once:
		return now_ms
	var due: int = time_set_target_pos + int(time_from_start_to_target_ms * game.time_scale / speed_scale)
	var start: int = now_ms - clampi(now_ms - due, 0, MAX_LEG_CATCHUP_MS)
	# the level's own cadence for this capsule follows the leg, not the tick that handed it out
	last_major_tick_ms = start
	return start

var _last_turn_dir: int = -1

func set_target_pos(p, turn_dir: int = -1):
	_last_turn_dir = turn_dir
	if reversed:
		# backing up: along the trail to its nearest point to p, no arcs of its own
		_arc_half = 0
		_arc_frac = 0.0
		_rev_len = _trail_dist_to(p)
		_rev_done = 0.0
		_legs_done += 1
		target_position = p
		starting_position = position
		time_set_target_pos = _leg_start_ms()
		time_from_start_to_target_ms = game.major_tick_time_ms
		set_target_once = true
		time_created_ms = MainGlobals.timems()
		return
	if _arc_half == 1:
		# Second half of a turn already under way: finish the arc, then run straight at whatever
		# the level has just asked for. The capsule is standing at the arc's midpoint.
		_legs_done += 1
		_arc_half = 2
		_arc_from = position - _arc_center
		var radius: float = _arc_from.length()
		var half_len: float = absf(_arc_sweep) * 0.5 * radius
		# The straight run afterwards is measured from where the ARC ENDS, not from where the
		# capsule is standing now. Measuring it from here counted the arc's own chord as straight
		# line as well, so the capsule finished the turn half way through the leg and then stood
		# still for the rest of it.
		var arc_end: Vector2 = _arc_center + _arc_from.rotated(_arc_sweep * 0.5)
		var out_len: float = arc_end.distance_to(p)
		_arc_frac = half_len / maxf(half_len + out_len, 0.001)
		target_position = p
		starting_position = position
		time_set_target_pos = _leg_start_ms()
		time_from_start_to_target_ms = game.major_tick_time_ms
		set_target_once = true
		time_created_ms = MainGlobals.timems()
		return
	_arc_half = 0
	_arc_frac = 0.0
	var u_in: Vector2 = (p - position).normalized()
	if turn_dir >= 0 and u_in != Vector2.ZERO:
		var u_out: Vector2 = Vector2(game.DirArray[turn_dir]).normalized()
		# A right angle and nothing else: this is the only shape a door makes.
		if u_out != Vector2.ZERO and absf(u_in.dot(u_out)) < 0.01:
			# The radius is CAPPED by the run-up actually available, not demanded of it. A capsule
			# halts a fraction short of each target — legs measure about 39.3 px against a 40 px
			# tile — so a guard that insisted on a full tile of run-up refused to plan any arc at
			# all, and those capsules went straight over the door and turned on the spot. That is
			# what a capsule bounced back off a wrong receiver did on its way back through the
			# door it came in by.
			var leg_len: float = position.distance_to(p)
			var frac: float = FIRST_LEG_RADIUS_FRAC if _legs_done == 0 else TURN_RADIUS_FRAC
			var r: float = minf(game.tile_size * frac, leg_len)
			if r >= game.tile_size * 0.2:
				_arc_a = p - u_in * r
				_arc_center = _arc_a + u_out * r
				_arc_from = _arc_a - _arc_center
				_arc_sweep = (PI * 0.5) * signf(u_in.cross(u_out))
				_arc_half = 1
				# This leg is: straight run, then the FIRST half of the arc. Time is split by
				# length so the speed does not change at the joint.
				var straight_len: float = position.distance_to(_arc_a)
				var half_len: float = r * PI * 0.25
				_arc_frac = straight_len / maxf(straight_len + half_len, 0.001)
				# It ends at the arc's midpoint; the next leg picks the arc up from there.
				p = _arc_center + _arc_from.rotated(_arc_sweep * 0.5)
	_legs_done += 1
	target_position = p
	starting_position = position
	time_set_target_pos = _leg_start_ms()
	time_from_start_to_target_ms = game.major_tick_time_ms
	set_target_once = true
	time_created_ms = MainGlobals.timems()

# Held still by the coach for a step that is about something ELSE — the doors. Behaves exactly
# like a pause for this capsule: every clock is suspended, so nothing ages while it waits.
var tutorial_hold: bool = false
var _last_process_ms: int = MainGlobals.timems()

func _process(delta: float) -> void:
	# Both clocks in here are the WALL clock: the auto-start delay and the tile-to-tile
	# interpolation. Neither stops when the game pauses, so a capsule kept gliding through a help
	# screen, a popup or a tutorial caption. Pushing both baselines forward by the paused (or held)
	# duration suspends it exactly where it is and resumes it without a jump.
	var now_ms: int = MainGlobals.timems()
	if tutorial_hold or (game != null and game.paused()):
		var paused_for: int = now_ms - _last_process_ms
		time_created_ms += paused_for
		time_set_target_pos += paused_for
		_last_process_ms = now_ms
		return
	_last_process_ms = now_ms
	if _sim_on:
		# the elastic chain (_sim_step): the level's clock is held while it runs, and the head keeps
		# its heading -- it never turns round
		time_set_target_pos += now_ms - _bounce_last_ms
		last_major_tick_ms += int(now_ms - _bounce_last_ms)
		_bounce_last_ms = now_ms
		$Head.rotation = _head_angle
		_sim_step(delta)
		if _sim_on:
			return
	_bounce_last_ms = now_ms
	_rise_above_gate_once_clear()
	_ease_head_angle(delta)
	$Head.rotation = _head_angle
	if MainGlobals.timems() - time_created_ms > game.time_to_auto_start_moving_ms:
		is_moving = true
		sig_agent_started_moving.emit(transaction_id)
	if set_target_once and is_moving and not was_hit and not arrived and not _leg_done_sent \
			and _dock_legs.is_empty() and MainGlobals.timems() - time_set_target_pos \
			> time_from_start_to_target_ms * game.time_scale / speed_scale:
		# the leg ran out: the next is handed over HERE, before this frame's move, so the frame does
		# not stand still (sig_leg_done -> level.tick() -> set_target_pos, synchronously)
		_leg_done_sent = true
		sig_leg_done.emit()
	if set_target_once and is_moving:
		var dv = target_position - starting_position
		var now = MainGlobals.timems()
		var dt = now - time_set_target_pos
		var should_halt = dt > time_from_start_to_target_ms * game.time_scale / speed_scale or was_hit
		if !should_halt:
			var sf = dt / float(time_from_start_to_target_ms * game.time_scale / speed_scale)
			var v = dv * sf
			var last = position
			if _arc_half == 1:
				if sf < _arc_frac:
					# Straight in, along the axis, up to where the arc begins.
					position = starting_position.lerp(_arc_a, sf / _arc_frac)
				else:
					# First half of the sweep, ending at the arc's midpoint.
					var t1: float = (sf - _arc_frac) / maxf(1.0 - _arc_frac, 0.001)
					position = _arc_center + _arc_from.rotated(_arc_sweep * 0.5 * t1)
			elif _arc_half == 2:
				if sf < _arc_frac:
					# Second half of the sweep, out of the turn.
					var t2: float = sf / maxf(_arc_frac, 0.001)
					position = _arc_center + _arc_from.rotated(_arc_sweep * 0.5 * t2)
				else:
					# Straight out along the new axis.
					var arc_end: Vector2 = _arc_center + _arc_from.rotated(_arc_sweep * 0.5)
					position = arc_end.lerp(target_position,
						(sf - _arc_frac) / maxf(1.0 - _arc_frac, 0.001))
			elif not reversed:
				position = starting_position + v
			if reversed:
				var want: float = _rev_len * sf
				_retreat(want - _rev_done)
				_rev_done = want
				# the nose stays to the wall: it faces AGAINST the way it moves
				if last.distance_to(position) > 0.01:
					angles[0] = last.angle_to_point(position) + PI
			elif last.distance_to(position) > 0.01:
				# (a frame with no movement -- the first after a bounce -- has no heading: angle_to_point
				# of a point to itself is 0, which turned the head toward the right and back)
				angles[0] = last.angle_to_point(position)
			if not reversed and Vector2i(target_position) != Vector2i(starting_position):
				time_back_positions.push_back(position)   # raw: rounding the trail to whole pixels
				# makes the segment lengths alternate and the tubes wobble half a pixel a frame
				# Only count a segment when one was actually appended. Adding this every frame
				# inflated the running total on frames with no new sample, which over-trimmed
				# the trail from the front and made the followers lurch.
				if time_back_positions.size() > 1:
					back_total_len += (time_back_positions[-1] - time_back_positions[-2]).length()
			# drop the oldest stretch only while enough trail remains for the whole capsule (the long
			# seeded stretch back into the dispatcher must not go in one piece while tubes still need it)
			# the trail is kept long (TRAIL_KEEP_PX past the capsule) so a bounced capsule can back up
			# along it; only beyond that is the oldest stretch dropped
			while time_back_positions.size() > 2 and back_total_len \
					- (time_back_positions[1] - time_back_positions[0]).length() > tail_dist_back * 1.5 + TRAIL_KEEP_PX:
				back_total_len -= (time_back_positions[1] - time_back_positions[0]).length()
				time_back_positions.pop_front()
			_place_tubes()
		elif not was_hit and not _dock_legs.is_empty():
			position = target_position
			_next_dock_leg()

	if not _dock_in.is_empty():
		_fade_into_dock()

# Every tube on the trail behind the head (packing up through a bounce, _tube_dist), then the dispatcher's
# mouth (_hide_in_dock) and the turn (set_rots).
func _place_tubes() -> void:
	for i in bodies.size():
		var trail_pos = pos_back_along_trail(_tube_dist(i + 1))
		if trail_pos != null:
			bodies[i].position = trail_pos - position
			bodies[i].show()
			while $Skeleton.get_point_count() < i+2:
				$Skeleton.add_point(Vector2.ZERO)
			$Skeleton.set_point_position(i+1, bodies[i].position)
			angles[i+1] = $Skeleton.get_point_position(i+1).angle_to_point($Skeleton.get_point_position(i))
	_hide_in_dock()
	set_rots()

# Returns the point exactly `dist` back along the recorded trail, interpolating inside the segment
# it lands in, or null when the trail is not yet that long.
#
# This used to return the index of the first sample at least `dist` back and the caller parked the
# tube on that sample, so between index steps the sample stood still while the capsule drove on and
# then jumped a whole sample forward -- a sawtooth as large as the distance covered in a frame.
func pos_back_along_trail(dist):
	if time_back_positions.is_empty():
		return null
	# Measure from where the head is RIGHT NOW, not from the newest recorded sample. A sample is
	# only appended when the tile target changes, so on the frames in between the newest sample is
	# stale and every follower comes out at the wrong offset, snapping back the next frame. That
	# showed up as the lead tube's gap breathing between 33.5 and 34.0 px while the head advanced
	# smoothly -- a sub-pixel jerk backwards every few frames.
	var sum: float = 0.0
	var b: Vector2 = position
	for i in range(time_back_positions.size()-1, -1, -1):
		var a: Vector2 = time_back_positions[i]
		var seg: float = (a - b).length()
		if sum + seg >= dist:
			var t: float = 0.0 if seg <= 0.0001 else (dist - sum) / seg
			return b.lerp(a, t)
		sum += seg
		b = a
	return null
			
func set_rots():
	$Head.rotation = _head_angle if _head_angle_set else angles[0]
	var step: float = TURN_SPEED * get_process_delta_time()
	for i in nbody_parts:
		var b: Node2D = bodies[i]
		var target: float = angles[i+1]
		# a tube that has just come into view takes its heading; after that it turns at TURN_SPEED
		if not b.visible or not b.has_meta("turned"):
			b.rotation = target
			if b.visible:
				b.set_meta("turned", true)
		else:
			b.rotation += clampf(wrapf(target - b.rotation, -PI, PI), -step, step)
	
func add_body(_id):
	pass
	
func remove_body_if_first(id):
	var idx = body_ids.find(id)
	return remove_body(id) if idx == 0 else false
		
var _pending_remove_ids: Dictionary = {}
func remove_body(id):
	if id in _pending_remove_ids:
		return
	_pending_remove_ids[id] = true
	var idx = body_ids.find(id)
	if idx >= 0:
		var body = bodies[idx]
		var tween_color = MainGlobals.make_tween()
		tween_color.tween_property(body, "modulate", color.darkened(0.4), 0.45)
		var tween_scale = MainGlobals.make_tween()
		var oldscale = body.scale
		tween_scale.tween_property(body, "scale", oldscale * 2, 0.2)
		tween_scale.tween_property(body, "scale", Vector2(0.0,0.0), 0.3)
		tween_scale.tween_callback(func(): final_remove_body(id))
		return true
	return false
		
func final_remove_body(id):
	var idx = body_ids.find(id)
	if idx >= 0:
		nbody_parts -= 1
		body_ids.remove_at(idx)
		var body = bodies[idx]
		for iidx in range(bodies.size()-1, idx, -1):
			bodies[iidx].position = bodies[iidx-1].position
			bodies[iidx].rotation = bodies[iidx-1].rotation
		bodies.remove_at(idx)
		if $Skeleton.get_point_count() > 0:
			$Skeleton.remove_point($Skeleton.get_point_count()-1)
		tail_dist_back = body_dist * nbody_parts + head_dist
		angles.pop_back()
		body.queue_free()		
		set_rots()
		_pending_remove_ids.erase(id)
		return true
	return false

# INTO THE DOCK, NOT FADED IN PLACE (2026-11-12, as in Valet): on arriving -- its head in the cell
# before its dock -- the capsule goes on at twice its speed to the center of the cell it is in and then
# straight into the dock and on; every part follows the trail as always, and each fades (and shrinks
# a little) only as it crosses the dock's mouth, the line joining the parts cut off there too. It is
# removed once its last part is in. It used to stop dead and shrink and fade where it stood. An arrived
# capsule is never counted in a crash.
const DOCK_SPEED_K: float = 2.0
var _dock_in: Dictionary = {}     # {mouth, dir, depth} (parent coords)
var _dock_legs: Array = []        # the points still to drive to
var _dock_base: Dictionary = {}   # each part's own scale before the drive-in

func drive_into_dock(cell_px: Vector2, dock_px: Vector2) -> void:
	arrived = true
	var tile: float = float(game.tile_size)
	var dirv: Vector2 = (dock_px - cell_px).normalized()
	_dock_in = {"mouth": dock_px - dirv * tile * 0.5, "dir": dirv, "depth": tile * 0.5}
	_dock_legs = []
	if position.distance_to(cell_px) > 1.0:
		_dock_legs.append(cell_px)
	# far enough past the mouth that the last part is in too
	_dock_legs.append(dock_px + dirv * (tail_dist_back + tile * 0.5))
	_next_dock_leg()

func _next_dock_leg() -> void:
	var to: Vector2 = _dock_legs.pop_front()
	var tile: float = float(game.tile_size)
	set_target_pos(to)
	# set_target_pos times a leg as one tile; this one is as long as it is, at DOCK_SPEED_K
	time_from_start_to_target_ms = maxi(1, int(float(game.major_tick_time_ms) * position.distance_to(to) / tile / DOCK_SPEED_K))

# A part's share of the way through the dock's mouth (0 outside .. 1 at the dock's center).
func _dock_depth(local_p: Vector2) -> float:
	var gp: Vector2 = position + local_p
	return clampf((gp - (_dock_in["mouth"] as Vector2)).dot(_dock_in["dir"]) / float(_dock_in["depth"]), 0.0, 1.0)

func _dock_parts() -> Array:
	return [$Head] + bodies

func _fade_into_dock() -> void:
	var parts: Array = _dock_parts()
	for part in parts:
		if part == null or not is_instance_valid(part):
			continue
		var n: Node2D = part as Node2D
		if not _dock_base.has(n):
			_dock_base[n] = n.scale
		var k: float = _dock_depth(n.position)
		n.modulate.a = 1.0 - k
		n.scale = (_dock_base[n] as Vector2) * (1.0 - 0.35 * k)
	# the joining line ends at the dock's center: none runs on past the parts that have gone
	var dirv: Vector2 = _dock_in["dir"]
	for i in $Skeleton.get_point_count():
		var lp: Vector2 = $Skeleton.get_point_position(i)
		var over: float = (position + lp - (_dock_in["mouth"] as Vector2)).dot(dirv) - float(_dock_in["depth"])
		if over > 0.0:
			$Skeleton.set_point_position(i, lp - dirv * over)
	var last: Node2D = parts[-1] as Node2D
	if _dock_legs.is_empty() and (last == null or _dock_depth(last.position) >= 1.0):
		_dock_in = {}
		remove_agent.emit(agent_id)

func mark_hit():
	# set_color(Color(0,0,0))
	was_hit = true
	var node_to_shake = $Head
	var tween_color = MainGlobals.make_tween()
	# tween_color.tween_property(self, "modulate", Color(1,1,1,0.4), 0.65)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.8), 0.3)
	tween_color.tween_property(self, "modulate", Color(0.7,0.7,0.7,0.2), 0.3)
	var tween_scale = MainGlobals.make_tween()
	var oldscale = node_to_shake.scale
	tween_scale.tween_property(node_to_shake, "scale", oldscale * 3.0, 0.3)
	oldscale = scale
	tween_scale.tween_property(self, "scale", oldscale * 0.1, 0.6)
	tween_scale.tween_callback(func(): remove_agent.emit(agent_id))

func distance_to_point(p):
	var d = (position - p).length()
	for body in bodies:
		d = min(d, (position + body.position).distance_to(p))
	return d

func distance_to(a):
	var d = a.distance_to_point(position)
	for body in bodies:
		d = min(d, a.distance_to_point(position + body.position))
	return d

func set_major_tick_now():
	last_major_tick_ms = MainGlobals.timems()

func need_to_major_tick():
	var t = MainGlobals.timems()
	return t - last_major_tick_ms >= game.major_tick_time_ms * game.time_scale / speed_scale and is_moving

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("lclick"):
		agent_pressed.emit(transaction_id, board_pos)

func _on_body_input_event() -> void:
	agent_pressed.emit(transaction_id, board_pos)

# --- Turning ---------------------------------------------------------------------------------
#
# `angles[0]` is the LOGICAL heading, recomputed every frame from the direction of travel — and at
# a corner the direction of travel changes between one frame and the next, so drawing the head
# straight off it made the capsule snap round. `_head_angle` is what the head is DRAWN at: it
# chases the logical heading instead of matching it, so a corner reads as a turn.
#
# Taxi does the same thing with a 0.12 s tween in `set_rot`, which works there because the heading
# only changes when the taxi is told to turn. Here it is re-derived every frame, and restarting a
# tween every frame means it never arrives — so this eases per frame instead. The body segments are
# unaffected: they trail off `angles`, not off this.
# A CONSTANT angular speed, not a proportional ease: taxi tweens its head over a fixed 0.12 s, and
# matching that here means the swing looks the same in both games and can never exceed this rate,
# however long a frame runs.
# A right angle in 0.12 s at most -- the head's rate, and since 2026-11-12 every tube's too (set_rots):
# a tube's angle came straight off the trail and could snap.
const TURN_SPEED: float = PI * 0.5 / 0.12

var _head_angle: float = 0.0
var _head_angle_set: bool = false

func _ease_head_angle(delta: float) -> void:
	if not _head_angle_set:
		# First heading of this capsule's life: face that way, do not spin into it.
		_head_angle = angles[0]
		_head_angle_set = true
		return
	# Shortest way round, so a right turn from "up" does not unwind three quarters of a circle.
	var diff: float = wrapf(angles[0] - _head_angle, -PI, PI)
	var step: float = TURN_SPEED * delta
	if absf(diff) <= step:
		_head_angle = angles[0]
	else:
		_head_angle += signf(diff) * step

# A capsule is drawn behind the gates while it is still in the mouth of one, and in front of them
# once it has left. Raising it a fixed distance after dispatch, rather than on the first movement,
# keeps it hidden for exactly as long as it overlaps the gate's own sprite.
func _rise_above_gate_once_clear() -> void:
	if _emerged:
		return
	if position.distance_to(_spawn_pos) < game.tile_size * EMERGED_FRAC:
		return
	_emerged = true
	z_index = Z_ON_BOARD
	$Skeleton.z_index = -20
	for i in bodies.size():
		if is_instance_valid(bodies[i]):
			bodies[i].z_index = -(i+1)
