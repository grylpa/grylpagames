extends CanvasLayer
class_name TutorialRunner

# The coach overlay: a caption panel that speaks over a LIVE game, optionally spotlighting what it
# is talking about, and either waiting for a tap or waiting for the player to actually do the thing.
#
# The one trick that makes this work across all 37 games without touching them:
#
#     MainGlobals.set_visible("tutorial", true)  ->  game.paused() == true
#
# Every game's `_can_play()` already checks `game.paused()`, and so does the HUD countdown
# (generic_game_hud.gd), so registering as a visible screen freezes the board AND the clock. And
# because `paused()` accumulates _total_paused_ms, `game_time`-based timers (card deadlines,
# animation phases) resume without jumping. We register only while the coach is TALKING, and
# deregister while the player is acting.
#
# Built in code rather than as a .tscn, following scripts/about_screen.gd — there is no scene state
# worth editing in the editor, and it keeps the whole thing readable in one file.
#
# See docs/tutorials.md for the step schema and the recipe for adding a game.

signal finished(completed: bool)

const LAYER: int = 120                      # under PopupText's 128 blocker
const DIM_COLOR: Color = Color(0, 0, 0, 0.62)
const SPOT_COLOR: Color = Color(1.0, 0.82, 0.15, 1.0)
const PANEL_BG: Color = Color(0.09, 0.13, 0.10, 0.96)
const TEXT_COLOR: Color = Color(1, 1, 1, 1)
const HINT_COLOR: Color = Color(1.0, 0.82, 0.15, 1.0)
const SPOT_PAD: float = 10.0
const DEFAULT_SPOT_RADIUS: float = 60.0
const PANEL_MARGIN: float = 12.0
const PAD_X: float = 18.0        # caption inner padding, left/right
const PAD_Y: float = 14.0        # caption inner padding, top/bottom
const VBOX_SEP: int = 6
const MAX_PANEL_FRAC: float = 0.55   # caption never eats more than this much of the screen

var _steps: Array = []
var _idx: int = -1
var _on_done: Callable = Callable()
var _game = null

var _dim: Control = null
var _panel: Panel = null
var _vbox: VBoxContainer = null
var _title_label: Label = null
var _skip_btn: Button = null
var _text_label: Label = null
var _foot_label: Label = null

var _spot_rect: Rect2 = Rect2()
var _has_spot: bool = false
var _blocking: bool = true
var _step_elapsed: float = 0.0
var _hint_shown: bool = false
var _await_event: String = ""
var _await_timeout: float = 0.0
var _finished: bool = false
var _pulse: float = 0.0
var _demo_pts: PackedVector2Array = PackedVector2Array()
# A step's `setup` can cause the very event that step is waiting for — gorilla's setup spawns the
# gorilla the step then waits to be told about. Events arriving during setup are parked here and
# applied once the step is fully entered; otherwise they are dropped and the step waits forever
# for something that already happened.
var _entering: bool = false
var _pending_event: String = ""

# --- Lifecycle --------------------------------------------------------------

func run(parent: Node, steps: Array, game_util, on_done: Callable = Callable()) -> void:
	_steps = steps
	_game = game_util
	_on_done = on_done
	layer = LAYER
	if get_parent() == null:
		parent.add_child(self)
	if _game != null:
		# The runner owns the non-scoring lifecycle so the two can never come apart: a tutorial
		# that forgot begin_tutorial() would both save scores AND silently drop every
		# tutorial_notify (which no-ops outside tutorial mode), and it would look like it worked.
		if not _game.tutorial_mode:
			_game.begin_tutorial()
		_game.tutorial_runner = self
	_build()
	_enter_step(0)

