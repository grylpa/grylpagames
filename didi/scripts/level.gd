extends CanvasLayer

class TimerArc extends Node2D:
	var progress: float = 1.0
	var radius: float = 20.0
	var width: float = 2.0
	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.1, 0.1, 0.1, 0.4), width)
		if progress <= 0.0:
			return
		var arc_end: float = -PI * 0.5 + progress * TAU
		var col: Color = Color(0.3, 0.85, 0.3, 1.0).lerp(Color(0.9, 0.2, 0.2, 1.0), 1.0 - progress)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, arc_end, 64, col, width)

var game: GenericGameUtil = null

# 8 directions: up, down, left, right, TL, TR, BL, BR
# Where each direction sits in the 3x3 the stats screen draws: row * 3 + column, with 4 the
# centre. The stats code stays ignorant of this game's own index order, the same way the rule
# games hand over a rule NAME rather than a key.
const DIR_SLOT: Array = [1, 7, 3, 5, 0, 2, 6, 8]
const DIR_NAME: Array = ["Up", "Down", "Left", "Right",
	"Top left", "Top right", "Bottom left", "Bottom right"]

const DIR_POSITIONS: Array = [
	Vector2i(3, 0),  # 0: up
	Vector2i(3, 6),  # 1: down
	Vector2i(0, 3),  # 2: left
	Vector2i(6, 3),  # 3: right
	Vector2i(0, 0),  # 4: TL
	Vector2i(6, 0),  # 5: TR
	Vector2i(0, 6),  # 6: BL
	Vector2i(6, 6),  # 7: BR
]

# THE STAKEOUT (2026-11-15). A rooftop over a night square in the rain. LIGHTNING lights it for one
# moment: the courier's umbrella at the center (WHAT -- its print and colors) and, at the same instant,
# the lookout glimpsed at one of the eight street mouths (WHERE). Then near darkness
# (the MASK), then the street lamps come on over umbrellas at every corner, and one tap answers both:
# the courier's umbrella, at the lookout's corner. This is the research task behind Pinpoint (the
# "useful field of view" speed training): a center item and a peripheral target shown TOGETHER, briefly,
# then masked. It used to show the shape first and the dot 150 ms later, with no mask.
#
# The DISPLAY TIME ADAPTS (a staircase): three fully right in a row shorten the flash by STEP_DOWN, a
# miss lengthens it by STEP_UP, so every player is kept at their own limit (it settles near 80% right).
# The levels add complexity instead: more umbrellas per corner, more look-alike prints, two-colored
# canopies and passers-by glimpsed with the lookout (clutter).
const MIN_FLASH_MS: float = 34.0          # two frames at 60 Hz
const FLASH_CEILING: float = 1.6          # the slowest it adapts to, x the level's starting time
const STEP_DOWN: float = 0.85
const STEP_UP: float = 1.20
const STREAK_TO_STEP: int = 3
const MASK_MS: float = 280.0
const LAMPS_MS: float = 180.0             # the lamps coming on
# EACH SPOT IS A GROUP IN ITS STREET, CENTERED ON THE LOOKOUT'S PLACE (2026-11-15): a pair down the
# street either side of it, or a triangle round it (see _get_cluster_positions), with no one ON it.
# Each spot is then a group of its own, set apart from the next by the roofs between the streets. Before: the people stood side by side across the street, either side of the
# lookout's point (at 170 and 190 degrees for a lookout at 180), and the sixteen umbrellas made one even
# ring with no visible groups. No jitter: the research task's targets are at fixed places too.
const PERIPH_R: float = 3.00              # the lookout, and the queue's middle place
const CLUSTER_R: float = PERIPH_R
const QUEUE_STEP: float = 0.80            # tiles between the two people of a pair
const TRIANGLE_H: float = 0.95            # a trio's triangle: tip to base, tiles
const TRIANGLE_HALF_BASE: float = 0.46    # and half its base
const CANOPY_TILES: float = 0.80          # a figure's width (an umbrella's), in tiles -- everyone alike
const CANOPY_FRAME_W: float = 92.0        # the same width in agent.gd's drawing frame (2 R)
const FIG_DROP_TILES: float = 0.42        # a figure stands this far below its point, so its umbrella
                                          # (not its feet) is centered on the ring
const VIEW_W_TILES: float = 8.4           # the scene's width the camera must show: out to the queues' ends
const VIEW_H_TILES: float = 8.6           # and its height
const VIEW_MID_TILES: float = 0.0         # how far above the fountain that height's middle is
const VIEW_TOP_PX: float = 56.0           # the HUD strip
const VIEW_BOTTOM_PX: float = 70.0        # the button bar
# The light on the figures is NEUTRAL in both moments (2026-11-15): an umbrella's COLOR is part of what
# the player remembers, and a cold light in the flash and a warm one in the answer shifted the same
# color two ways, so the right umbrella did not match the courier's. The scene carries the lightning
# and the lamplight; the umbrellas keep their true colors.
const LIGHT_FLASH: Color = Color(1.0, 1.0, 1.0)
const LIGHT_LAMPS: Color = Color(1.0, 1.0, 1.0)
const DIR_VEC: Array = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0),
	Vector2(-0.70710678, -0.70710678), Vector2(0.70710678, -0.70710678),
	Vector2(-0.70710678, 0.70710678), Vector2(0.70710678, 0.70710678)]
