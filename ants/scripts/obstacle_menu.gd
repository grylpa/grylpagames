class_name ObstacleMenu
extends RefCounted

# The tap menu for dropping something in an ant's way.
#
# Built on storm's pattern (storm/scripts/level.gd create_actions_popup): a ring of choices around a
# CENTRE LEFT EMPTY, so the spot being acted on stays visible while the player chooses. That last
# part is the whole point of the design and the reason it is not a bottom bar -- you are choosing
# what to put on top of ants you can still see.
#
# NOT a PopupPanel, though, which is where storm's version differs and why. A Window clips
# everything to its own rect, so a tooltip has to live inside the menu's own three-by-three square
# -- cropped, and lying across the very tool it describes. Growing the window to make room made the
# menu enormous. As a CanvasLayer over the viewport there is no rect to be clipped by: the ring
# stays exactly the size it was and the tooltip goes wherever it reads best.
#
# Each choice draws its own swatch through AntsArt, from a real AntObstacle, so the button is the
# thing itself rather than an icon standing in for it.

const BOX_DESKTOP: int = 58
const SEP: int = 3
const RIM: Color = Color(0.92, 0.80, 0.42)
const SPENT: Color = Color(1.0, 1.0, 1.0, 0.30)   # modulate for an item with none left
const SPRAY_PICK: int = -2
# A phone has no hover, so the only gesture left that does not already mean "use this" is a HOLD.
# A desktop keeps its hover as well, on the same delay.
const HOLD_MS: int = 400
# A mouse rests on things on its way elsewhere; a finger does not. Hovering wants the longer wait,
# or the tooltip pops up at every tool the pointer crosses on its way to the one you want.
const HOVER_MS: int = 750
const TIP_W_DESKTOP: int = 210
const TIP_GAP: float = 14.0