func _build() -> void:
	var is_mob: bool = MainGlobals.is_mobile()

	_dim = Control.new()
	_dim.name = "Dim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.draw.connect(_draw_dim)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	# A plain Panel, NOT a PanelContainer. A Container clamps its size to its combined minimum,
	# and an auto-wrapping Label reports a nonsense minimum height until it has been given a
	# width — which put the caption at y=-1952 with height 2644, i.e. entirely off-screen, so
	# all the player saw was the dim layer. Here the height is measured from the font directly
	# (see _measured_height) and nothing can override it.
	_panel = Panel.new()
	_panel.name = "Caption"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = SPOT_COLOR
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", VBOX_SEP)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_vbox)
	var vbox: VBoxContainer = _vbox

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30 if is_mob else 22)
	_title_label.add_theme_color_override("font_color", SPOT_COLOR)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 26 if is_mob else 19)
	_text_label.add_theme_color_override("font_color", TEXT_COLOR)
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_text_label)

	_foot_label = Label.new()
	_foot_label.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	_foot_label.add_theme_color_override("font_color", HINT_COLOR)
	_foot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_foot_label)

	# A way OUT, on every step. Without it the only escape from a tutorial started by accident was
	# to back out to the game chooser. Added after the caption so it draws on top, and it takes
	# input in its own right — on a doing step the dim layer ignores input entirely, so a button
	# parented to the dim would be dead exactly when the player is most likely to want it.
	_skip_btn = Button.new()
	_skip_btn.name = "SkipTutorial"
	_skip_btn.text = "Skip tutorial"
	_skip_btn.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_skip_btn.add_theme_color_override(state, Color(1, 1, 1, 0.92))
	_skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skip_btn.focus_mode = Control.FOCUS_NONE
	var sb_skip: StyleBoxFlat = StyleBoxFlat.new()
	sb_skip.bg_color = Color(0, 0, 0, 0.55)
	sb_skip.set_corner_radius_all(14)
	sb_skip.set_border_width_all(2)
	sb_skip.border_color = Color(1, 1, 1, 0.45)
	sb_skip.content_margin_left = 14.0
	sb_skip.content_margin_right = 14.0
	sb_skip.content_margin_top = 6.0
	sb_skip.content_margin_bottom = 6.0
	var sb_skip_hi: StyleBoxFlat = sb_skip.duplicate() as StyleBoxFlat
	sb_skip_hi.bg_color = Color(0.25, 0.25, 0.25, 0.8)
	_skip_btn.add_theme_stylebox_override("normal", sb_skip)
	_skip_btn.add_theme_stylebox_override("hover", sb_skip_hi)
	_skip_btn.add_theme_stylebox_override("pressed", sb_skip_hi)
	_skip_btn.add_theme_stylebox_override("focus", sb_skip)
	_skip_btn.pressed.connect(_on_skip_pressed)
	add_child(_skip_btn)
	_layout_skip()

# Top-right, clear of the app header.
func _layout_skip() -> void:
	if _skip_btn == null:
		return
	var screen: Vector2 = Vector2(MainGlobals.screen_size)
	var sz: Vector2 = _skip_btn.get_combined_minimum_size()
	_skip_btn.size = sz
	_skip_btn.position = Vector2(screen.x - sz.x - PANEL_MARGIN,
		float(_game.header_height if _game != null else 60) + 6.0)

func _on_skip_pressed() -> void:
	abort()

# --- Step machine -----------------------------------------------------------

func _enter_step(i: int) -> void:
	_idx = i
	if _idx >= _steps.size():
		_finish(true)
		return
	var step: Dictionary = _steps[_idx]

	# Work out what this step waits for FIRST, so an event caused by its own setup is recognized
	# rather than discarded.
	_await_event = ""
	_await_timeout = 0.0
	var await_spec = step.get("await", null)
	if await_spec is String:
		_await_event = await_spec
	elif await_spec is Dictionary:
		_await_event = String(await_spec.get("event", ""))
		_await_timeout = float(await_spec.get("timeout", 0.0))

	# Talking steps freeze the game and eat input; doing steps let the player play underneath.
	_blocking = _await_event.is_empty()

	# `setup` stages the situation this step needs to teach (force the next card to repeat, spawn
	# the gorilla to point at, send an alien to the gate).
	_pending_event = ""
	_entering = true
	if step.has("setup"):
		var setup_call: Callable = step["setup"]
		if setup_call.is_valid():
			setup_call.call()
	_entering = false
	_set_frozen(_blocking)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP if _blocking else Control.MOUSE_FILTER_IGNORE

	_step_elapsed = 0.0
	_hint_shown = false
	_title_label.text = _resolve_text(step.get("title", ""))
	_title_label.visible = not _title_label.text.is_empty()
	_text_label.text = _resolve_text(step.get("text", ""))
	_update_footer()
	_update_spot()
	_update_demo_path()
	_layout_panel()
	_dim.queue_redraw()

	# The setup already satisfied this step (e.g. it spawned the thing the step waits to hear
	# about). Move on now rather than sitting out the timeout.
	if not _blocking and not _pending_event.is_empty() and _pending_event == _await_event:
		_pending_event = ""
		_advance()