const FEEDBACK_RIGHT_MS: float = 650.0
const FEEDBACK_WRONG_MS: float = 1300.0   # longer: it shows where the lookout really was

var level: int = 1
var _flash_ms: float = 500.0              # the current display time (adapts)
var _flash_start_ms: float = 500.0        # this level's starting display time
var _streak: int = 0
var _clutter: int = 0
var _rotate: bool = false                 # corner umbrellas may be turned unlike the courier's
var _model_spin: float = 0.0
var _clutter_agents: Array = []
var _mask_until_ms: float = -1.0
var _lamps: float = 0.0
var _clear_at_ms: float = -1.0            # feedback showing: clear the answer umbrellas then
var _plaza: ColorRect = null
var _plaza_mat: ShaderMaterial = null
var _periph_px: Vector2 = Vector2.ZERO    # where the lookout was, to show after a miss
var _num_same: int = 2
var _num_options: int = 2
var _two_colors: bool = false
var _same_color_alts: bool = false
var _num_corrects_for_next_level: int = 5
var _time_to_consider_fail_ms: int = 5000

var num_corrects_in_level_so_far: int = 0
var _times_to_answer: Array = []

# Model and periph flash state
var _model_agent: Area2D = null
var _periph_agent: Area2D = null
var _model_done: bool = false
var _periph_done: bool = false
var _need_to_show_model: bool = false
var _time_to_show_model_ms: float = 0.0
var _need_to_show_periph: bool = false
var _time_to_show_periph_ms: float = 0.0
var _pending_answer_at_ms: float = -1.0

# Answer stage state
var _answer_active: bool = false
var _answer_agents: Array = []
var _answer_start_game_time: float = 0.0
var _answer_start_real_time: float = 0.0

# Current round's model shape/color (periph uses same)
var _round_model_texture_idx: int = 0
var _round_model_color: Array = []
var _periph_dir_idx: int = -1

# Circular timeout indicator
var _timer_arc: TimerArc = null

# Camera
var _agent_cam: Camera2D = null

signal started_playing
signal sig_level_is_done(didwin: bool)

@export var agent_scene: PackedScene = load("res://didi/scenes/agent.tscn")

# SOUNDS made for this game (devtools/make_answer_sounds.py): `dispatch` the target appearing
# (a radar ping), `delivery` a right answer (a rising chime), `swoosh` a wrong one (a soft low note), and
# one STEADY ambient loop. They replaced a heavy bell, an arcade coin, a swoosh and three stock
# ocean-wave loops.
var dispatch_audio: AudioStream = preload("res://art/sounds/didi_show.ogg")
var delivery_audio: AudioStream = preload("res://art/sounds/didi_right.ogg")
var swoosh_audio: AudioStream = preload("res://art/sounds/didi_wrong.ogg")

var ambient_audios: Array = [
	preload("res://art/sounds/didi_ambient.ogg"),
]

# What the score was when this level began. A level that misses the gate gives its points
# back (see the level-done function): without that, failing forever is a way to earn forever
# — every attempt banked its points and the retry cost nothing.
var _score_at_level_start: int = 0
var _rollback_score_on_next_level: bool = false

func _ready() -> void:
	game = DidiG.game
	# the ambient registered at once, so the main menu can play it under the poster (GenericGameUtil.menu_ambient)
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.set_sound_volume("ambient", -6.0)
	game.sig_time_over.connect(on_time_over)
	level = DidiG.starting_level
	_load_cfg(false)
	game.add_sound(self, "dispatch", dispatch_audio)
	game.add_sound(self, "delivery", delivery_audio)
	game.add_sound(self, "swoosh", swoosh_audio)
	if not MainGlobals.sig_game_popup_closed.is_connected(_on_game_popup_closed):
		MainGlobals.sig_game_popup_closed.connect(_on_game_popup_closed)
	_timer_arc = TimerArc.new()
	_timer_arc.z_index = 10
	_timer_arc.hide()
	add_child(_timer_arc)
	_create_camera()
	_fit_ground_to_board()

func _on_game_popup_closed() -> void:
	if not game.level_is_done and not game.level_is_ready:
		game.level_is_ready = true
		started_playing.emit()
		_schedule_next_round(500.0)

