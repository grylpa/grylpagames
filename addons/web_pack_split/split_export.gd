@tool
extends EditorExportPlugin
# cuts a finished Web export's pack into a base and one pack per game (splitter.gd; plugin.gd)

const Splitter: GDScript = preload("res://addons/web_pack_split/splitter.gd")

var _web_path: String = ""

func _get_name() -> String:
	return "WebPackSplit"

func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_web_path = path if features.has("web") else ""

func _export_end() -> void:
	if _web_path == "":
		return
	var full: String = _web_path
	if full.is_relative_path():
		full = ProjectSettings.globalize_path("res://").path_join(full)
	_web_path = ""
	if not Splitter.new().split(ProjectSettings.globalize_path(full).get_base_dir()):
		push_error("Web export: the pack was NOT split (it holds every game) -- see the lines above")
