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
const MAX_PANEL_FRAC: float = 0.55       # caption never eats more than this much of the screen
# A tutorial runs on the real level, so it inherits that level's clock — a minute or so in most
# games. Reading the captions and doing the exercises easily outlasts it, and the level ending
# mid-lesson drops a "level complete" popup over the coach. Give it far more room than any
# tutorial needs; end_tutorial() puts the player's own clock back afterwards (time_left_sec and
# _reset_time_left_sec are both in the snapshot).
const TUTORIAL_MINUTES: int = 30
# A SIDE caption is a narrow column pinned to one edge, for games whose action runs down the middle
# of the screen: udbr's lane is vertical and centered, and the ball travels its whole height, so a
# full-width caption docked at the bottom sits on top of the very thing the player is watching.
const SIDE_FRAC: float = 0.32            # of screen width
const SIDE_MIN_W: float = 150.0
const SIDE_MAX_FRAC: float = 0.80        # a narrow column wraps taller, so allow more height

var _steps: Array = []
var _idx: int = -1
var _on_done: Callable = Callable()
var _game = null

var _dim: Control = null
var _panel: Panel = null
var _title_label: Label = null
var _skip_btn: Button = null
var _text_label: Label = null
var _foot_label: Label = null

var _spot_rect: Rect2 = Rect2()
var _has_spot: bool = false
var _blocking: bool = true

