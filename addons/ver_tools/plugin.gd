@tool
extends EditorPlugin

const PROJECT_VERSION_KEY := "application/config/version"

func _enter_tree() -> void:
	add_tool_menu_item("Bump Version + Android Code", _on_bump)

func _exit_tree() -> void:
	remove_tool_menu_item("Bump Version + Android Code")

func _on_bump() -> void:
	_bump_and_sync()

func _bump_and_sync() -> void:
	var v := str(ProjectSettings.get_setting(PROJECT_VERSION_KEY, "0.0.0"))
	var parts := v.split(".")
	while parts.size() < 3:
		parts.append("0")

	var major := int(parts[0])
	var minor := int(parts[1])
	var patch := int(parts[2]) + 1
	var new_version := "%d.%d.%d" % [major, minor, patch]

	ProjectSettings.set_setting(PROJECT_VERSION_KEY, new_version)
	ProjectSettings.save()

	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") == OK:
		for s in cfg.get_sections():
			if s.begins_with("preset.") and s.ends_with(".options") and cfg.has_section_key(s, "version/code"):
				cfg.set_value(s, "version/code", patch)
				# if cfg.has_section_key(s, "version/name"):
				# 	cfg.set_value(s, "version/name", new_version)
		cfg.save("res://export_presets.cfg")

	EditorInterface.get_editor_toaster().push_toast(
		"Version bumped to %s (Android code %d)" % [new_version, patch]
	)