static func open(host: Node, screen_pos: Vector2, on_pick: Callable, can_remove: bool,
		level: Node = null, on_tip: Callable = Callable()) -> CanvasLayer:
	var box: int = MainGlobals.ui_font_size(BOX_DESKTOP)
	var pitch: float = float(box + 2 * SEP)
	var view: Vector2 = host.get_viewport_rect().size

	var menu: CanvasLayer = CanvasLayer.new()
	menu.layer = 80
	host.add_child(menu)

	# Anything outside the ring dismisses it. The scrim is invisible but takes the press, so the
	# world underneath never sees the tap that closed the menu.
	var scrim: Control = Control.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.add_child(scrim)

	var line: Control = Control.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The ring, centred on the tap and nudged just enough to stay on screen.
	var half: float = pitch * 1.5
	var mid: Vector2 = Vector2(
		clampf(screen_pos.x, half + 4.0, maxf(half + 4.0, view.x - half - 4.0)),
		clampf(screen_pos.y, half + 4.0, maxf(half + 4.0, view.y - half - 4.0)))
	var ring: Control = Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = mid
	menu.add_child(ring)
	# AFTER the ring, so the connector is drawn over the tools rather than under them. It used to go
	# in first and every cell painted across it.
	menu.add_child(line)

	var tip: PanelContainer = PanelContainer.new()
	var tsb: StyleBoxFlat = StyleBoxFlat.new()
	tsb.bg_color = Color(0.086, 0.070, 0.059, 0.97)
	tsb.set_border_width_all(2)
	tsb.border_color = RIM
	tsb.set_corner_radius_all(8)
	tsb.set_content_margin_all(8)
	tip.add_theme_stylebox_override("panel", tsb)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	var tip_text: Label = Label.new()
	tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_text.custom_minimum_size.x = float(MainGlobals.ui_font_size(TIP_W_DESKTOP))
	tip_text.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	MainGlobals.set_font_size(tip_text, 15)
	tip.add_child(tip_text)
	menu.add_child(tip)

	# ONE TAP, ONE ACTION. Godot emulates a mouse click from every touch by default, so a single tap
	# on a phone arrives twice -- once as InputEventScreenTouch and again as InputEventMouseButton --
	# and the menu obligingly placed two obstacles for it. The guard is on the MENU rather than on
	# the event, because it is the menu that may only be used once.
	var acted: Array = [false]
	var from_at: Array = [Vector2.ZERO]
	# Filled in as the cells are laid out below, and read by the tooltip placement above it -- so it
	# is declared here, where both can see it.
	var cell_rects: Array = []
	# Parallel to cell_rects: what each box IS. The order the boxes go round the ring is an
	# implementation detail of this file (kinds, then spray, then remove, minus whatever the level
	# is out of), so a tutorial that wants to point at the bait cannot count slots -- it asks.
	var cell_kinds: Array = []
	line.draw.connect(func() -> void:
		if not tip.visible:
			return
		# ONE segment, always, from the middle of the tool to the edge of the box. It used to elbow
		# outward first whenever the straight line would cross another tool -- and from a corner
		# cell "outward" is the corner of the screen, so the line shot up into the corner and then
		# came back down to the tooltip, which looks like a mistake rather than a route. The
		# connector is drawn over the tools now, so crossing one is legible and costs nothing.
		var a: Vector2 = from_at[0]
		line.draw_line(a, _edge_toward(tip, a), Color(RIM.r, RIM.g, RIM.b, 0.95), 2.0, true)
		line.draw_circle(a, 3.0, RIM))

	# OUTWARD from the ring, always. A tooltip put anywhere else needs a line across the middle of
	# the menu, over the other tools; radially outward from the cell being held, the line is short
	# and cannot cross a thing.
	var show_tip: Callable = func(cell_mid: Vector2, text: String) -> void:
		tip_text.text = text
		tip.reset_size()
		await host.get_tree().process_frame
		var sz: Vector2 = tip.size
		var base: Vector2 = (cell_mid - mid).normalized()
		if base.length_squared() < 0.01:
			base = Vector2.DOWN
		# Outward from the ring is where it reads best, but near a screen edge outward is off the
		# screen, and clamping it back drops the box straight onto the tools -- sometimes onto the
		# very one being held. So the whole circle is tried, nearest bearing first, and the first
		# position that both fits and touches no tool wins. There is always one: the ring is small
		# and the screen is not.
		tip.position = place_tip(mid, half, base, sz, view, cell_rects)
		from_at[0] = cell_mid
		tip.visible = true
		line.queue_redraw()
		if on_tip.is_valid():
			on_tip.call()

	var hide_tip: Callable = func() -> void:
		tip.visible = false
		line.queue_redraw()

	var close: Callable = func() -> void:
		acted[0] = true
		if is_instance_valid(menu):
			MainGlobals.set_popup_open(false)
			menu.queue_free()

	scrim.gui_input.connect(func(e: InputEvent) -> void:
		var down: bool = false
		if e is InputEventMouseButton:
			down = (e as InputEventMouseButton).pressed
		elif e is InputEventScreenTouch:
			down = (e as InputEventScreenTouch).pressed
		if down and not bool(acted[0]):
			scrim.accept_event()
			close.call())

	# North, east, south, west, then the corners -- the middle stays empty whatever happens.
	var slots: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var choices: Array = []
	for k in AntObstacle.KINDS:
		var left: int = 0
		if level != null:
			left = int(level.call("stock_of", int(k)))
		choices.append({"kind": int(k), "remove": false, "spray": false, "left": left})
	if level != null and int(level.get("spray_presses_total")) > 0:
		var total: float = maxf(float(level.get("spray_presses_total")), 1.0)
		choices.append({"kind": SPRAY_PICK, "remove": false, "spray": true,
			"left": int(level.get("spray_left")),
			"full": float(level.get("spray_left")) / total})
	if can_remove:
		choices.append({"kind": -1, "remove": true, "spray": false, "left": -1})

	for i in mini(choices.size(), slots.size()):
		var at: Vector2 = Vector2(slots[i]) * pitch
		var cell: Control = _make_cell(box, choices[i], on_pick, close, show_tip, hide_tip, acted)
		cell.position = at - Vector2(box, box) * 0.5
		cell_rects.append(Rect2(mid + at - Vector2(box, box) * 0.5, Vector2(box, box)))
		cell_kinds.append(int(choices[i]["kind"]))
		ring.add_child(cell)

	# Published so a tutorial caption can keep off it -- CELL BY CELL, not as one ring. The runner
	# only re-places a caption once it buries half of a zone's area, and a caption lying across the
	# bottom row of tools covers barely a third of the whole square, so a single ring-sized zone is
	# one the coach will happily sit on.
	menu.set_meta("ring_rect", Rect2(mid - Vector2(half, half), Vector2(half, half) * 2.0))
	menu.set_meta("cell_rects", cell_rects)
	menu.set_meta("cell_kinds", cell_kinds)
	MainGlobals.set_popup_open(true)
	return menu

# Where a tooltip of this size can sit: outward from the ring if it can, and otherwise anywhere on
# the circle that both fits the screen and touches no tool.
#
# Pulled out as a plain function of its inputs so it can be checked directly. Near a screen edge
# "outward" is off the screen, and clamping it back used to drop the box straight onto the tools --
# sometimes onto the very one being held.
static func place_tip(mid: Vector2, ring_half: float, base: Vector2, sz: Vector2, view: Vector2,
		cell_rects: Array) -> Vector2:
	var reach: float = ring_half + TIP_GAP + maxf(sz.x, sz.y) * 0.5
	var best: Vector2 = Vector2.ZERO
	var best_off: float = INF
	for i in 13:
		for sgn in [1.0, -1.0]:
			var off: float = deg_to_rad(float(i) * 15.0)
			var d: Vector2 = Vector2.from_angle(base.angle() + off * sgn)
			var at: Vector2 = mid + d * reach - sz * 0.5
			at.x = clampf(at.x, 6.0, maxf(6.0, view.x - sz.x - 6.0))
			at.y = clampf(at.y, 6.0, maxf(6.0, view.y - sz.y - 6.0))
			var box_r: Rect2 = Rect2(at, sz).grow(6.0)
			var clear: bool = true
			for cr in cell_rects:
				if box_r.intersects(cr as Rect2):
					clear = false
					break
			if clear and off < best_off:
				best_off = off
				best = at
	if best_off < INF:
		return best
	# Nowhere clear at all -- take the outward one and let it overlap rather than vanish.
	var fall: Vector2 = mid + base * reach - sz * 0.5
	fall.x = clampf(fall.x, 6.0, maxf(6.0, view.x - sz.x - 6.0))
	fall.y = clampf(fall.y, 6.0, maxf(6.0, view.y - sz.y - 6.0))
	return fall