# Rects the caption must not sit on while the player is playing: the controls the step is telling
# them to use. Set per game before run() — each entry is a Callable returning a Rect2, a Control,
# or null. A coach bubble that covers the tray you are told to drag coins into, or the New/Seen
# buttons you are told to press, makes the step impossible to carry out.
#
# Set it on the RUNNER (`runner.keep_clear = [...]` in the game's main.gd) for zones that hold for
# the whole tutorial, or per STEP (`"keep_clear": [...]`) for zones that only matter to that step.
# A step that names its own list replaces the runner's for as long as it is up; a step that does
# not, inherits it.
var keep_clear: Array = []
# The runner-level list, kept so a per-step list can be a temporary override rather than a
# permanent one.
var _base_keep_clear: Array = []
const KEEP_CLEAR_PAD: float = 6.0
# How long the caption stays put after being moved out of the spotlight's way.
const SPOT_FOLLOW_COOLDOWN_MS: int = 700
var _moved_for_spot_ms: int = -100000
var _step_elapsed: float = 0.0
var _diag_ticks: int = 0
var _host: Node = null
var _hint_shown: bool = false
var _await_event: String = ""
var _await_timeout: float = 0.0
var _finished: bool = false
var _pulse: float = 0.0
# How long one breath of the spotlight takes, and how far its halo travels before fading out.
const SPOT_PULSE_SEC: float = 1.6
const SPOT_HALO_PX: float = 16.0
var _demo_pts: PackedVector2Array = PackedVector2Array()
# "auto" (default) = the full-width panel, bottom or top. "right" / "left" = a narrow side column.
# Set before run(); a step may override it with its own `caption_side` key.
var caption_side: String = "auto"
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
	_host = parent
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
	_base_keep_clear = keep_clear.duplicate()
	_build()
	_hold_clock()
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
	# Backstop: nothing may render outside the balloon, whatever a label decides its minimum is.
	_panel.clip_contents = true
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# NO container. A VBoxContainer clamps itself to its children's combined minimum size, and an
	# auto-wrapping Label reports a minimum computed from whatever width it happens to have — so
	# the box grew to 2223 px on the opening step and the footer ended up hanging below the
	# balloon. The three labels are positioned by hand in _layout_panel from the same measurements
	# that size the panel, which makes the layout exact and frame-independent.
	var vbox: Control = _panel

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30 if is_mob else 22)
	_title_label.add_theme_color_override("font_color", SPOT_COLOR)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Must wrap like the others. Without this a title wider than the caption ("Up Down Breathe" at
	# 30px against a 182px side column) reports its full width as its MINIMUM, the VBox grows past
	# the panel to satisfy it, and the text spills out to the right of the balloon.
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	# Zones this step in particular must not be covered by, falling back to the runner-wide list.
	var step_clear = step.get("keep_clear", null)
	keep_clear = (step_clear as Array) if step_clear is Array else _base_keep_clear

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

	_step_elapsed = 0.0
	# BEFORE _apply_dim_filter(): the filter's settle window is measured from this timestamp, so
	# applying it first computes "settling" against the step that just ended — which is always long
	# past, so the overlay dropped out of the way instantly and the second half of the dismissing
	# tap went straight through to the board.
	_step_opened_ms = Time.get_ticks_msec()
	_apply_dim_filter()
	_moved_for_spot_ms = -100000
	_hint_shown = false
	_title_label.text = _resolve_text(step.get("title", ""))
	_title_label.visible = not _title_label.text.is_empty()
	_text_label.text = _resolve_text(step.get("text", ""))
	# A step with nothing to say shows no caption at all. Some steps exist only to WAIT for the
	# game to reach a state — didi holds its round until the player taps, then needs a step that
	# simply waits for the flash — and a filler line like "here it comes" appears for a moment and
	# reads as a glitch. With no title and no text, the panel stays hidden and the player just sees
	# the game.
	_panel.visible = not (_title_label.text.is_empty() and _text_label.text.is_empty())
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
# A caption whose `title` or `text` is a Callable is re-read every frame, so it can REACT to what
# the player just did instead of being fixed when the step opened. Lights Out needs this: walking
# into a bomb during the lesson is survivable, but saying nothing about it leaves the player
# wondering why they were sent back — the caption changes to name what happened.
#
# Only a string that actually CHANGED triggers a relayout, or the caption would be re-measured and
# re-placed every frame for no reason.
func _refresh_live_text() -> void:
	if _idx < 0 or _idx >= _steps.size():
		return
	var step: Dictionary = _steps[_idx]
	var changed: bool = false
	if step.get("title", "") is Callable:
		var t: String = _resolve_text(step["title"])
		if t != _title_label.text:
			_title_label.text = t
			_title_label.visible = not t.is_empty()
			changed = true
	if step.get("text", "") is Callable:
		var x: String = _resolve_text(step["text"])
		if x != _text_label.text:
			_text_label.text = x
			changed = true
	if changed:
		_panel.visible = not (_title_label.text.is_empty() and _text_label.text.is_empty())
		_layout_panel()

func _resolve_text(v) -> String:
	if v is Callable:
		if not v.is_valid():
			return ""
		var out = v.call()
		return "" if out == null else String(out)
	return String(v)

func _update_footer() -> void:
	# No "3/12" counter. Several steps exist only to unfreeze the game and wait for it to produce
	# something ("here comes the first card", "here comes another pile"); they are satisfied within
	# a frame or two and are never really seen, so the numbers ran 1, 3, 4, 6 … and looked broken.
	# The count is not information the player needs, and any numbering that skips is worse than
	# none. (A continuous progress bar would be the way to show position, if it is ever wanted.)
	var parts: Array = []
	if _blocking:
		parts.append("tap to continue")
	var line: String = "        ".join(parts)
	if _hint_shown:
		# No default text: every step that sets `hint_after` supplies its own `hint`, and a generic
		# "take your time" nudge is worse than none — it tells the player nothing they do not know.
		var hint: String = _resolve_text(_steps[_idx].get("hint", ""))
		line = hint if line.is_empty() else hint + "\n" + line
	# TEMPORARY DIAGNOSTIC — remove once the mobile taxi stall is understood. On a DOING step the
	# game must be running; if it is paused, the board is frozen and the step can never be
	# satisfied. game.paused() is four things OR'd together, so this says which one is true.
	if not _blocking and _game != null and _game.paused():
		var why: Array = []
		if bool(_game.get("_pause")):
			why.append("_pause")
		if MainGlobals.any_screen_visible():
			why.append("screens:" + ",".join(MainGlobals.visible_screens.keys()))
		if not bool(_game.get("in_focus")):
			why.append("no focus")
		if not bool(_game.get("playing")):
			why.append("not playing")
		line = "FROZEN: " + ("  ".join(why) if not why.is_empty() else "?")
	_foot_label.text = line
	_foot_label.visible = not line.is_empty()

func _advance() -> void:
	_enter_step(_idx + 1)

# One physical tap arrives as TWO events. Godot's Input layer synthesizes a mouse button from a
# screen touch (input_devices/pointing/emulate_mouse_from_touch, on by default) and a screen touch
# from a mouse button (pointing/emulate_touch_from_mouse=true in project.godot) — so on every
# platform, one tap reaches _on_dim_input twice. accept_event() does not help: it ends propagation
# of the event it is called on, not of the twin that follows.
#
# That cost a step every time two talking steps were adjacent: the tap dismissing the first also
# dismissed the second. gorilla (steps 4-7 all talking) and wolves (7-8) simply never showed their
# last step — the tutorial ended on the tap that was meant to reveal it. Steps followed by a
# player-action step were spared, because _blocking goes false and the twin is dropped below, which
# is why the loss looked arbitrary rather than systematic.
#
# Debounced rather than filtered by event type: dropping InputEventScreenTouch outright would leave
# the tutorial undismissable on any device where mouse emulation is off. The twin lands in the same
# frame or the next, so the window only has to cover ~2 frames — keep it tight. It was 350 ms,
# which is long enough to swallow a real second press from a player tapping quickly; nothing needs
# that much, and on a touch device a swallowed press reads as the screen having gone dead.
const TAP_DEBOUNCE_MS: int = 120
var _last_tap_ms: int = -100000

# A step that has only just opened ignores taps for this long. The tap that COMPLETES a doing step
# is delivered twice (touch + the mouse event synthesized from it): the first goes to the game and
# satisfies the step, the second arrives after the next step has opened and lands on its dim, which
# dismisses it instantly. The debounce above cannot catch that pair, because the first half never
# went through the overlay at all.
#
# In Mind Palace this took the player straight from answering a color to the main menu — the
# closing step was opened and dismissed by the two halves of one tap — and only on mobile, where
# the synthesized event actually reaches the overlay.
const STEP_SETTLE_MS: int = 250
var _step_opened_ms: int = -100000

# The overlay swallows input while a caption is up, and gets out of the way on a doing step. But
# it must ALSO keep swallowing for the settle window after a step change, because one physical tap
# is two events (a touch and the mouse event synthesized from it, or vice versa): the first half
# dismisses the caption, the step advances to a doing step, the overlay drops out of the way — and
# the second half lands on the board. In Couples that read as tapping a card, so dismissing "Picked
# up" counted as choosing a wrong card.
#
# STEP_SETTLE_MS is the same window that stops the second half from advancing two steps at once;
# this is the same problem seen from the game's side rather than the overlay's.
func _apply_dim_filter() -> void:
	if _dim == null:
		return
	var settling: bool = Time.get_ticks_msec() - _step_opened_ms < STEP_SETTLE_MS
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP if (_blocking or settling) \
		else Control.MOUSE_FILTER_IGNORE

func _tap_advance() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _step_opened_ms < STEP_SETTLE_MS:
		return
	if now - _last_tap_ms < TAP_DEBOUNCE_MS:
		return
	_last_tap_ms = now
	_advance()

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
		# Silence whatever the tutorial's own session started, however it was started.
		_silence_now_and_shortly()
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
		_silence_now_and_shortly()
		_game.end_tutorial()
		_finished = true

# Silence the tutorial's session. `stop_all_sounds()` only covers sounds registered through
# GenericGameUtil.add_sound; several games instead play an AudioStreamPlayer that lives in their
# own scene (delemfp's $MotorAudio, pneumo's $DoorAudio), which that registry has never heard of.
# So the game's whole scene is walked as well.
#
# It is also run again a moment later: delemfp starts its motor from
# `MainGlobals.do_after(0.5, ...)`, so a stop at the instant the tutorial ends can be undone by a
# timer that has not fired yet.
func _silence(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
	for c in node.get_children():
		_silence(c)

func _silence_everything() -> void:
	if _game != null:
		_game.stop_all_sounds()
	_silence(_host)

func _silence_now_and_shortly() -> void:
	_silence_everything()
	var host: Node = _host
	if host != null and is_instance_valid(host):
		# Deliberately on the HOST, not on this node: the runner frees itself immediately.
		MainGlobals.do_after(0.8, func():
			if is_instance_valid(host):
				_silence(host))

func _set_frozen(frozen: bool) -> void:
	MainGlobals.set_visible("tutorial", frozen)

# --- Per-frame --------------------------------------------------------------

# Keep the level clock topped up for as long as the tutorial runs.
#
# Setting it once is not enough: several games (wolves, storm) have a new_game() that awaits a
# frame, so the level applies its OWN level time after run() has already set ours — they were left
# on a 120 s clock. Re-applying also covers a level that resets the clock part-way through.
# end_tutorial() restores the player's own values afterwards; both time_left_sec and
# _reset_time_left_sec are in the snapshot, and a real game re-derives its clock from its level
# config on the next new_game() regardless.
func _hold_clock() -> void:
	if _game == null:
		return
	var want: int = TUTORIAL_MINUTES * 60
	if _game.time_left_sec >= want - 5:
		return
	_game.set_reset_time_left(want)
	_game.set_time_left(0, TUTORIAL_MINUTES, 0)

func _process(dt: float) -> void:
	_apply_dim_filter()
	_refresh_live_text()
	if _finished or _idx < 0 or _idx >= _steps.size():
		return
	_hold_clock()
	# `tick` runs every frame the step is current. It exists so a game can repair a situation the
	# player has broken out from under a step: aliens' "drag this one IN" step is left pointing at
	# an alien that the player dragged OUT instead, and has to get another one to the gate or the
	# step waits forever on something that will never happen.
	var step_now: Dictionary = _steps[_idx]
	if step_now.has("tick"):
		var tick_call: Callable = step_now["tick"]
		if tick_call.is_valid():
			tick_call.call()
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

	# TEMPORARY DIAGNOSTIC — keep the FROZEN readout current; the footer is otherwise only rebuilt
	# when a step changes or a hint appears.
	if not _blocking and _game != null:
		_diag_ticks += 1
		if _diag_ticks % 20 == 0:
			_update_footer()

	# Re-evaluated every frame so the spotlight tracks a moving target.
	var was: Rect2 = _spot_rect
	var had_spot: bool = _has_spot
	_update_spot()
	# Only move the caption when the spotlight has actually come to sit under it, and then not
	# again for a moment. Re-laying out on every change made the caption chase a moving target
	# across the screen — an alien dragged out of the ring wanders the field, and the bubble
	# jumped after it frame by frame.
	if was != _spot_rect and _has_spot:
		var panel_rect: Rect2 = Rect2(_panel.position, _panel.size)
		var hits: Rect2 = panel_rect.intersection(_spot_rect)
		var overlapping: bool = hits.size.x > 0.0 and hits.size.y > 0.0
		var now_ms: int = Time.get_ticks_msec()
		if overlapping and now_ms - _moved_for_spot_ms >= SPOT_FOLLOW_COOLDOWN_MS:
			_moved_for_spot_ms = now_ms
			_layout_panel()
	elif was != _spot_rect:
		_layout_panel()
	_follow_keep_clear()
	# The frame going AWAY needs a redraw as much as one appearing: without this the last frame
	# drawn stayed on the canvas after the spotlight resolved to nothing, so dragging the marked
	# alien out of the ring left its marker hanging in empty space until something else happened
	# to trigger a redraw.
	if _has_spot or had_spot != _has_spot or not _demo_pts.is_empty():
		_dim.queue_redraw()

# A keep_clear zone can appear AFTER the caption has been placed. The opening caption is laid out
# before the game has finished building its board, so at that moment there is nothing to avoid —
# and the board then materializes underneath it. mmm's intro caption sat on the coin this way,
# while sixteen clean positions were available.
#
# Same discipline as the spotlight follow above: only when a zone has actually come to sit under
# the caption, only if it is properly buried (a clipped corner is not worth a jump), and never more
# often than the cooldown allows — a caption that re-places itself every frame chases the board
# around the screen.
const KEEP_CLEAR_REFLOW_FRAC: float = 0.5

func _follow_keep_clear() -> void:
	if keep_clear.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _moved_for_spot_ms < SPOT_FOLLOW_COOLDOWN_MS:
		return
	var panel_rect: Rect2 = Rect2(_panel.position, _panel.size)
	for entry in keep_clear:
		var target = entry
		if target is Callable:
			if not (target as Callable).is_valid():
				continue
			target = (target as Callable).call()
		if target == null:
			continue
		var zone: Rect2 = _rect_for(target, DEFAULT_SPOT_RADIUS)
		if zone.size.x <= 0.0 or zone.size.y <= 0.0:
			continue
		var ov: Rect2 = panel_rect.intersection(zone)
		if ov.size.x <= 0.0 or ov.size.y <= 0.0:
			continue
		if ov.get_area() / maxf(zone.get_area(), 1.0) < KEEP_CLEAR_REFLOW_FRAC:
			continue
		_moved_for_spot_ms = now_ms
		_layout_panel()
		return

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
		_tap_advance()
		get_viewport().set_input_as_handled()

func _on_dim_input(event: InputEvent) -> void:
	if _finished or not _blocking:
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		_tap_advance()
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

# A pointing hand: a closed fist with the index finger extended, fingertip ON the point being
# traced. Drawn rather than typeset so it does not depend on an emoji font being installed (and
# cannot be resized into a blob by one).
#
# It was two stacked rectangles, which at ~14px read as a featureless blob — indistinguishable from
# the dot that follows it, so the "you swipe, then it walks" sequence did not come across.
#
# Outline of a hand pointing UP, in local units, fingertip at the origin and the wrist below it.
# Down the left: finger, knuckle, thumb, heel of the palm. Along the bottom: the wrist. Up the
# right: the folded fingers as three bumps. Closed with a rounded fingertip.
const _HAND_SHAPE: Array = [
	Vector2(-3.5, 0.0), Vector2(-3.5, 13.0),          # index finger, left edge
	Vector2(-8.5, 13.5), Vector2(-11.5, 19.0),        # knuckle and thumb
	Vector2(-9.5, 26.0), Vector2(-7.5, 32.0),
	Vector2(-5.5, 37.0), Vector2(5.5, 37.0),          # heel and wrist
	Vector2(8.5, 32.0), Vector2(9.5, 25.0),           # folded fingers, three bumps
	Vector2(8.5, 19.0), Vector2(5.5, 14.5),
	Vector2(3.5, 13.0), Vector2(3.5, 0.0),            # index finger, right edge
	Vector2(0.0, -3.0),                               # rounded tip
]
const _HAND_SCALE: float = 1.25

func _draw_hand(at: Vector2) -> void:
	var ink: Color = Color(1, 1, 1, 0.97)
	var edge: Color = Color(0.08, 0.08, 0.08, 0.9)
	var pts: PackedVector2Array = PackedVector2Array()
	for v in _HAND_SHAPE:
		pts.append(at + Vector2(v) * _HAND_SCALE)
	_dim.draw_colored_polygon(pts, ink)
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	_dim.draw_polyline(closed, edge, 1.6, true)
	# the point of contact, on the path itself
	_dim.draw_circle(at, 3.5, SPOT_COLOR, true, -1.0, true)

func _draw_dim() -> void:
	var full: Rect2 = Rect2(Vector2.ZERO, _dim.size)
	if not _has_spot:
		# On a doing step we must not dim — the player is looking at the board and playing on it.
		if _blocking:
			for r in dim_rects(full, _holes()):
				_dim.draw_rect(r, DIM_COLOR)
		_draw_demo_path()
		return
	var hole: Rect2 = _spot_rect
	if _blocking:
		for r in dim_rects(full, _holes()):
			_dim.draw_rect(r, DIM_COLOR)
	# The frame has to pull the eye by itself. A caption saying "this is your money" is usually at
	# the other end of the screen from the thing it names, and a steady 3px outline that only dips
	# to 55% opacity does not read as "look over here" — players kept reading the words without
	# ever finding what they pointed at.
	#
	# So: the frame breathes between faint and solid over SPOT_PULSE_SEC, thickening as it
	# brightens, and a second ring expands out of it and fades away — the standard attention pulse.
	# Slow on purpose; a fast blink next to a caption you are trying to read is worse than none.
	var cyc: float = fmod(_pulse, SPOT_PULSE_SEC) / SPOT_PULSE_SEC        # 0..1, sawtooth
	var breathe: float = 0.5 + 0.5 * sin(_pulse * TAU / SPOT_PULSE_SEC)   # 0..1, smooth
	var ring: Color = Color(SPOT_COLOR.r, SPOT_COLOR.g, SPOT_COLOR.b, 0.3 + 0.7 * breathe)
	_dim.draw_rect(hole, ring, false, 3.0 + 2.0 * breathe)
	var halo: Color = Color(SPOT_COLOR.r, SPOT_COLOR.g, SPOT_COLOR.b, (1.0 - cyc) * 0.45)
	_dim.draw_rect(hole.grow(SPOT_HALO_PX * cyc), halo, false, 2.0)
	_draw_demo_path()

# Regions that stay at full brightness on EVERY talking step, not just the one that points at
# them. A game's HUD is at a low CanvasLayer and the overlay is at 120, so anything the player is
# supposed to be reading off the HUD — Delem FP and Deliverem's dispatcher line, "Deliver to 2,3" —
# spends the whole tutorial under the dim, unreadable, except on the single step whose spotlight
# happens to fall on it. Part of learning the game is learning WHERE that information appears.
#
# Same accepted types as `spot` and `keep_clear`: Callables returning a Rect2, a Control, or null.
var never_dim: Array = []

# Everything that must stay bright: the spotlight, plus the always-clear regions.
func _holes() -> Array:
	var out: Array = []
	if _has_spot:
		out.append(_spot_rect)
	for entry in never_dim:
		var target = entry
		if target is Callable:
			if not (target as Callable).is_valid():
				continue
			target = (target as Callable).call()
		if target == null:
			continue
		var r: Rect2 = _rect_for(target, DEFAULT_SPOT_RADIUS)
		if r.size.x > 0.0 and r.size.y > 0.0:
			out.append(r.grow(4.0))
	return out

# The dim, as a set of rectangles that covers `full` except for the holes.
#
# It CANNOT be painted as one rect with the holes cleared afterwards: the dim is a translucent
# color composited over the game, so drawing transparent pixels on top of it changes nothing.
# The holes have to be left unpainted in the first place. Slicing on every hole edge and skipping
# the cells that land inside a hole handles any number of holes; the old code special-cased
# exactly one (four rects around it), which is the same result when there is only the spotlight.
static func dim_rects(full: Rect2, holes: Array) -> Array:
	if holes.is_empty():
		return [full]
	var xs: Array = [full.position.x, full.end.x]
	var ys: Array = [full.position.y, full.end.y]
	for h in holes:
		var r: Rect2 = h
		for v in [r.position.x, r.end.x]:
			if v > full.position.x and v < full.end.x and not (v in xs):
				xs.append(v)
		for v2 in [r.position.y, r.end.y]:
			if v2 > full.position.y and v2 < full.end.y and not (v2 in ys):
				ys.append(v2)
	xs.sort()
	ys.sort()
	var out: Array = []
	for i in range(xs.size() - 1):
		for j in range(ys.size() - 1):
			var cell: Rect2 = Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			if cell.size.x <= 0.0 or cell.size.y <= 0.0:
				continue
			var c: Vector2 = cell.get_center()
			var inside: bool = false
			for h2 in holes:
				if (h2 as Rect2).has_point(c):
					inside = true
					break
			if not inside:
				out.append(cell)
	return out

# --- Caption placement ------------------------------------------------------

# Which placement this step wants: its own `caption_side` if it has one, else the runner default.
func _effective_side() -> String:
	if _idx >= 0 and _idx < _steps.size():
		var s = _steps[_idx].get("caption_side", "")
		if s is String and not (s as String).is_empty():
			return String(s)
	return caption_side

func _layout_panel() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(MainGlobals.screen_size)
	# The app's own bottom bar sits below everything and must stay reachable.
	var bottom_bar: float = 70.0 if MainGlobals.is_mobile() else 44.0
	var side: String = _effective_side()
	var is_side: bool = side == "right" or side == "left"

	# Never let this go negative — a negative Rect2 size makes intersects() fail outright.
	var avail_w: float
	if is_side:
		avail_w = clampf(maxf(screen.x * SIDE_FRAC, SIDE_MIN_W), 1.0,
			maxf(screen.x - 2.0 * PANEL_MARGIN, 1.0))
	else:
		avail_w = maxf(screen.x - 2.0 * PANEL_MARGIN, 1.0)
	var inner_w: float = maxf(avail_w - 2.0 * PAD_X, 1.0)
	# Wrapping happens at inner_w, so pin the labels there before measuring at the same width.
	for lbl: Label in [_title_label, _text_label, _foot_label]:
		lbl.custom_minimum_size.x = inner_w
	var frac: float = SIDE_MAX_FRAC if is_side else MAX_PANEL_FRAC
	var panel_h: float = minf(_measured_height(inner_w), screen.y * frac)
	_place_labels(inner_w)

	var low_limit: float = screen.y - bottom_bar - PANEL_MARGIN     # lowest the caption may reach
	var bottom_y: float = low_limit - panel_h
	var top_y: float = float(_game.header_height if _game != null else 60) + PANEL_MARGIN
	# Keep clear of the Skip button in the top-right corner. It is NOT decoration: it draws over
	# the caption and takes input in its own right, while a talking step is dismissed by tapping
	# ANYWHERE — so a caption reaching under it turns "tap to continue" into "quit the tutorial"
	# for anyone who taps the top-right of the bubble. A full-width caption spans the button's
	# columns by definition, so it always has to be pushed below; a side caption only when it is
	# the right-hand column. The default top_y is header (60) + margin (12) = 72 against a button
	# at 66..97, so every top-placed caption in the app overlapped it: eight tutorials, sixteen
	# steps.
	if _skip_btn != null and (not is_side or side == "right"):
		top_y = maxf(top_y, _skip_btn.position.y + _skip_btn.size.y + 8.0)
	if is_side:
		panel_h = minf(panel_h, maxf(low_limit - top_y, 1.0))
		var x_side: float = (screen.x - avail_w - PANEL_MARGIN) if side == "right" else PANEL_MARGIN
		var y_side: float = top_y + maxf(low_limit - top_y - panel_h, 0.0) * 0.5
		if _has_spot:
			var here: Rect2 = Rect2(x_side, y_side, avail_w, panel_h)
			if here.intersects(_spot_rect):
				# Slide up or down within the column, whichever side of the spotlight has room.
				var above: float = _spot_rect.position.y - top_y
				var below: float = low_limit - _spot_rect.end.y
				if below >= panel_h:
					y_side = low_limit - panel_h
				elif above >= panel_h:
					y_side = _spot_rect.position.y - panel_h
		_panel.position = Vector2(x_side, y_side)
		_panel.size = Vector2(avail_w, panel_h)
		return

	var y: float = _best_y(_obstacles(), top_y, low_limit, panel_h, bottom_y, avail_w)
	_panel.position = Vector2(PANEL_MARGIN, y)
	_panel.size = Vector2(avail_w, panel_h)

# Everything the caption should stay off: the spotlight always (pointing at something and then
# covering it is the one thing a coach must never do), plus `keep_clear` while the player is
# playing.
# Covering the spotlight is worse than covering a keep-clear zone, so it costs more per pixel.
# Without this the two are weighed equally, and since the spotlight is usually ALSO one of the
# keep-clear zones (the thing being pointed at is normally the thing to be used), the same area
# gets counted twice and the placer will happily sit on the subject of its own caption to spare
# some other zone. Delem FP hit this: the caption docked across the top of the dock it was
# sending the truck to, because moving off it would have covered the truck instead.
const SPOT_COST_WEIGHT: float = 8.0

func _obstacles() -> Array:
	var out: Array = []
	if _has_spot:
		out.append({"rect": _spot_rect, "weight": SPOT_COST_WEIGHT})
	# keep_clear counts on TALKING steps too, not just when the player has the controls. It began
	# as "what must stay reachable", but a caption that buries the thing the coach is describing is
	# just as broken when the board is frozen — Delem FP's caption sat squarely on the truck while
	# telling the player to work out a route from it. Weighting (above) is what keeps this from
	# pushing a caption onto its own spotlight instead.
	for entry in keep_clear:
		var target = entry
		if target is Callable:
			if not (target as Callable).is_valid():
				continue
			target = (target as Callable).call()
		if target == null:
			continue
		var rect: Rect2 = _rect_for(target, DEFAULT_SPOT_RADIUS)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			out.append({"rect": rect.grow(KEEP_CLEAR_PAD), "weight": 1.0})
	return out

# Where to dock a full-width caption so it covers as little as possible of what matters.
#
# Candidates are the natural bottom dock plus, for each obstacle, flush above and flush below it;
# the winner is whichever overlaps the obstacles least, ties going to the lowest (captions read
# better near the bottom, and that is where every tutorial started out). The panel is never
# shrunk to fit — a clipped instruction is worse than an overlapping one.
#
# This replaced a spotlight-only rule that only ever flipped bottom->top. It could not express
# "clear of the spotlight AND clear of the tray", which is what change needs on the step that says
# to put coins in the tray, and it sat on the tray 94%% of the time.
func _best_y(obstacles: Array, top_y: float, low_limit: float, panel_h: float,
		bottom_y: float, panel_w: float) -> float:
	if obstacles.is_empty():
		return bottom_y
	var lowest: float = maxf(low_limit - panel_h, top_y)
	var cands: Array = [clampf(bottom_y, top_y, lowest), top_y]
	for r in obstacles:
		var rect: Rect2 = r["rect"]
		cands.append(clampf(rect.position.y - PANEL_MARGIN - panel_h, top_y, lowest))
		cands.append(clampf(rect.end.y + PANEL_MARGIN, top_y, lowest))
	var best_y: float = cands[0]
	var best_cost: float = INF
	for c in cands:
		var cy: float = c
		var here: Rect2 = Rect2(PANEL_MARGIN, cy, maxf(panel_w, 1.0), panel_h)
		var cost: float = 0.0
		for r2 in obstacles:
			var ov: Rect2 = here.intersection(r2["rect"])
			if ov.size.x > 0.0 and ov.size.y > 0.0:
				cost += ov.get_area() * float(r2["weight"])
		# Ties go to the lower position.
		if cost < best_cost - 0.5 or (absf(cost - best_cost) <= 0.5 and cy > best_y):
			best_cost = cost
			best_y = cy
	return best_y

# The caption's height, computed from the font rather than asked of a container. Font metrics are
# available immediately, so the caption is correctly placed on the very first frame it appears —
# no waiting for a layout pass, and nothing to clamp it to a bogus minimum.
# Stack the labels top-down inside the panel using the same per-label heights the panel is sized
# from, so what is drawn and what is reserved can never disagree.
func _place_labels(inner_w: float) -> void:
	# First pass: hand every label its WIDTH. Control.size is clamped to get_combined_minimum_size(),
	# and an auto-wrapping Label computes that minimum from the width it currently has — so on the
	# very first layout, when the labels are still zero-width, the clamp inflated one of them by
	# 1175 px. Once the width is known the minimum is the real wrapped height and the clamp is a
	# no-op.
	for lbl: Label in [_title_label, _text_label, _foot_label]:
		if lbl != null:
			lbl.custom_minimum_size = Vector2(inner_w, 0)
			lbl.size.x = inner_w
	var y: float = PAD_Y
	for lbl2: Label in [_title_label, _text_label, _foot_label]:
		if lbl2 == null:
			continue
		var h: float = _label_height(lbl2, inner_w)
		if h <= 0.0:
			continue
		lbl2.position = Vector2(PAD_X, y)
		lbl2.size = Vector2(inner_w, h)
		y += h + float(VBOX_SEP)

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
	var ink: float = f.get_multiline_string_size(lbl.text, HORIZONTAL_ALIGNMENT_CENTER, inner_w, fs).y
	# get_multiline_string_size returns the TEXT's extent; a Label reserves a whole font line per
	# row — ascent + descent + the line_spacing theme constant. The difference is a couple of px
	# per line, which is nothing in a wide caption but stacks up in a narrow column until
	# "tap to continue" hangs below the balloon. Rebuild the height from whole lines instead.
	var line_h: float = maxf(f.get_height(fs), 1.0)
	var n_lines: float = maxf(1.0, round(ink / line_h))
	return n_lines * (line_h + float(lbl.get_theme_constant("line_spacing")))