# A step's text may be a plain String or a Callable returning one. The Callable form is evaluated
# when the step OPENS, which is the only way a caption can name something the game decided at run
# time — the actual rule on the gate, the amount being asked for, the color that came up. Getting
# that wrong is worse than saying nothing: aliens once announced "this one matches" over an alien
# that plainly did not match the pass on screen.
func _resolve_text(v) -> String:
	if v is Callable:
		if not v.is_valid():
			return ""
		var out = v.call()
		return "" if out == null else String(out)
	return String(v)

func _update_footer() -> void:
	var parts: Array = []
	if _steps.size() > 1:
		parts.append("%d/%d" % [_idx + 1, _steps.size()])
	if _blocking:
		parts.append("tap to continue")
	var line: String = "        ".join(parts)
	if _hint_shown:
		var hint: String = _resolve_text(_steps[_idx].get("hint", "Take your time — try it now."))
		line = hint if line.is_empty() else hint + "\n" + line
	_foot_label.text = line
	_foot_label.visible = not line.is_empty()

func _advance() -> void:
	_enter_step(_idx + 1)

# A game reports that something happened, via game.tutorial_notify("...").
func notify(event_name: String) -> void:
	if _finished:
		return
	if _entering:
		# Mid-_enter_step: park it, do not re-enter the step machine from inside itself.
		if event_name == _await_event:
			_pending_event = event_name
		return
	if _blocking or _await_event.is_empty():
		return
	if event_name == _await_event:
		_advance()

func abort() -> void:
	_finish(false)

func _finish(completed: bool) -> void:
	if _finished:
		return
	_finished = true
	_set_frozen(false)
	# Records completion (and clears the "running" marker either way), so the How-to-play list can
	# drop a tutorial you have already finished to the bottom.
	MainGlobals.mark_tutorial_done(completed)
	if _game != null:
		_game.tutorial_runner = null
		# Restore the real session BEFORE the callback, so whoever resumes the game sees the
		# player's own state rather than the tutorial's.
		_game.end_tutorial()
	if _on_done.is_valid():
		_on_done.call(completed)
	finished.emit(completed)
	queue_free()

func _exit_tree() -> void:
	# Torn down some other way — scene change, chooser back-out, queue_free from elsewhere. Leaving
	# the app frozen would be bad; leaving `tutorial_mode` stuck true would be far worse, because
	# every guard in generic_game_util.gd would go on suppressing the player's REAL scores.
	_set_frozen(false)
	if not _finished and _game != null:
		_game.tutorial_runner = null
		_game.end_tutorial()
		_finished = true

func _set_frozen(frozen: bool) -> void:
	MainGlobals.set_visible("tutorial", frozen)

# --- Per-frame --------------------------------------------------------------

func _process(dt: float) -> void:
	if _finished or _idx < 0 or _idx >= _steps.size():
		return
	_step_elapsed += dt
	_pulse += dt

	if not _blocking and _await_timeout > 0.0 and _step_elapsed >= _await_timeout:
		_advance()
		return

	if not _hint_shown:
		var hint_after: float = float(_steps[_idx].get("hint_after", 0.0))
		if hint_after > 0.0 and _step_elapsed >= hint_after:
			_hint_shown = true
			_update_footer()
			_layout_panel()

	# Re-evaluated every frame so the spotlight tracks a moving target.
	var was: Rect2 = _spot_rect
	_update_spot()
	if was != _spot_rect:
		_layout_panel()
	if _has_spot or not _demo_pts.is_empty():
		_dim.queue_redraw()

func _input(event: InputEvent) -> void:
	if _finished:
		return
	# ESC leaves the tutorial, on any step — the keyboard equivalent of the Skip button.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		abort()
		return
	if not _blocking:
		return
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _on_dim_input(event: InputEvent) -> void:
	if _finished or not _blocking:
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		_advance()
		_dim.accept_event()

# --- Spotlight --------------------------------------------------------------

func _update_spot() -> void:
	_has_spot = false
	if _idx < 0 or _idx >= _steps.size():
		return
	var step: Dictionary = _steps[_idx]
	if not step.has("spot"):
		return
	var target = step["spot"]
	if target is Callable:
		if not target.is_valid():
			return
		target = target.call()
	var rect: Rect2 = _rect_for(target, float(step.get("spot_radius", DEFAULT_SPOT_RADIUS)))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_spot_rect = rect.grow(float(step.get("spot_pad", SPOT_PAD)))
	_has_spot = true

