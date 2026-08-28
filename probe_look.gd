extends Node

# TEMPORARY PROBE — instantiates the restyled screens and reports what they are made of, so a
# cosmetic pass can be checked without a display.

func _ready() -> void:
	MainGlobals.init_globals(Vector2(680, 788))
	var fails: Array = []
	var login: CanvasLayer = load("res://scenes/login.tscn").instantiate()
	add_child(login)
	for _i in 8:
		await get_tree().process_frame
	var ground: TextureRect = login.get_node_or_null("BackgroundPanel/TextureRect")
	if ground == null:
		fails.append("no background node")
	else:
		if ground.texture != null:
			fails.append("the grass texture is still there")
		if ground.get_node_or_null("Backdrop") == null:
			fails.append("no drawn backdrop attached")
	for name_ in ["Username", "Email", "Password", "GuestName"]:
		var le: LineEdit = _find(login, name_) as LineEdit
		if le == null:
			fails.append("no field %s" % name_)
		elif le.get_theme_stylebox("normal") is StyleBoxFlat:
			var sb: StyleBoxFlat = le.get_theme_stylebox("normal")
			if sb.corner_radius_top_left < 8:
				fails.append("%s is still a square field" % name_)
		else:
			fails.append("%s has no field style" % name_)
	for name_ in ["LoginTabBtn", "SignupTabBtn", "GuestTabBtn"]:
		var b: Button = _find(login, name_) as Button
		if b == null:
			fails.append("no tab %s" % name_)
			continue
		var sb = b.get_theme_stylebox("normal")
		if not (sb is StyleBoxFlat) or not (sb as StyleBoxFlat).draw_center:
			fails.append("%s is still an outline tab" % name_)
	for name_ in ["ActionButton", "GuestPlayBtn", "GuestBackBtn"]:
		var b: Button = _find(login, name_) as Button
		if b == null:
			fails.append("no button %s" % name_)
			continue
		var sb = b.get_theme_stylebox("normal")
		if not (sb is StyleBoxFlat) or (sb as StyleBoxFlat).corner_radius_top_left != GameButton.CORNER:
			fails.append("%s is not the app's button" % name_)
	login.queue_free()
	for _i in 4:
		await get_tree().process_frame

	# The two card games' boards: the drawn ground, and (friends) the answer row in the order the
	# swipes go.
	for spec: Array in [["friends", true], ["weris", false]]:
		var folder: String = String(spec[0])
		var m: Node = load("res://%s/scenes/main.tscn" % folder).instantiate()
		add_child(m)
		for _i in 8:
			await get_tree().process_frame
		var lvl: Node = m.get_node_or_null("Level")
		var tr: TextureRect = lvl.get_node_or_null("TextureRect") if lvl != null else null
		if tr == null:
			fails.append("%s: no background node" % folder)
		else:
			if tr.texture != null:
				fails.append("%s: the tiled grass is still there" % folder)
			if tr.get_node_or_null("Backdrop") == null:
				fails.append("%s: no drawn backdrop attached" % folder)
		if bool(spec[1]):
			var ignore_btn: Button = _find(lvl, "IgnoreButton") as Button
			var hi_btn: Button = _find(lvl, "SayHiButton") as Button
			if ignore_btn == null or hi_btn == null:
				fails.append("%s: answer buttons missing" % folder)
			else:
				if ignore_btn.get_index() > hi_btn.get_index():
					fails.append("%s: Say Hi is still left of Ignore, against the swipe" % folder)
				if not hi_btn.text.contains("\u2192") or not ignore_btn.text.contains("\u2190"):
					fails.append("%s: the answer buttons carry no arrows" % folder)
		m.queue_free()
		for _i in 4:
			await get_tree().process_frame

	# The scores/stats screen: the drawn ground, and the tabs on the app's accent.
	var scores: CanvasLayer = load("res://scenes/scores_list.tscn").instantiate()
	add_child(scores)
	for _i in 8:
		await get_tree().process_frame
	var srect: TextureRect = scores.get_node_or_null("ScoresWindow/ColorRect")
	if srect == null:
		fails.append("scores: no background node")
	else:
		if srect.texture != null:
			fails.append("scores: the tiled grass is still there")
		if srect.get_node_or_null("Backdrop") == null:
			fails.append("scores: no drawn backdrop attached")
	var tab: Button = _find(scores, "ScoresTabButton") as Button
	if tab == null:
		fails.append("scores: no tab button")
	else:
		var sb = tab.get_theme_stylebox("normal")
		if not (sb is StyleBoxFlat):
			fails.append("scores: the tab has no style")
		elif (sb as StyleBoxFlat).bg_color.a > 0.0 and (sb as StyleBoxFlat).bg_color != ScreenBackdrop.ACCENT:
			fails.append("scores: the active tab is not on the app's accent")
	# The table must sit ON a panel, and that panel must be square across the top so the active tab
	# joins it instead of floating over the gradient.
	var panel: PanelContainer = _find(scores, "TablePanel") as PanelContainer
	if panel == null:
		fails.append("scores: the table has no surface")
	else:
		var psb = panel.get_theme_stylebox("panel")
		if not (psb is StyleBoxFlat):
			fails.append("scores: the table surface has no style")
		else:
			# Rounded at the TOP too: the tab bar is an inset pill on a full-width panel, so those
			# corners are in plain view either side of it.
			if (psb as StyleBoxFlat).corner_radius_top_left == 0:
				fails.append("scores: the content frame is square where it shows beside the tabs")
			# Lighter than the bar above it, so the rows separate from the surface they sit on.
			if (psb as StyleBoxFlat).bg_color.v <= ResultCard.CARD_BG.v:
				fails.append("scores: the content surface is no lighter than the tab bar")
		if _find(panel, "Header") == null or _find(panel, "ScrollContainer") == null:
			fails.append("scores: the header and the list are not on the surface")
	# The frame belongs to the content, not to the tabs: a border on the tab bar wraps it around
	# them, which is what a tab has to sit outside of.
	var bar: PanelContainer = null
	for c in _all_nodes(scores):
		if c is PanelContainer and _find(c, "ScoresTabButton") != null:
			bar = c
	if bar == null:
		fails.append("scores: no tab bar panel")
	else:
		var bsb = bar.get_theme_stylebox("panel")
		if bsb is StyleBoxFlat and (bsb as StyleBoxFlat).border_width_top > 0:
			fails.append("scores: the frame runs around the tabs instead of under them")
	if panel != null:
		var fsb = panel.get_theme_stylebox("panel")
		if fsb is StyleBoxFlat and (fsb as StyleBoxFlat).border_width_top == 0:
			fails.append("scores: the content frame has no line closing it under the tabs")

	# The chart's frame must be filled with the chart's OWN ground, or a mat of a different color
	# shows between the frame and the plot.
	var chart: Node = null
	for c in _all_nodes(scores):
		if c is ChartControl:
			chart = c
	if chart == null:
		fails.append("scores: no chart control")
	else:
		var csb = (chart.get_parent() as PanelContainer).get_theme_stylebox("panel") \
			if chart.get_parent() is PanelContainer else null
		if csb == null or not (csb is StyleBoxFlat):
			fails.append("scores: the chart has no frame")
		elif (csb as StyleBoxFlat).bg_color != ChartControl.GROUND:
			fails.append("scores: the chart's frame is not filled with the chart's own ground")

	# The bar and the surface must be siblings with no gap between them.
	var stack: VBoxContainer = _find(scores, "TabsAndTable") as VBoxContainer
	if stack == null:
		fails.append("scores: the tab bar and the table are not in one stack")
	elif stack.get_theme_constant("separation") != 0:
		fails.append("scores: there is a gap between the tab bar and the table")
	# The stack must only claim the screen while it HAS content showing. typit adds a Keys page as a
	# sibling and switches to it by hiding both the table and the chart; a stack still set to expand
	# went on holding ~350 units for a 57-unit tab bar, and the Keys list had no room to scroll in.
	if stack != null:
		if stack.size_flags_vertical != Control.SIZE_EXPAND_FILL:
			fails.append("scores: the stack does not expand while the table is showing")
		scores.call("_show_chart_area")
		if scores.get("_chart_area") != null:
			(scores.get("_chart_area") as Control).visible = false
		for _i in 4:
			await get_tree().process_frame
		if stack.size_flags_vertical == Control.SIZE_EXPAND_FILL:
			fails.append("scores: the stack still claims the screen with no content on show")

	scores.queue_free()
	for _i in 4:
		await get_tree().process_frame

	# --- the scores screen AT MOBILE TYPE -------------------------------------------------------
	#
	# Built with force_mobile on, so the automatic type pass runs over it: the three things that
	# broke when it first did were tabs of different sizes, rows inheriting a scene size and
	# bursting their line, and the chart's metric row running off the screen.
	MainGlobals.force_mobile = true
	var mscores: CanvasLayer = load("res://scenes/scores_list.tscn").instantiate()
	add_child(mscores)
	for _i in 8:
		await get_tree().process_frame
	var tabs: Array = []
	var tab_bar: Node = _find(mscores, "TabBar")
	if tab_bar == null:
		fails.append("mobile scores: no tab bar")
	else:
		# With every tab visible, the bar must still fit across the screen.
		for c in tab_bar.get_children():
			if c is Control:
				(c as Control).visible = true
		for _i in 4:
			await get_tree().process_frame
		var bar_want: float = (tab_bar as Control).get_combined_minimum_size().x
		print("  tab bar wants %.0f of %.0f units" % [bar_want, MainGlobals.full_screen_size.x])
		if bar_want > float(MainGlobals.full_screen_size.x):
			fails.append("mobile scores: the tab bar wants %d units of a %d-unit screen" % [
				bar_want, MainGlobals.full_screen_size.x])
		for c in tab_bar.get_children():
			if c is Button:
				tabs.append(c)
		var sizes: Array = []
		for t: Button in tabs:
			sizes.append(t.get_theme_font_size("font_size"))
		for v in sizes:
			if int(v) != int(sizes[0]):
				fails.append("mobile scores: the tabs are set at different sizes %s" % str(sizes))
				break
	# The chart's metric row must fit the canvas. The chart area starts hidden, and a container that
	# has never been laid out reports a stale minimum size — so it is shown first.
	if mscores.has_method("_show_chart_area"):
		mscores.call("_show_chart_area")
	for _i in 6:
		await get_tree().process_frame
	var metric_row: Node = null
	for c in _all_nodes(mscores):
		if c is Button and String(c.text) == "% Correct":
			metric_row = c.get_parent().get_parent().get_parent()
	if metric_row == null:
		fails.append("mobile scores: no metric row")
	else:
		var want: float = (metric_row as Control).get_combined_minimum_size().x
		var have: float = float(MainGlobals.full_screen_size.x)
		print("  metric row wants %.0f of %.0f units" % [want, have])
		if want > have:
			fails.append("mobile scores: the metric row wants %d units of a %d-unit screen" % [want, have])
	mscores.queue_free()
	MainGlobals.force_mobile = false
	for _i in 4:
		await get_tree().process_frame

	# --- the mobile type scale ------------------------------------------------------------------
	#
	# It applies where it is CALLED and nowhere else — the scene files are authored phone-first, so
	# there is no automatic pass over them (see MainGlobals.ui_font_size).
	MainGlobals.force_mobile = true
	var decided: Label = Label.new()
	MainGlobals.set_font_size(decided, 20)
	add_child(decided)
	if decided.get_theme_font_size("font_size") != int(round(20.0 * MainGlobals.MOBILE_FONT_SCALE)):
		fails.append("type: set_font_size did not scale on mobile (got %d)" % decided.get_theme_font_size("font_size"))
	decided.queue_free()

	var untouched: Label = Label.new()
	untouched.add_theme_font_size_override("font_size", 40)
	add_child(untouched)
	if untouched.get_theme_font_size("font_size") != 40:
		fails.append("type: a scene-authored size was changed behind the scenes (got %d)" % untouched.get_theme_font_size("font_size"))
	untouched.queue_free()
	MainGlobals.force_mobile = false
	for _i in 2:
		await get_tree().process_frame

	# --- a panning game's ground ----------------------------------------------------------------
	#
	# The ground of a panning game needs a background layer of its own, drawn behind everything, and
	# that layer must sit in the SAME space as the board: the lawn is now board-sized (one continuous
	# field over the whole board, scripts/grass_field.gd), so if the Level layer follows the camera
	# and the ground layer does not, the lawn is drawn unzoomed and reads as a different grass the
	# moment the camera takes over. That was the "background changes once the board is built" bug.
	for folder: String in ["mmm", "storm", "delemfp", "gorilla"]:
		var lvl: Node = load("res://%s/scenes/level.tscn" % folder).instantiate()
		add_child(lvl)
		await get_tree().process_frame
		# The ground node itself is a drawn lawn rather than a texture now, so what is checked is the
		# LAYER it lives in.
		var layer: CanvasLayer = null
		for c in _all_nodes(lvl):
			if c is CanvasLayer and c.name == "BgLayer":
				layer = c
		if layer == null:
			fails.append("%s: the ground has no BgLayer of its own" % folder)
		elif layer.get_child_count() == 0:
			fails.append("%s: the BgLayer is empty" % folder)
		elif lvl is CanvasLayer and (lvl as CanvasLayer).follow_viewport_enabled \
				and not layer.follow_viewport_enabled:
			fails.append("%s: the Level follows the camera but its BgLayer does not, so the lawn is drawn at the wrong scale" % folder)
		lvl.queue_free()
		await get_tree().process_frame

	print("")
	if fails.is_empty():
		print("LOOK OK")
	else:
		for f in fails:
			print("LOOK FAIL ", f)
	get_tree().quit()

func _all_nodes(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all_nodes(c))
	return out

func _find(n: Node, want: String) -> Node:
	if n.name == want:
		return n
	for c in n.get_children():
		var r: Node = _find(c, want)
		if r != null:
			return r
	return null
