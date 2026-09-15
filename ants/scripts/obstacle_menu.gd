class_name ObstacleMenu
extends RefCounted

# The tap menu for dropping something in an ant's way.
#
# Built on storm's pattern (storm/scripts/level.gd create_actions_popup): a PopupPanel centred on
# the tap, and a ring of choices around a CENTRE LEFT EMPTY AND TRANSPARENT, so the spot being
# acted on stays visible while the player chooses. That last part is the whole point of the design
# and the reason it is not a bottom bar or a side panel -- you are choosing what to put on top of
# ants you can still see.
#
# Each choice draws its own miniature through AntsArt.draw_obstacle, from a real AntObstacle. The
# button is therefore a picture of the thing itself rather than an icon standing in for it, and it
# cannot fall out of step with how the obstacle looks or how big it is.

const BOX_DESKTOP: int = 58
const SEP: int = 3
const RIM: Color = Color(0.92, 0.80, 0.42)
const SPENT: Color = Color(1.0, 1.0, 1.0, 0.30)   # modulate for an item with none left

# Returns the popup, or null if nothing could be offered.
static func open(host: Node, screen_pos: Vector2, on_pick: Callable, can_remove: bool,
		level: Node = null) -> PopupPanel:
	var box: int = MainGlobals.ui_font_size(BOX_DESKTOP)

	# Transparent FILL with a visible BORDER, which is what storm does. The fill has to stay clear:
	# this menu opens over a live colony and the whole reason it is a ring round an empty middle is
	# that you are choosing what to drop on ants you can still see. But an unframed set of floating
	# buttons has no edge, and nothing tells the player where the menu stops and the world starts --
	# so storm's frame is worth keeping even though its panel is not.
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.03, 0.25)
	sb.set_border_width_all(2)
	sb.border_color = Color(RIM.r, RIM.g, RIM.b, 0.55)
	sb.set_corner_radius_all(10)

	var popup: PopupPanel = PopupPanel.new()
	host.add_child(popup)
	popup.unresizable = true
	popup.add_theme_stylebox_override("panel", sb)

	var canvas: Control = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(canvas)

	var origin: Control = Control.new()
	origin.anchor_left = 0.5
	origin.anchor_top = 0.5
	origin.anchor_right = 0.5
	origin.anchor_bottom = 0.5
	origin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(origin)

	# North, east, south, west around an empty middle. Four choices in a three-by-three, so the
	# centre cell is free and nothing the player is looking at is covered.
	var slots: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var choices: Array = []
	for k in AntObstacle.KINDS:
		var left: int = 0
		if level != null:
			left = int(level.call("stock_of", int(k)))
		choices.append({"kind": int(k), "remove": false, "left": left})
	if can_remove:
		choices.append({"kind": -1, "remove": true, "left": -1})

	var pitch: float = float(box + 2 * SEP)
	for i in mini(choices.size(), slots.size()):
		var cell: Control = _make_cell(box, choices[i], on_pick, popup)
		origin.add_child(cell)
		cell.position = Vector2(slots[i]) * pitch - Vector2(box, box) * 0.5

	var span: int = box * 3 + SEP * 6
	popup.size = Vector2i(span, span)
	popup.popup(MainGlobals.clamp_popup_rect(screen_pos - Vector2(span, span) * 0.5,
		Vector2(span, span), 20))
	MainGlobals.set_popup_open(true)
	popup.popup_hide.connect(MainGlobals.set_popup_open.bind(false))
	return popup

static func _make_cell(box: int, choice: Dictionary, on_pick: Callable, popup: PopupPanel) -> Control:
	var cell: Control = Control.new()
	cell.custom_minimum_size = Vector2(box, box)
	cell.size = Vector2(box, box)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_remove: bool = bool(choice["remove"])
	var kind: int = int(choice["kind"])
	var left: int = int(choice["left"])
	var spent: bool = (not is_remove) and left <= 0
	# An item with none left is dimmed WHOLE -- swatch, frame and count together -- rather than
	# hidden, so the player can see that it exists and that they are out of it. Same treatment
	# storm gives a spent action.
	if spent:
		cell.modulate = SPENT

	# A miniature of the real thing, scaled to the cell. Drawn through the same function the world
	# uses, so the swatch is the obstacle rather than a picture of one.
	var swatch: AntObstacle = null
	var swatch_scale: float = 1.0
	if not is_remove:
		swatch = AntObstacle.new(kind, Vector2.ZERO, -0.35, 7)
		swatch_scale = (float(box) * 0.34) / maxf(swatch.half.x, swatch.half.y)

	cell.draw.connect(func() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, cell.size)
		cell.draw_rect(r, Color(0.10, 0.07, 0.05, 0.86), true)
		cell.draw_rect(r, RIM, false, 2.0)
		var mid: Vector2 = cell.size * 0.5
		if is_remove:
			var a: float = float(box) * 0.22
			cell.draw_line(mid - Vector2(a, a), mid + Vector2(a, a), Color(0.93, 0.44, 0.40), 4.0, true)
			cell.draw_line(mid - Vector2(a, -a), mid + Vector2(a, -a), Color(0.93, 0.44, 0.40), 4.0, true)
		else:
			# draw_obstacle works in world units, so the cell is scaled around its middle rather
			# than the obstacle being rebuilt at button size.
			cell.draw_set_transform(mid, 0.0, Vector2(swatch_scale, swatch_scale))
			AntsArt.draw_obstacle(cell, swatch)
			cell.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not is_remove:
			# The count, bottom right. Drawn rather than a Label so it lands on the swatch without
			# a container fighting the cell for size.
			var f: Font = MainGlobals.get_text_font()
			var fs: int = MainGlobals.ui_font_size(15)
			var txt: String = str(left)
			var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
			var at: Vector2 = Vector2(cell.size.x - w - 5.0, cell.size.y - 5.0)
			cell.draw_string_outline(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, 3,
				Color(0, 0, 0, 0.85))
			cell.draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs,
				Color(0.96, 0.93, 0.84)))

	cell.gui_input.connect(func(e: InputEvent) -> void:
		var tapped: bool = false
		if e is InputEventMouseButton:
			var mb: InputEventMouseButton = e as InputEventMouseButton
			tapped = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		elif e is InputEventScreenTouch:
			tapped = (e as InputEventScreenTouch).pressed
		if tapped:
			# Swallowed, so the same gesture cannot fall through to the world underneath.
			cell.accept_event()
			if spent:
				return
			popup.hide()
			popup.queue_free()
			on_pick.call(kind, is_remove))
	return cell