# Accepts a Rect2, a Vector2 center, a Control, or any CanvasItem (Node2D) — all resolved to
# SCREEN coordinates, because a Node2D under a zoomed camera does not live in screen space.
func _rect_for(target, radius: float) -> Rect2:
	if target is Rect2:
		return target
	if target is Vector2:
		return Rect2(target - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	if target is Control and is_instance_valid(target):
		return (target as Control).get_global_rect()
	if target is CanvasItem and is_instance_valid(target):
		var center: Vector2 = (target as CanvasItem).get_global_transform_with_canvas().origin
		return Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	return Rect2()

# A step may carry `demo_path`: a Callable returning screen points. The overlay traces them with a
# traveling dot, so a gesture the player has never met can be SHOWN rather than described. Words
# alone were not getting "you can draw a route for the dog to walk" across.
func _update_demo_path() -> void:
	_demo_pts = PackedVector2Array()
	if _idx < 0 or _idx >= _steps.size():
		return
	var spec = _steps[_idx].get("demo_path", null)
	if spec == null:
		return
	if spec is Callable:
		if not spec.is_valid():
			return
		spec = spec.call()
	if spec is PackedVector2Array:
		_demo_pts = spec
	elif spec is Array:
		for pt in spec:
			if pt is Vector2:
				_demo_pts.append(pt)

func _draw_demo_path() -> void:
	if _demo_pts.size() < 2:
		return
	var trail: Color = Color(SPOT_COLOR.r, SPOT_COLOR.g, SPOT_COLOR.b, 0.55)
	_dim.draw_polyline(_demo_pts, trail, 5.0, true)
	# Total length, so the dot travels at a constant speed rather than per-segment.
	var seg_len: Array = []
	var total: float = 0.0
	for i in range(_demo_pts.size() - 1):
		var d: float = _demo_pts[i].distance_to(_demo_pts[i + 1])
		seg_len.append(d)
		total += d
	if total <= 0.0:
		return
	# Two halves per cycle: the finger draws the route (t 0..1), then the character walks the same
	# route (t 1..2), then a pause. Cause and effect, in that order.
	var cycle: float = 4.6
	var phase: float = fmod(_pulse, cycle)
	var t: float = phase / 1.8 if phase < 1.8 else (1.0 + clampf((phase - 2.1) / 1.8, 0.0, 1.0))
	var traveled: float = clampf(fmod(t, 1.0) if t > 1.0 else t, 0.0, 1.0) * total
	if t >= 2.0:
		traveled = total
	var pos: Vector2 = _demo_pts[_demo_pts.size() - 1]
	var acc: float = 0.0
	for i in seg_len.size():
		if traveled <= acc + seg_len[i]:
			var f: float = (traveled - acc) / maxf(seg_len[i], 0.001)
			pos = _demo_pts[i].lerp(_demo_pts[i + 1], f)
			break
		acc += seg_len[i]
	_dim.draw_circle(_demo_pts[0], 9.0, trail, false, 3.0, true)
	# The finger doing the drawing, then the character following it. Showing only a dot left it
	# ambiguous whether the dot WAS the character or the gesture; drawing both, one after the
	# other, is what makes it read as "you swipe, then it walks".
	if t <= 1.0:
		_draw_hand(pos)
	else:
		_dim.draw_circle(pos, 11.0, SPOT_COLOR, true, -1.0, true)
		_dim.draw_arc(pos, 16.0, 0.0, TAU, 24, Color(SPOT_COLOR.r, SPOT_COLOR.g, SPOT_COLOR.b, 0.5), 2.0, true)

# A simple pointing hand, drawn rather than typeset so it does not depend on an emoji font being
# present (and cannot be resized into a blob by one).
func _draw_hand(at: Vector2) -> void:
	var ink: Color = Color(1, 1, 1, 0.95)
	var edge: Color = Color(0.1, 0.1, 0.1, 0.9)
	# palm
	var palm: Rect2 = Rect2(at + Vector2(-7.0, -2.0), Vector2(14.0, 15.0))
	_dim.draw_rect(palm, ink, true)
	_dim.draw_rect(palm, edge, false, 1.5)
	# index finger, pointing up at the path
	var finger: Rect2 = Rect2(at + Vector2(-3.0, -15.0), Vector2(6.0, 15.0))
	_dim.draw_rect(finger, ink, true)
	_dim.draw_rect(finger, edge, false, 1.5)
	# contact point
	_dim.draw_circle(at + Vector2(0.0, -15.0), 4.0, SPOT_COLOR, true, -1.0, true)

func _draw_dim() -> void:
	var full: Rect2 = Rect2(Vector2.ZERO, _dim.size)
	if not _has_spot:
		# On a doing step we must not dim — the player is looking at the board and playing on it.
		if _blocking:
			_dim.draw_rect(full, DIM_COLOR)
		_draw_demo_path()
		return
	var hole: Rect2 = _spot_rect
	if _blocking:
		# Four rects around the hole, so the spotlighted thing stays at full brightness.
		_dim.draw_rect(Rect2(0, 0, full.size.x, hole.position.y), DIM_COLOR)
		_dim.draw_rect(Rect2(0, hole.end.y, full.size.x, full.size.y - hole.end.y), DIM_COLOR)
		_dim.draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), DIM_COLOR)
		_dim.draw_rect(Rect2(hole.end.x, hole.position.y, full.size.x - hole.end.x, hole.size.y),
			DIM_COLOR)
	var alpha: float = 0.55 + 0.45 * absf(sin(_pulse * 3.0))
	var ring: Color = Color(SPOT_COLOR.r, SPOT_COLOR.g, SPOT_COLOR.b, alpha)
	_dim.draw_rect(hole, ring, false, 3.0)
	_draw_demo_path()

