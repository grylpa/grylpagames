extends Node
var main: Node
func _cards() -> Array:
	var out: Array = []
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("close_window") and n.is_inside_tree():
			out.append("%s(%s,vis=%s)" % [n.name, str(n.get_script().resource_path).get_file() if n.get_script() else "-", n.get("visible")])
	return out
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("game_popup.gd") and n.visible:
			out.append(str(n._parts["title"].text) if not n._parts.is_empty() else "?")
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("level_done_popup.gd") and n.visible:
			out.append("LEVEL DONE")
	return out
func _wait(sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()
func _ready() -> void:
	main = load("res://storm/scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	main.call("_on_main_menu_menu_start_game", true)
	await _wait(1.5)
	var lv: Node = main.get_node("Level")
	print("after start: ", _cards(), " intro_open=", lv.get("_intro_is_open"), " ready=", StormG.game.level_is_ready, " pipes=", (lv.get("pipes") as Array).size(), " kids=", lv.get_child_count())
	# close the briefing like a tap
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("close_window") and n.get_script() != null and str(n.get_script().resource_path).ends_with("game_popup.gd"):
			n.close_window()
	await _wait(0.5)
	print("playing: ", StormG.game.playing, " cards ", _cards())
	# Scenario: the clock runs out.
	StormG.game.time_left_sec = 2
	await _wait(4.0)
	print("after time out: ", _cards(), " done=", StormG.game.level_is_done, " t=", StormG.game.time_left_sec)
	await _wait(3.0)
	print("3 s later: ", _cards())
	get_tree().quit(0)
