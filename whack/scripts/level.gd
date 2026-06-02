extends CanvasLayer

signal started_playing
signal sig_level_is_done(didwin: bool)

var game: GenericGameUtil

var level: int = 1
var max_difficulty: int = WhackLevelConfig.LEVELS.size()
var num_corrects_in_level_so_far: int = 0
var corrects_for_next_level: int = 10
var target_radius: float = 48.0
var show_target_ms: float = 4000.0
var interval_min_ms: float = 1000.0
var interval_max_ms: float = 2500.0
var _num_decoys: int = 0
var _no_real_chance: float = 0.0
var _same_color_decoy: bool = false
var _use_many_colors_for_decoys: bool = false

const _DECOY_COLOR_DEFAULT: Color = Color(0.25, 0.5, 1.0, 1.0)
const _DECOY_COLORS_MULTI: Array = [
	Color(0.3,  0.85, 0.3,  1.0),  # green
	Color(0.75, 0.3,  0.9,  1.0),  # purple
	Color(0.9,  0.85, 0.2,  1.0),  # yellow
	Color(0.2,  0.85, 0.85, 1.0),  # cyan
	Color(0.9,  0.3,  0.7,  1.0),  # pink
]

var _target_active: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _target_color: Color = Color(1.0, 0.35, 0.2, 1.0)

# Each decoy: { "pos": Vector2, "color": Color, "draw_dot": bool }
var _decoys: Array = []

var _round_active: bool = false
var _round_has_real: bool = true
var _round_shown_time_ms: float = 0.0

var _reaction_times: Array = []
var _accuracies: Array = []

var _next_target_time_ms: float = 0.0
var _waiting_for_next: bool = false

var _flash_color: Color = Color.TRANSPARENT
var _flash_alpha: float = 0.0
var _flash_pos: Vector2 = Vector2.ZERO

var _hit_sound: AudioStream = preload("res://art/sounds/tap-1.mp3")
var _miss_sound: AudioStream = preload("res://art/sounds/bump-sound-7.mp3")
var _appear_sound: AudioStream = preload("res://art/sounds/click-2.mp3")

@onready var _draw_area: Control = $DrawArea

func _ready() -> void:
	game = WhackG.game
	game.sig_time_over.connect(_on_time_over)
	level = WhackG.starting_level
	_apply_difficulty()
	game.add_sound(self, "hit", _hit_sound)
	game.add_sound(self, "miss", _miss_sound)
	game.add_sound(self, "appear", _appear_sound)
	game.add_sound(self, "wrong", preload("res://art/sounds/swoosh.mp3"))
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_draw_area.position = Vector2.ZERO
	_draw_area.size = vp_size
	_draw_area.gui_input.connect(_on_draw_area_input)

func new_game(from_scratch: bool = true) -> void:
	game.level_is_ready = false
	if from_scratch:
		level = WhackG.starting_level
	else:
		if game.need_to_increase_level:
			level = min(level + 1, max_difficulty)
			game.need_to_increase_level = false
	_apply_difficulty()
	game.level_label_changed("Level %d" % level)
	num_corrects_in_level_so_far = 0
	if from_scratch:
		_reaction_times.clear()
		_accuracies.clear()
	_target_active = false
	_round_active = false
	_decoys.clear()
	_waiting_for_next = false
	_flash_alpha = 0.0
	_draw_area.queue_redraw()
	_schedule_next_target()
	game.level_is_ready = true
	started_playing.emit()

func _apply_difficulty() -> void:
	var idx: int = clamp(level - 1, 0, WhackLevelConfig.LEVELS.size() - 1)
	var cfg: Dictionary = WhackLevelConfig.LEVELS[idx]
	target_radius = cfg["radius"]
	show_target_ms = cfg["show_ms"]
	interval_min_ms = cfg["interval_min_ms"]
	interval_max_ms = cfg["interval_max_ms"]
	corrects_for_next_level = cfg["hits_to_complete"]
	_num_decoys = cfg.get("num_decoys", 0)
	_no_real_chance = cfg.get("no_real_chance", 0.0)
	_same_color_decoy = cfg.get("same_color_decoy", false)
	_use_many_colors_for_decoys = cfg.get("use_many_colors_for_decoys", false)

func _schedule_next_target() -> void:
	var interval: float = randf_range(interval_min_ms, interval_max_ms)
	_next_target_time_ms = game.game_time + interval
	_waiting_for_next = true