func new_game(from_scratch: bool = true) -> void:
	# The failed level's points go back HERE, on Continue, together with everything else that is
	# cleared — so the summary card was still read against the score the player had while playing.
	if _rollback_score_on_next_level:
		_rollback_score_on_next_level = false
		game.score = _score_at_level_start
	_score_at_level_start = game.score
	# A replay has to be a FRESH attempt. The gate reads these, so a retry that inherited the
	# misses which failed the level could not pass it even played perfectly; and the summary's
	# timing average would fold in the attempt the player is being made to redo.
	game.corrects = 0
	game.mistakes = 0
	_times_to_answer.clear()
	_clear_round_state()
	game.level_is_ready = false
	game.level_is_done = false
	num_corrects_in_level_so_far = 0
	if from_scratch:
		level = DidiG.starting_level
	_load_cfg(game.need_to_increase_level)
	game.need_to_increase_level = false
	game.level_label_changed("Level %d" % level)
	ambient_audios.shuffle()
	game.add_sound(self, "ambient", ambient_audios[0], true)
	game.set_sound_volume("ambient", -6.0)
	game.play_sound("ambient")
	if game.tutorial_mode:
		# The tutorial teaches all of this by doing it, and a wall of level numbers in front of the
		# coach is the first thing the player would have to dismiss.
		_on_game_popup_closed()
		return
	var lvl: Dictionary = DidiLevelConfig.get_level(level)
	game.show_game_popup(self, "Level %d" % level,
		"Umbrellas per corner: %d\nPassers-by: %d\nTime to answer: %.1f s\nRounds: %d" % [
			lvl["num_options"], lvl.get("clutter", 0),
			float(lvl["time_to_consider_fail"]) / 1000.0, lvl["rounds"]])

func _load_cfg(increase: bool = false) -> void:
	if increase:
		level = min(level + 1, DidiLevelConfig.MAX_LEVEL)
	level = clamp(level, 1, DidiLevelConfig.MAX_LEVEL)
	var s: int = 7
	game.max_board_size = Vector2i(s, s)
	game.forced_board_size = Vector2i(s, s)
	game.init_sizes()
	var lvl: Dictionary = DidiLevelConfig.get_level(level)
	_flash_start_ms = float(lvl["flash_ms"])
	_flash_ms = _flash_start_ms
	_streak = 0
	_clutter = int(lvl.get("clutter", 0))
	_rotate = bool(lvl.get("rotate", false))
	_num_same = lvl["num_same"]
	_two_colors = lvl["two_colors"]
	_same_color_alts = lvl["same_color_alts"]
	_num_options = lvl["num_options"]
	_num_corrects_for_next_level = lvl["rounds"]
	_time_to_consider_fail_ms = lvl["time_to_consider_fail"]
	_fit_ground_to_board()
	if game.tutorial_mode:
		# After the level values are read, so it overrides them rather than being overwritten.
		_tutorial_setup()

# --- tutorial staging -------------------------------------------------------

# Set by the tutorial for its final step; cleared when the tutorial ends.
var tutorial_only_correct_taps: bool = false

# Holds the round at the gate. "Watch the center" is worth nothing if the shape has already come
# and gone by the time the player has read it — so the coach holds the round until they say they
# are ready, and only then lets it run.
var tutorial_hold_round: bool = false

# The one agent that is both the right shape AND in the right direction.
func tutorial_correct_agent():
	for a in _answer_agents:
		if is_instance_valid(a) and a.is_correct:
			return a
	return null

func _tutorial_setup() -> void:
	# The answer clock is 6 s at level 1, which is right for play and absurd for someone reading a
	# caption. game_time does not advance while a caption is up, but the moment they start looking
	# for the answer it does, and a first-timer needs longer than six seconds.
	_time_to_consider_fail_ms = 10000000

# The shape the round is about, while it is still lit.
func tutorial_model_agent():
	return _model_agent if _model_agent != null and is_instance_valid(_model_agent) else null

# The dot, while it is still lit.
func tutorial_periph_agent():
	return _periph_agent if _periph_agent != null and is_instance_valid(_periph_agent) else null

# A decoy: the model's shape sitting in a direction the dot did NOT flash. This is the trap the
# tutorial has to name out loud, so it needs to be able to point at one.
func tutorial_decoy_agent():
	for a in _answer_agents:
		if is_instance_valid(a) and a.is_correct_shape and not a.is_correct_direction:
			return a
	return null

func _clear_round_state() -> void:
	_answer_active = false
	if _timer_arc != null:
		_timer_arc.hide()
	_clear_answer_agents()
	if _model_agent != null and is_instance_valid(_model_agent):
		_model_agent.queue_free()
	_model_agent = null
	if _periph_agent != null and is_instance_valid(_periph_agent):
		_periph_agent.queue_free()
	_periph_agent = null
	_clear_clutter()
	_mask_until_ms = -1.0
	_clear_at_ms = -1.0
	_model_done = false
	_periph_done = false
	_pending_answer_at_ms = -1.0
	_need_to_show_model = false
	_need_to_show_periph = false

func _schedule_next_round(delay_ms: float) -> void:
	_model_done = false
	_periph_done = false
	_pending_answer_at_ms = -1.0
	_time_to_show_model_ms = game.game_time + delay_ms
	_need_to_show_model = true

