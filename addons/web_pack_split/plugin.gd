@tool
extends EditorPlugin
# After every WEB export -- from the editor or `--export-release "Web"` -- the exported pack is cut into a base and one
# pack per game by devtools/split_web_pack.py (see CLAUDE.md, "The web build"). Without it the web build is one pack of
# ~50 MB, every game's files downloaded before the chooser comes up.

var _exporter: EditorExportPlugin = null

func _enter_tree() -> void:
	_exporter = preload("res://addons/web_pack_split/split_export.gd").new()
	add_export_plugin(_exporter)

func _exit_tree() -> void:
	remove_export_plugin(_exporter)
	_exporter = null