func _try_random_pos(area_size: Vector2, existing: Array) -> Variant:
	var top_margin: float = 120.0
	var bottom_margin: float = 80.0
	var visual_radius: float = target_radius + 11.0  # circle edge + arc (radius+9 center, 4px wide)
	var pad: float = visual_radius + 4.0
	var min_sep: float = visual_radius * 2.0 + 12.0
	var x_min: float = pad
	var x_max: float = area_size.x - pad
	var y_min: float = top_margin + pad
	var y_max: float = area_size.y - bottom_margin - pad
	if x_max <= x_min or y_max <= y_min:
		return null
	for _attempt in range(200):
		var pos: Vector2 = Vector2(randf_range(x_min, x_max), randf_range(y_min, y_max))
		var ok: bool = true
		for ep in existing:
			if pos.distance_to(ep) < min_sep:
				ok = false
				break
		if ok:
			return pos
	return null

func _spawn_round() -> void:
	_waiting_for_next = false
	_round_has_real = randf() >= _no_real_chance
	_decoys.clear()
	_target_active = false

	var area_size: Vector2 = _draw_area.size
	if area_size.x < 100.0 or area_size.y < 100.0:
		area_size = Vector2(680.0, 788.0)

	var used_positions: Array = []

	if _round_has_real:
		var rpos: Variant = _try_random_pos(area_size, used_positions)
		if rpos != null:
			_target_pos = rpos
			used_positions.append(_target_pos)
			_target_active = true

	var round_same_color: bool = _same_color_decoy
	var round_multi_color: bool = _use_many_colors_for_decoys
	if _same_color_decoy and _use_many_colors_for_decoys:
		round_same_color = randf() < 0.5
		round_multi_color = not round_same_color

	var decoy_count: int = 0
	for _i in range(_num_decoys):
		var dpos: Variant = _try_random_pos(area_size, used_positions)
		if dpos == null:
			break  # can't fit more decoys without overlapping — stop here
		used_positions.append(dpos)
		var dcolor: Color
		if round_same_color:
			dcolor = _target_color
		elif round_multi_color:
			dcolor = _DECOY_COLORS_MULTI[decoy_count % _DECOY_COLORS_MULTI.size()]
		else:
			dcolor = _DECOY_COLOR_DEFAULT
		_decoys.append({"pos": dpos, "color": dcolor, "draw_dot": not round_same_color})
		decoy_count += 1

	_round_shown_time_ms = game.game_time
	_round_active = true
	_target_color = Color(1.0, 0.35, 0.2, 1.0)
	game.play_sound("appear")
	_draw_area.queue_redraw()

func _process(_delta: float) -> void:
	if not game.level_is_ready or game.level_is_done or game.paused():
		return
	if _waiting_for_next and game.game_time >= _next_target_time_ms:
		_spawn_round()
	if _round_active and (game.game_time - _round_shown_time_ms) >= show_target_ms:
		_on_round_timeout()
	if _round_active:
		_draw_area.queue_redraw()
	if _flash_alpha > 0.0:
		_flash_alpha -= _delta * 2.5
		if _flash_alpha < 0.0:
			_flash_alpha = 0.0
		_draw_area.queue_redraw()

func _on_round_timeout() -> void:
	_round_active = false
	_target_active = false
	_decoys.clear()
	if _round_has_real:
		game.add_score_and_time(-5, -5)
		game.add_correct_or_mistake(0, 1)
		game.play_sound("wrong")
	_draw_area.queue_redraw()
	_schedule_next_target()

func _on_draw_area_input(event: InputEvent) -> void:
	if not game.level_is_ready or game.level_is_done or game.paused():
		return
	var tap_pos: Vector2 = Vector2.ZERO
	var is_tap: bool = false
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.pressed:
			tap_pos = mbe.position
			is_tap = true
	elif event is InputEventScreenTouch:
		var ste: InputEventScreenTouch = event as InputEventScreenTouch
		if ste.pressed:
			tap_pos = ste.position
			is_tap = true
	if not is_tap:
		return
	if not _round_active:
		return

	# Check decoys first
	for i in range(_decoys.size()):
		var d: Dictionary = _decoys[i]
		if tap_pos.distance_to(d["pos"]) <= target_radius:
			_on_decoy_hit(tap_pos, i)
			return

	# Check real target
	if _target_active:
		var dist: float = tap_pos.distance_to(_target_pos)
		if dist <= target_radius:
			_on_hit(tap_pos, dist)
		else:
			_on_miss_tap(tap_pos)
	# Tapping empty space in a no-real round: no penalty