func _process(delta: float) -> void:
	_light_plaza(delta)
	if game.level_is_done:
		return
	# Update circular arc timer continuously (real time for smooth animation)
	if _answer_active and _timer_arc != null and _timer_arc.visible:
		var elapsed_sec: float = Time.get_unix_time_from_system() - _answer_start_real_time
		var timeout_sec: float = float(_time_to_consider_fail_ms) / 1000.0
		_timer_arc.progress = 1.0 - clamp(elapsed_sec / timeout_sec, 0.0, 1.0)
		_timer_arc.queue_redraw()
	if game.paused() or not game.level_is_ready:
		return
	if _clear_at_ms >= 0.0 and game.game_time >= _clear_at_ms:
		_clear_at_ms = -1.0
		_clear_answer_agents()
	if _need_to_show_model and game.game_time >= _time_to_show_model_ms:
		if tutorial_hold_round:
			# Held: keep the round pending so it starts the moment the coach lets it, rather than
			# firing the instant the player dismisses a caption they have not finished reading.
			_time_to_show_model_ms = game.game_time + 100.0
		else:
			_need_to_show_model = false
			_spawn_model()
	if _need_to_show_periph and game.game_time >= _time_to_show_periph_ms:
		_need_to_show_periph = false
		_spawn_periph_flash()
	if _pending_answer_at_ms >= 0.0 and game.game_time >= _pending_answer_at_ms:
		_pending_answer_at_ms = -1.0
		_dispatch_answer_stage()
	if _answer_active and game.game_time >= _answer_start_game_time + float(_time_to_consider_fail_ms):
		_on_answer_timeout()

func _spawn_model() -> void:
	if _model_agent != null and is_instance_valid(_model_agent):
		_model_agent.queue_free()
	var center: Vector2i = Vector2i(3, 3)
	_model_done = false
	var agent: Area2D = agent_scene.instantiate()
	agent.time_to_hide_ms = _flash_ms
	agent.is_model = true
	agent.is_correct = false
	agent.board_pos = center
	add_child(agent)
	var use_two_colors: bool = _two_colors and game.rng.randi() % 2 == 0
	if use_two_colors:
		_round_model_color = [game.next_color(), game.next_color()]
	else:
		var c: Color = game.next_color()
		_round_model_color = [c, c]
	_round_model_texture_idx = agent.set_rand_texture()
	agent.set_pos(game.board_to_px(center), 0)
	_person(agent, LIGHT_FLASH)
	agent.set_colors(_round_model_color)
	_model_spin = agent.spin
	agent.need_to_remove_agent.connect(_on_model_removed)
	_model_agent = agent
	# The lookout and any passers-by in the SAME flash: the research task shows the center item and
	# the peripheral target together (it used to show the dot 150 ms after the shape).
	_spawn_periph_flash()
	_spawn_clutter()
	game.play_sound("dispatch")
	game.tutorial_notify("model_shown")   # no-op outside tutorial mode
	game.tutorial_notify("periph_shown")

func _on_model_removed(_agent) -> void:
	if is_instance_valid(_agent):
		_agent.queue_free()
	_model_agent = null
	_model_done = true
	_maybe_start_answer()

func _spawn_periph_flash() -> void:
	_periph_dir_idx = game.rng.randi() % 8
	var center_px: Vector2 = game.board_to_px(Vector2i(3, 3))
	# On ONE RING for every direction, so no direction is nearer the center (easier) than another.
	# (It was 80-100% of the way to the board's edge, which put the corners 41% further out.)
	var flash_px: Vector2 = center_px + (DIR_VEC[_periph_dir_idx] as Vector2) * PERIPH_R * float(game.tile_size)
	_periph_px = flash_px
	var agent: Area2D = agent_scene.instantiate()
	agent.time_to_hide_ms = _flash_ms
	agent.is_model = false
	agent.is_correct = false
	agent.board_pos = DIR_POSITIONS[_periph_dir_idx]
	add_child(agent)
	agent.set_pos(flash_px, 0)
	agent.set_kind(agent.Kind.LOOKOUT)        # the yellow raincoat: position only, nothing to remember
	_person(agent, LIGHT_FLASH)
	agent.need_to_remove_agent.connect(func(_a):
		if is_instance_valid(_a):
			_a.queue_free()
		_periph_agent = null
		_periph_done = true
		_maybe_start_answer()
	)
	_periph_agent = agent