# --- Caption placement ------------------------------------------------------

func _layout_panel() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(MainGlobals.screen_size)
	# The app's own bottom bar sits below everything and must stay reachable.
	var bottom_bar: float = 70.0 if MainGlobals.is_mobile() else 44.0
	# Never let this go negative — a negative Rect2 size makes intersects() fail outright.
	var avail_w: float = maxf(screen.x - 2.0 * PANEL_MARGIN, 1.0)
	var inner_w: float = maxf(avail_w - 2.0 * PAD_X, 1.0)
	# Wrapping happens at inner_w, so pin the labels there before measuring at the same width.
	for lbl: Label in [_title_label, _text_label, _foot_label]:
		lbl.custom_minimum_size.x = inner_w
	var panel_h: float = minf(_measured_height(inner_w), screen.y * MAX_PANEL_FRAC)
	_vbox.position = Vector2(PAD_X, PAD_Y)
	_vbox.size = Vector2(inner_w, maxf(panel_h - 2.0 * PAD_Y, 1.0))

	var low_limit: float = screen.y - bottom_bar - PANEL_MARGIN     # lowest the caption may reach
	var bottom_y: float = low_limit - panel_h
	var top_y: float = float(_game.header_height if _game != null else 60) + PANEL_MARGIN
	var y: float = bottom_y
	if _has_spot:
		# Put the caption in whichever gap around the spotlight it actually fits in. Simply
		# flipping bottom->top is not enough: a target near the middle of the screen (a gorilla
		# held mid-lane on a vertical run, say) clips BOTH ends, and the old fallback then chose
		# bottom regardless and sat on top of the very thing it was pointing at.
		var gap_above: float = _spot_rect.position.y - top_y
		var gap_below: float = low_limit - _spot_rect.end.y
		if gap_below >= panel_h:
			y = bottom_y
		elif gap_above >= panel_h:
			y = _spot_rect.position.y - PANEL_MARGIN - panel_h
		elif gap_above >= gap_below:
			# Neither gap fits: take the roomier one and sit flush against the spotlight, so the
			# overlap is as small as the screen allows rather than as large.
			y = maxf(top_y, _spot_rect.position.y - panel_h)
		else:
			y = minf(bottom_y, _spot_rect.end.y)
	_panel.position = Vector2(PANEL_MARGIN, y)
	_panel.size = Vector2(avail_w, panel_h)

# The caption's height, computed from the font rather than asked of a container. Font metrics are
# available immediately, so the caption is correctly placed on the very first frame it appears —
# no waiting for a layout pass, and nothing to clamp it to a bogus minimum.
func _measured_height(inner_w: float) -> float:
	var total: float = 2.0 * PAD_Y
	var shown: int = 0
	for lbl: Label in [_title_label, _text_label, _foot_label]:
		var h: float = _label_height(lbl, inner_w)
		if h > 0.0:
			total += h
			shown += 1
	if shown > 1:
		total += float(VBOX_SEP * (shown - 1))
	return total

func _label_height(lbl: Label, inner_w: float) -> float:
	if lbl == null or not lbl.visible or lbl.text.is_empty():
		return 0.0
	var f: Font = lbl.get_theme_font("font")
	if f == null:
		return 0.0
	var fs: int = lbl.get_theme_font_size("font_size")
	if fs <= 0:
		fs = 16
	# Measures exactly what an auto-wrapping Label will draw at this width, including the
	# explicit \n line breaks the step texts use.
	return f.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, inner_w, fs).y
