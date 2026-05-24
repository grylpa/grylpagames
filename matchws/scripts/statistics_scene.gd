extends CanvasLayer

enum EPlotType {time = 0, mistakes = 1}

var resgroup: ButtonGroup = null

func _ready() -> void:
	resgroup = $VBoxContainer/Resolution/M.button_group
	resgroup.connect("pressed", _on_pressed_res_group)

func create_graph():
	$VBoxContainer/Resolution.find_child(MatchwsG.statistics_resolution).set_pressed_no_signal(true)
	var w = MatchwsG.words
	%Info.text = w.selected_new_lang_name() + "/" + w.selected_known_lang_name() + "\n" + \
		w.selected_collection_name() + \
		"\ndifficulty: " + str(MatchwsG.starting_difficulty) + \
		"\nmoving: " + MainGlobals.YN(MatchwsG.moving) + \
		", fast mode: " + MainGlobals.YN(MatchwsG.speed_mode)
	match MatchwsG.statistics_plot_type:
		EPlotType.time:
			create_time_stats()
			%StatTimeButton.set_pressed_no_signal(true)
			%StatMistakesButton.set_pressed_no_signal(false)
		EPlotType.mistakes:
			create_mistakes_stats()
			%StatTimeButton.set_pressed_no_signal(false)
			%StatMistakesButton.set_pressed_no_signal(true)

func _on_stat_time_button_pressed() -> void:
	create_time_stats()

func _on_stat_mistakes_button_pressed() -> void:
	create_mistakes_stats()

func _on_pressed_res_group(btn: BaseButton) -> void:
	MatchwsG.statistics_resolution = btn.text
	create_graph()
	MatchwsG.save_settings()

func _get_data():
	if "data" in MatchwsG.words.stats_dict:
		return MatchwsG.words.stats_dict["data"][int(MatchwsG.moving)][int(MatchwsG.speed_mode)].get(MatchwsG.starting_difficulty, {})
	else:
		return null

func dhms_to_s(days: int, hours: int, minutes: int, seconds: int) -> int:
	return (((days * 24) + hours) * 60 + minutes) * 60 + seconds

func _disp_graph(raw_points: Array, x_res_sec: float, y_label: String, title: String) -> void:
	var pts: Array = []
	if raw_points.size() > 0:
		var x_idx: int = 0
		var acc: float = 0.0
		var start_x: float = 0.0
		var n: int = 0
		for i: int in range(raw_points.size()):
			var v: Vector2 = raw_points[i]
			var epoch: float = v.x
			if i == 0:
				start_x = epoch
			if epoch - start_x >= x_res_sec:
				if n > 0:
					pts.append(Vector2(float(x_idx), acc / float(n)))
					x_idx += 1
				acc = 0.0
				start_x = epoch
				n = 0
			acc += v.y
			n += 1
		if n > 0:
			pts.append(Vector2(float(x_idx), acc / float(n)))
	%ChartControl.y_label = y_label
	%ChartControl.x_as_index = true
	%ChartControl.set_series([{"label": title, "color": ChartControl.SERIES_COLORS[0], "points": pts}])

func get_resolution_vals() -> Array:
	match MatchwsG.statistics_resolution:
		"M": return ["minute", float(dhms_to_s(0, 0, 1, 0))]
		"H": return ["hour",   float(dhms_to_s(0, 1, 0, 0))]
		"D": return ["day",    float(dhms_to_s(1, 0, 0, 0))]
		_:   return ["hour",   float(dhms_to_s(0, 1, 0, 0))]

func create_time_stats() -> void:
	MatchwsG.statistics_plot_type = EPlotType.time
	MatchwsG.save_settings()
	var data = _get_data()
	if data == null:
		return
	var points: Array = []
	if data.size() > 0:
		var res_vals: Array = get_resolution_vals()
		var x_res_sec: float = res_vals[1]
		for i: int in range(data.size()):
			var row = data[i]
			var epoch: float = float(row.get("epoch", 0))
			var t: int = int(row.get("durationms", -1) / 1000.0)
			if t >= 0:
				points.append(Vector2(epoch, float(t)))
		_disp_graph(points, x_res_sec, "Time to answer (s)", "Time per " + res_vals[0])

func create_mistakes_stats() -> void:
	MatchwsG.statistics_plot_type = EPlotType.mistakes
	MatchwsG.save_settings()
	var data = _get_data()
	if data == null:
		return
	var points: Array = []
	if data.size() > 0:
		var res_vals: Array = get_resolution_vals()
		var x_res_sec: float = res_vals[1]
		for i: int in range(data.size()):
			var row = data[i]
			var epoch: float = float(row.get("epoch", 0))
			var t: int = int(row.get("nmistakes", 0))
			if t >= 0:
				points.append(Vector2(epoch, float(t)))
		_disp_graph(points, x_res_sec, "Mistakes", "Mistakes per " + res_vals[0])

func _on_close_button_pressed() -> void:
	hide()

func _on_x_close_scene_button_pressed() -> void:
	_on_close_button_pressed()