# The flash is over: near darkness for MASK_MS (so nothing lingers on the eye -- the display time
# is then the time the player really had), then the lamps and the answer.
# PASSERS-BY glimpsed in the same flash (the research task's clutter, from level 3): dark coats on
# the same ring, at random bearings clear of the lookout and of each other. Gone with the flash.
func _spawn_clutter() -> void:
	_clear_clutter()
	if _clutter <= 0:
		return
	var center_px: Vector2 = game.board_to_px(Vector2i(3, 3))
	# The research's hardest stage fills the other places with look-alikes: so the passers-by stand
	# at the OTHER posts first, in random order, and only beyond seven between the posts.
	var spots: Array = []
	for k in 8:
		if k != _periph_dir_idx:
			spots.append((DIR_VEC[k] as Vector2).angle())
	spots.shuffle()
	for k2 in 8:
		spots.append((DIR_VEC[k2] as Vector2).angle() + PI / 8.0)
	for i2 in mini(_clutter, spots.size()):
		var agent: Area2D = agent_scene.instantiate()
		agent.time_to_hide_ms = _flash_ms
		add_child(agent)
		agent.set_pos(center_px + Vector2.from_angle(float(spots[i2])) * PERIPH_R * float(game.tile_size), 0)
		agent.set_kind(agent.Kind.PASSERBY)
		_person(agent, LIGHT_FLASH)
		agent.input_pickable = false
		_clutter_agents.append(agent)

func _clear_clutter() -> void:
	for a in _clutter_agents:
		if is_instance_valid(a):
			a.queue_free()
	_clutter_agents.clear()

# THE STAIRCASE: three fully right in a row -> a shorter flash; any miss -> a longer one.
func _adapt(right: bool) -> void:
	if game.tutorial_mode:
		return
	if right:
		_streak += 1
		if _streak >= STREAK_TO_STEP:
			_streak = 0
			_flash_ms = maxf(MIN_FLASH_MS, _flash_ms * STEP_DOWN)
	else:
		_streak = 0
		_flash_ms = minf(_flash_start_ms * FLASH_CEILING, _flash_ms * STEP_UP)

# The answer is in: the tapped umbrella ringed green or red, and after a miss the right one ringed
# gold and the lookout shown again where they stood, so the player sees what they lost. The umbrellas
# go when the feedback has been seen (_clear_at_ms).
func _show_feedback(tapped) -> void:
	_answer_active = false
	if _timer_arc != null:
		_timer_arc.hide()
	var right: bool = tapped != null and tapped.is_correct
	if tapped != null:
		tapped.set_mark(1 if right else 2)
	if not right:
		var c = tutorial_correct_agent()
		if c != null:
			c.set_mark(3)
		var ghost: Area2D = agent_scene.instantiate()
		ghost.time_to_hide_ms = FEEDBACK_WRONG_MS
		add_child(ghost)
		ghost.set_pos(_periph_px, 0)
		ghost.set_kind(ghost.Kind.LOOKOUT)
		_person(ghost, LIGHT_LAMPS)
		ghost.modulate.a = 0.75
		ghost.input_pickable = false
		ghost.need_to_remove_agent.connect(func(g): if is_instance_valid(g): g.queue_free())
	_clear_at_ms = game.game_time + (FEEDBACK_RIGHT_MS if right else FEEDBACK_WRONG_MS)

# The plaza's three lights, every frame: LIGHTNING while the flash is up (held, with the figures,
# while a tutorial caption pauses the game), the MASK until it runs out, the LAMPS eased on for the
# answer and off again.
func _light_plaza(delta: float) -> void:
	if _plaza_mat == null:
		return
	var flash_on: bool = (_model_agent != null and is_instance_valid(_model_agent) and _model_agent.visible) \
		or (_periph_agent != null and is_instance_valid(_periph_agent) and _periph_agent.visible)
	_plaza_mat.set_shader_parameter("flash", 1.0 if flash_on else 0.0)
	var masking: bool = _mask_until_ms >= 0.0 and game.game_time < _mask_until_ms
	_plaza_mat.set_shader_parameter("mask", 1.0 if masking else 0.0)
	var lamps_to: float = 1.0 if (_answer_active or _clear_at_ms >= 0.0) else 0.0
	_lamps = move_toward(_lamps, lamps_to, delta * 1000.0 / LAMPS_MS)
	_plaza_mat.set_shader_parameter("lamps", _lamps)

func _maybe_start_answer() -> void:
	if _model_done and _periph_done and _pending_answer_at_ms < 0.0 and not _answer_active:
		_clear_clutter()
		_mask_until_ms = game.game_time + MASK_MS
		_pending_answer_at_ms = game.game_time + MASK_MS

func _dispatch_answer_stage() -> void:
	if game.paused() or game.level_is_done or _answer_active:
		return
	_answer_active = true
	_answer_start_game_time = game.game_time
	_answer_start_real_time = Time.get_unix_time_from_system()
	_clear_answer_agents()

	# Decide which direction clusters get the correct shape.
	# periph_dir_idx always gets one; fill remaining from random others.
	var correct_shape_dirs: Array = [_periph_dir_idx]
	var other_dirs: Array = []
	for i in 8:
		if i != _periph_dir_idx:
			other_dirs.append(i)
	other_dirs.shuffle()
	var extra: int = min(_num_same - 1, other_dirs.size())
	for i in range(extra):
		correct_shape_dirs.append(other_dirs[i])

	for dir_idx in 8:
		var has_correct_shape: bool = dir_idx in correct_shape_dirs
		_spawn_answer_cluster(dir_idx, has_correct_shape)

	game.tutorial_notify("answer_ready")   # no-op outside tutorial mode
	_timer_arc.position = game.board_to_px(Vector2i(3, 3))
	_timer_arc.radius = game.tile_size * 0.25
	_timer_arc.progress = 1.0
	_timer_arc.show()
	_timer_arc.queue_redraw()