func _on_hit(tap_pos: Vector2, dist: float) -> void:
	var reaction_ms: int = int(game.game_time - _round_shown_time_ms)
	_reaction_times.append(reaction_ms)
	_accuracies.append(int(dist))
	while _reaction_times.size() > 20:
		_reaction_times.remove_at(0)
		_accuracies.remove_at(0)
	var score_bonus: int = max(1, 20 - reaction_ms / 200)
	game.add_score_and_time(score_bonus, 10)
	game.add_correct_or_mistake(1, 0)
	num_corrects_in_level_so_far += 1
	_flash_at(tap_pos, Color(0.2, 0.9, 0.3, 0.6))
	_target_active = false
	_round_active = false
	_decoys.clear()
	game.play_sound("hit")
	_draw_area.queue_redraw()
	if num_corrects_in_level_so_far >= corrects_for_next_level:
		_level_done(true)
	else:
		_schedule_next_target()

func _on_decoy_hit(tap_pos: Vector2, decoy_idx: int) -> void:
	_decoys.remove_at(decoy_idx)
	game.add_score_and_time(-5, -5)
	game.add_correct_or_mistake(0, 1)
	_flash_at(tap_pos, Color(0.9, 0.2, 0.2, 0.5))
	_draw_area.queue_redraw()

func _on_miss_tap(tap_pos: Vector2) -> void:
	game.add_score_and_time(-3, -3)
	game.add_correct_or_mistake(0, 1)
	_flash_at(tap_pos, Color(0.9, 0.2, 0.2, 0.5))
	_draw_area.queue_redraw()

func _flash_at(pos: Vector2, color: Color) -> void:
	_flash_color = color
	_flash_alpha = 1.0
	_flash_pos = pos

func _level_done(didwin: bool) -> void:
	game.level_is_done = true
	game.sig_level_is_done.emit(didwin)
	if didwin:
		MainGlobals.global_level_is_done(true)
		if level >= max_difficulty:
			sig_level_is_done.emit(true)
		else:
			game.need_to_increase_level = true
			if not MainGlobals.sig_level_done_popup_closed.is_connected(_on_level_done_popup_closed):
				MainGlobals.sig_level_done_popup_closed.connect(_on_level_done_popup_closed)
			var avg_ms: int = mean_reaction_ms()
			var avg_dist: int = mean_distance_px()
			var textadd: String = "\n\nAvg reaction: %d ms\nAvg distance: %d px" % [avg_ms, avg_dist]
			game.show_level_done_popup(self, "", "", level, textadd)
	else:
		sig_level_is_done.emit(false)

func _on_level_done_popup_closed() -> void:
	sig_level_is_done.emit(true)

func _on_time_over() -> void:
	_target_active = false
	_round_active = false
	_decoys.clear()
	_draw_area.queue_redraw()

func tick() -> void:
	pass

func get_draw_state() -> Dictionary:
	var age: float = 0.0
	if _round_active and show_target_ms > 0.0:
		age = clamp((game.game_time - _round_shown_time_ms) / show_target_ms, 0.0, 1.0)

	var targets: Array = []
	if _target_active:
		targets.append({
			"pos": _target_pos,
			"radius": target_radius,
			"color": _target_color,
			"age": age,
			"draw_dot": true,
		})
	for d in _decoys:
		targets.append({
			"pos": d["pos"],
			"radius": target_radius,
			"color": d["color"],
			"age": age,
			"draw_dot": d["draw_dot"],
		})

	return {
		"targets": targets,
		"target_radius": target_radius,
		"flash_color": _flash_color,
		"flash_alpha": _flash_alpha,
		"flash_pos": _flash_pos,
	}

func mean_reaction_ms(exclude_last: bool = false) -> int:
	if _reaction_times.size() == 0:
		return 9999
	var data: Array = _reaction_times
	if exclude_last and data.size() > 1:
		data = data.slice(0, data.size() - 1)
	var s: int = 0
	for t in data:
		s += t
	return int(float(s) / float(data.size()))

func mean_distance_px(exclude_last: bool = false) -> int:
	if _accuracies.size() == 0:
		return 0
	var data: Array = _accuracies
	if exclude_last and data.size() > 1:
		data = data.slice(0, data.size() - 1)
	var s: int = 0
	for a in data:
		s += a
	return int(float(s) / float(data.size()))