# Where a line aimed at the box should stop: on its edge, not in its middle.
static func _edge_toward(tip: Control, from: Vector2) -> Vector2:
	var c: Vector2 = tip.position + tip.size * 0.5
	var d: Vector2 = (from - c).normalized()
	return c + Vector2(d.x * tip.size.x * 0.5, d.y * tip.size.y * 0.5)

static func _tip_for(choice: Dictionary) -> String:
	if bool(choice["remove"]):
		return "Pick up what is here and put it back in your hand."
	if bool(choice["spray"]):
		return "A repellent they will not walk on. One squirt where you tapped. It fades."
	return str(AntObstacle.TIPS.get(int(choice["kind"]), "")).replace("\n", " ")

static func _make_cell(box: int, choice: Dictionary, on_pick: Callable, close: Callable,
		show_tip: Callable, hide_tip: Callable, acted: Array) -> Control:
	var cell: Control = Control.new()
	cell.custom_minimum_size = Vector2(box, box)
	cell.size = Vector2(box, box)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_remove: bool = bool(choice["remove"])
	var is_spray: bool = bool(choice["spray"])
	var kind: int = int(choice["kind"])
	var left: int = int(choice["left"])
	var spent: bool = (not is_remove) and left <= 0
	var full: float = float(choice.get("full", 1.0))
	# An item with none left is dimmed WHOLE -- swatch, frame and count together -- rather than
	# hidden, so the player can see that it exists and that they are out of it.
	if spent:
		cell.modulate = SPENT

	var swatch: AntObstacle = null
	var swatch_scale: float = 1.0
	if not is_remove and not is_spray:
		swatch = AntObstacle.new(kind, Vector2.ZERO, -0.35, 7)
		swatch_scale = (float(box) * 0.34) / maxf(swatch.half.x, swatch.half.y)

	cell.draw.connect(func() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, cell.size)
		cell.draw_rect(r, Color(0.10, 0.07, 0.05, 0.86), true)
		cell.draw_rect(r, RIM, false, 2.0)
		var mid: Vector2 = cell.size * 0.5
		if is_spray:
			AntsArt.draw_spray_can(cell, mid, float(box) * 0.62, full)
		elif is_remove:
			var a: float = float(box) * 0.22
			cell.draw_line(mid - Vector2(a, a), mid + Vector2(a, a), Color(0.93, 0.44, 0.40), 4.0, true)
			cell.draw_line(mid - Vector2(a, -a), mid + Vector2(a, -a), Color(0.93, 0.44, 0.40), 4.0, true)
		else:
			cell.draw_set_transform(mid, 0.0, Vector2(swatch_scale, swatch_scale))
			AntsArt.draw_obstacle(cell, swatch)
			cell.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not is_remove:
			var f: Font = MainGlobals.get_text_font()
			var fs: int = MainGlobals.ui_font_size(15)
			var txt: String = str(left)
			var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
			var at: Vector2 = Vector2(cell.size.x - w - 5.0, cell.size.y - 5.0)
			cell.draw_string_outline(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 3,
				Color(0, 0, 0, 0.85))
			cell.draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs,
				Color(0.96, 0.93, 0.84)))

	# Press and release are separated so a HOLD can mean something different from a tap.
	var pressed_at: Array = [0]
	cell.gui_input.connect(func(e: InputEvent) -> void:
		if bool(acted[0]):
			return
		var down: bool = false
		var up: bool = false
		if e is InputEventMouseButton:
			var mb: InputEventMouseButton = e as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				down = mb.pressed
				up = not mb.pressed
		elif e is InputEventScreenTouch:
			down = (e as InputEventScreenTouch).pressed
			up = not (e as InputEventScreenTouch).pressed
		if down:
			pressed_at[0] = Time.get_ticks_msec()
			cell.accept_event()
			return
		if not up:
			return
		cell.accept_event()
		if Time.get_ticks_msec() - int(pressed_at[0]) >= HOLD_MS:
			show_tip.call(cell.global_position + cell.size * 0.5, _tip_for(choice))
			return
		hide_tip.call()
		if spent:
			return
		close.call()
		on_pick.call(kind, is_remove))

	# A mouse has a hover; holding a button down to read a label is a phone's compromise.
	var hovering: Array = [false]
	cell.mouse_entered.connect(func() -> void:
		hovering[0] = true
		var t: SceneTreeTimer = cell.get_tree().create_timer(float(HOVER_MS) / 1000.0)
		t.timeout.connect(func() -> void:
			if bool(hovering[0]) and is_instance_valid(cell):
				show_tip.call(cell.global_position + cell.size * 0.5, _tip_for(choice))))
	cell.mouse_exited.connect(func() -> void:
		hovering[0] = false
		hide_tip.call())
	return cell