# Where the people of one spot stand, round the lookout's place in that street (CLUSTER_R) -- with NO
# ONE ON IT, so no umbrella is singled out by standing exactly where the lookout flashed:
#   2: a queue down the street, one nearer the fountain and one farther, half a step either side;
#   3: a triangle whose CENTER is the lookout's place, its tip toward the fountain and its base toward
#      the edge of the screen.
func _get_cluster_positions(dir_idx: int, num_opts: int) -> Array:
	var t: float = float(game.tile_size)
	var out_dir: Vector2 = DIR_VEC[dir_idx]
	var perp: Vector2 = Vector2(-out_dir.y, out_dir.x)
	var spot: Vector2 = game.board_to_px(Vector2i(3, 3)) + out_dir * CLUSTER_R * t
	if num_opts <= 2:
		return [spot - out_dir * QUEUE_STEP * 0.5 * t, spot + out_dir * QUEUE_STEP * 0.5 * t]
	var h: float = TRIANGLE_H * t                  # the triangle's height, tip to base
	return [spot - out_dir * h * 2.0 / 3.0,        # the tip, toward the fountain
		spot + out_dir * h / 3.0 - perp * TRIANGLE_HALF_BASE * t,
		spot + out_dir * h / 3.0 + perp * TRIANGLE_HALF_BASE * t]

# Every figure the same size -- umbrellas, the lookout's clear one, the passers-by's black ones (fairness:
# no spot's people bigger, so easier, than another's) -- standing so its umbrella is centered on its
# point, drawn in front of anyone further back, and lit by the moment it belongs to.
func _person(agent: Area2D, light: Color) -> void:
	var sc: float = CANOPY_TILES * float(game.tile_size) / CANOPY_FRAME_W
	agent.scale = Vector2(sc, sc)
	agent.position += Vector2(0.0, FIG_DROP_TILES * float(game.tile_size))
	agent.z_index = 100 + int(agent.position.y * 0.5)
	agent.set_light(light)

func _spawn_answer_cluster(dir_idx: int, has_correct_shape: bool) -> void:
	var positions: Array = _get_cluster_positions(dir_idx, _num_options)
	# Randomly pick which sub-slot within this cluster gets the correct shape
	var correct_sub: int = game.rng.randi() % positions.size()
	for sub_idx in positions.size():
		var px: Vector2 = positions[sub_idx]
		var this_correct_shape: bool = has_correct_shape and sub_idx == correct_sub
		var this_true_correct: bool = this_correct_shape and dir_idx == _periph_dir_idx
		var agent: Area2D = agent_scene.instantiate()
		agent.time_to_hide_ms = 999999.0
		agent.is_model = false
		agent.is_correct = this_true_correct
		agent.is_correct_shape = this_correct_shape
		agent.is_correct_direction = (dir_idx == _periph_dir_idx)
		agent.board_pos = DIR_POSITIONS[dir_idx]
		add_child(agent)
		agent.set_pos(px, 0)
		_person(agent, LIGHT_LAMPS)
		# The same turn as the courier's unless the level allows otherwise (`rotate`): a turned
		# "half" or "stripes" print reads as a different print.
		if not _rotate:
			agent.spin = _model_spin
		if this_correct_shape:
			agent.set_texture(_round_model_texture_idx)
			agent.set_colors(_round_model_color.duplicate(true))
		else:
			agent.set_rand_texture(_round_model_texture_idx)
			if _same_color_alts:
				agent.set_colors(_round_model_color.duplicate(true))
			else:
				# a CLEARLY different umbrella (level 1: the research's "car or truck")
				var c: Color = game.next_color()
				for _try in 8:
					if not c.is_equal_approx(_round_model_color[0]):
						break
					c = game.next_color()
				agent.set_colors([c, c])
		agent.agent_pressed.connect(func(_a): _on_answer_agent_pressed(_a))
		_answer_agents.append(agent)

