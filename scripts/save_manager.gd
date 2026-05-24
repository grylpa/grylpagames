extends Node

const SAVE_VERSION: int = 1

var verbose: bool = true

func _print_debug(msg: String) -> void:
	if verbose:
		print("[SaveManager] " + msg)

func fix_path(path):
	if path.left("user://".length()) != "user://":
		path = "user://" + path
	if path.right(".json".length()) != ".json":
		path += ".json"
	return path

func save_game(path: String, dict_snapshot: Dictionary) -> void:
	path = fix_path(path)
	var data = dict_snapshot.duplicate(true)
	data["save_version"] = SAVE_VERSION
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# _print_debug("Saved to %s: %s" % [path, str(data)])

func load_game(path: String) -> Dictionary:
	path = fix_path(path)
	if not FileAccess.file_exists(path):
		_print_debug("No save file at %s" % path)
		return {}

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = f.get_as_text()
	f.close()

	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_print_debug("Invalid save format")
		return {}

	var dict: Dictionary = data

	# Handle save version
	var file_version: int = dict.get("save_version", 0)
	if file_version != SAVE_VERSION:
		_print_debug("Save version mismatch (file=%d, current=%d)" % [file_version, SAVE_VERSION])

	# _print_debug("Loaded from %s: %s" % [path, str(dict)])
	data.erase("save_version")
	return data

func v2i_d(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}

func d_v2i(d: Dictionary) -> Vector2i:
	return Vector2i(d.get("x", 0), d.get("y", 0))

func v2_d(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}

func d_v2(d: Dictionary) -> Vector2:
	return Vector2(d.get("x", 0.0), d.get("y", 0.0))

func c_d(c: Color) -> Dictionary:
	return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}

func d_c(d: Dictionary) -> Color:
	return Color(d.get("r", 1.0), d.get("g", 1.0), d.get("b", 1.0), d.get("a", 1.0))

func r2_d(r: Rect2) -> Dictionary:
	return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}

func d_r2(d: Dictionary) -> Rect2:
	return Rect2(
		Vector2(d.get("x", 0.0), d.get("y", 0.0)),
		Vector2(d.get("w", 0.0), d.get("h", 0.0))
	)
