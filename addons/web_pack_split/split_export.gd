@tool
extends EditorExportPlugin
# runs devtools/split_web_pack.py on a finished Web export (plugin.gd)

var _web_path: String = ""

func _get_name() -> String:
	return "WebPackSplit"

func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_web_path = path if features.has("web") else ""

func _export_end() -> void:
	if _web_path == "":
		return
	var out_dir: String = ProjectSettings.globalize_path(_web_path).get_base_dir()
	if _web_path.is_relative_path():
		out_dir = ProjectSettings.globalize_path("res://").path_join(_web_path).get_base_dir()
	_web_path = ""
	var script_path: String = ProjectSettings.globalize_path("res://").path_join("../devtools/split_web_pack.py").simplify_path()
	if not FileAccess.file_exists(script_path):
		push_error("Web export: %s not found -- the pack was NOT split (it holds every game)" % script_path)
		return
	var output: Array = []
	var code: int = OS.execute("python3", [script_path, out_dir], output, true)
	for line in output:
		print(str(line).strip_edges())
	if code != 0:
		push_error("Web export: split_web_pack.py failed (exit %d) -- the pack was NOT split" % code)