func _on_answer_agent_pressed(agent) -> void:
	if not _answer_active or game.paused() or game.level_is_done:
		return
	# While the tutorial is asking for one particular shape, anything else is simply ignored: no
	# score, no partial credit, no round ending. A first-timer who taps the wrong thing here should
	# get another go at the thing being explained, not a penalty and a fresh round.
	if tutorial_only_correct_taps and not agent.is_correct:
		game.play_sound("swoosh")
		return
	var elapsed_ms: float = game.game_time - _answer_start_game_time

	# WHICH DIRECTION the dot was in, and what survived of the round. A percentage for the
	# session cannot show a corner the player keeps missing, and it cannot separate losing the
	# shape from losing the place — which is the whole question this game asks.
	game.record_trial({
		"dir": _periph_dir_idx,
		"slot": DIR_SLOT[_periph_dir_idx],
		"dir_name": DIR_NAME[_periph_dir_idx],
		"right": agent.is_correct,
		"got_dir": agent.is_correct_direction,
		"got_shape": agent.is_correct_shape,
		"ms": int(elapsed_ms),
	})

	_adapt(agent.is_correct)
	if agent.is_correct:
		var score_to_add: int = max(1, int(10 - elapsed_ms / 300.0))
		_add_time_to_answer_ms(int(elapsed_ms))
		game.add_score_and_time(score_to_add, 15)
		game.add_correct_or_mistake(1, 0)
		game.play_sound("delivery")
		_show_score_popup(agent.position, "+" + str(score_to_add), true)
		game.tutorial_notify("answered_right")   # no-op outside tutorial mode
		num_corrects_in_level_so_far += 1
	elif agent.is_correct_direction:
		# Correct direction, wrong shape — partial credit
		game.add_score_and_time(1, 5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("swoosh")
		_show_score_popup(agent.position, "+1", false)
	elif agent.is_correct_shape:
		# Correct shape, wrong direction — partial credit
		game.add_score_and_time(1, 5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("swoosh")
		_show_score_popup(agent.position, "+1", false)
	else:
		# Decoy
		game.add_score_and_time(-1, -5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("swoosh")
		_show_score_popup(agent.position, "-1", false)

	_show_feedback(agent)

	if agent.is_correct and num_corrects_in_level_so_far >= _num_corrects_for_next_level:
		_level_done(true)
		return
	_schedule_next_round((FEEDBACK_RIGHT_MS if agent.is_correct else FEEDBACK_WRONG_MS) + 350.0)

func _on_answer_timeout() -> void:
	# A round that ran out is a round got wrong in that direction, not a round that never
	# happened. Leaving it out would flatter whichever direction the player freezes on.
	if _answer_active and _periph_dir_idx >= 0:
		game.record_trial({"dir": _periph_dir_idx, "slot": DIR_SLOT[_periph_dir_idx],
			"dir_name": DIR_NAME[_periph_dir_idx], "right": false,
			"got_dir": false, "got_shape": false, "ms": 0})

	if not _answer_active:
		return
	_adapt(false)
	game.add_score_and_time(-1, -5)
	game.add_correct_or_mistake(0, 1)
	game.play_sound("swoosh")
	_show_feedback(null)
	_schedule_next_round(FEEDBACK_WRONG_MS + 350.0)

func _end_answer_stage() -> void:
	_answer_active = false
	if _timer_arc != null:
		_timer_arc.hide()
	_clear_answer_agents()

func _clear_answer_agents() -> void:
	for a in _answer_agents:
		if is_instance_valid(a):
			a.queue_free()
	_answer_agents.clear()

func on_time_over() -> void:
	game.stop_sound("ambient")

func tick() -> void:
	pass

func _level_done(didwin: bool) -> void:
	game.level_is_done = true
	# The gate is decided BEFORE the level's score row is written: main.gd saves that row on
	# game.sig_level_is_done, and it has to carry the score the player actually KEEPS, or
	# failing the same level over and over is a way to farm the score list.
	#
	# Passing is a RESULT, not a formality: below this level's accuracy the SAME level comes
	# round again. The bar rises with the level, from 60% to at most 70%: the adaptive flash holds a
	# player near 80% right, so a bar at 80% (as before the staircase) would fail them for playing at
	# exactly the level the game puts them at. Failing now means struggling even at the slowest flash.
	var need: int = mini(60 + 2 * (level - 1), 70)
	var pct: int = game.session_pct_correct()
	var passed: bool = true
	if didwin and level < DidiLevelConfig.MAX_LEVEL:
		passed = pct >= need
		_rollback_score_on_next_level = not passed
	if passed:
		game.sig_level_is_done.emit(didwin)
	else:
		# The kept value is put in place just for the save. The SCREEN keeps showing the score
		# the player had while playing, because watching it drop out from under a summary you
		# are still reading is alarming; the visible rollback lands on Continue, in new_game().
		var earned_this_level: int = game.score
		game.score = _score_at_level_start
		game.sig_level_is_done.emit(didwin)
		game.score = earned_this_level
	game.stop_sound("ambient")
	if didwin:
		# No fanfare for a level that was not passed.
		MainGlobals.global_level_is_done(passed)
		if level >= DidiLevelConfig.MAX_LEVEL:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = passed
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var textadd: String = "\n\nAverage time: %d ms\nAccuracy: %d%%\n\n%s" % [mean_time_to_answer_ms(), pct, _progress_line(passed, need)]
			game.show_level_done_popup(self, "", "", level, textadd, passed)
	else:
		sig_level_is_done.emit(didwin)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

const FEEDBACK_OK_TEXT_COLOR: Color = Color(0.3, 1.0, 0.3)
const FEEDBACK_BAD_TEXT_COLOR: Color = Color(1.0, 0.4, 0.4)

func _show_score_popup(px: Vector2, text: String, is_correct: bool) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color",
		FEEDBACK_OK_TEXT_COLOR if is_correct else FEEDBACK_BAD_TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(game.tile_size * 3, 0)
	label.position = px - Vector2(game.tile_size * 1.5, game.tile_size * 0.5)
	label.z_index = 10
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", px.y - game.tile_size * 2.5, 0.65)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.65)
	tween.tween_callback(label.queue_free)

func mean_time_to_answer_ms() -> int:
	var N: int = _times_to_answer.size()
	if N == 0:
		return _time_to_consider_fail_ms
	var s: int = 0
	for t in _times_to_answer:
		s += t
	return roundi(float(s) / float(N))

func _add_time_to_answer_ms(t_ms: int) -> void:
	if t_ms <= 0:
		return
	_times_to_answer.append(t_ms)
	while _times_to_answer.size() > 10:
		_times_to_answer.remove_at(0)

func _create_camera() -> void:
	follow_viewport_enabled = true
	if _agent_cam == null:
		_agent_cam = Camera2D.new()
		add_child(_agent_cam)
	_agent_cam.make_current()
	# Fit the whole SCENE, not just the board's width: from the roofline above the far spots to the
	# near spots, between the HUD strip and the button bar. Fitting the width alone put the buildings
	# above the screen on the shorter desktop canvas and the ring too high (2026-11-15).
	var t: float = float(game.tile_size)
	var canvas: Vector2 = Vector2(MainGlobals.full_screen_size)
	var avail_h: float = canvas.y - VIEW_TOP_PX - VIEW_BOTTOM_PX
	var z: float = minf(canvas.x / (VIEW_W_TILES * t), avail_h / (VIEW_H_TILES * t))
	_agent_cam.zoom = Vector2(z, z)
	_agent_cam.enabled = true
	_agent_cam.set_anchor_mode(Camera2D.ANCHOR_MODE_DRAG_CENTER)
	# the scene's middle (VIEW_MID_TILES above the fountain) at the middle of the free band
	var band_mid: float = VIEW_TOP_PX + avail_h * 0.5
	var c: Vector2 = game.board_to_px(Vector2i(3, 3))
	_agent_cam.set_offset(Vector2(c.x, c.y - VIEW_MID_TILES * t + (canvas.y * 0.5 - band_mid) / z))

# What the player gets next, in words. An accuracy figure alone does not say whether they are
# moving on, which is the only thing they want to know at that moment.
func _progress_line(passed: bool, need: int) -> String:
	if not passed:
		return "You need at least %d%% accuracy to pass to the next level." % need
	return "Level passed. On to level %d." % (level + 1)

# THE SQUARE (plaza.gdshader) under everything: a ColorRect first in the layer, covering the board
# plus a four-tile margin and the whole canvas (the camera shows more than the board on a phone), its
# pattern laid from the board's CENTER and the tile size. It replaced StudyBackdrop's plain surface.
# Called from _ready() and _load_cfg() (the board is a fixed 7x7, so that is the only place its size
# could change).
func _fit_ground_to_board() -> void:
	var tiled: CanvasItem = get_node_or_null("TextureRect") as CanvasItem
	if _plaza == null:
		_plaza = ColorRect.new()
		_plaza.name = "Plaza"
		_plaza.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plaza_mat = ShaderMaterial.new()
		_plaza_mat.shader = preload("res://didi/scripts/plaza.gdshader")
		_plaza.material = _plaza_mat
		add_child(_plaza)
		move_child(_plaza, 0)
	var m: float = game.tile_size * 4.0
	var r: Rect2 = Rect2(game.board_to_px(Vector2i(0, 0)) - Vector2(m, m),
		game.board_to_px(game.board_size) - game.board_to_px(Vector2i(0, 0)) + Vector2(m, m) * 2.0)
	r = r.merge(Rect2(Vector2.ZERO, Vector2(MainGlobals.full_screen_size)))
	if r.size.x < 4.0 or r.size.y < 4.0:
		return
	if tiled != null:
		tiled.hide()
	_plaza.position = r.position
	_plaza.size = r.size
	_plaza_mat.set_shader_parameter("rect_pos", r.position)
	_plaza_mat.set_shader_parameter("rect_size", r.size)
	_plaza_mat.set_shader_parameter("center", game.board_to_px(Vector2i(3, 3)))
	_plaza_mat.set_shader_parameter("tile", float(game.tile_size))
	_plaza_mat.set_shader_parameter("lamp_r", 3.45)
