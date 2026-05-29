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
	var ps_err := ProjectSettings.save()
	print("[ver_tools] project version %s -> %s (ProjectSettings.save err=%d)" % [v, new_version, ps_err])

	var path := "res://export_presets.cfg"
	print("[ver_tools] target abs path: ", ProjectSettings.globalize_path(path))
	var cfg := ConfigFile.new()
	var load_err := cfg.load(path)
	var msg := ""
	if load_err != OK:
		push_error("[ver_tools] ConfigFile.load(%s) FAILED, err=%d" % [path, load_err])
		msg = "Version %s set, but export_presets.cfg LOAD failed (err %d)" % [new_version, load_err]
	else:
		var updated := 0
		for s in cfg.get_sections():
			if s.begins_with("preset.") and s.ends_with(".options") and cfg.has_section_key(s, "version/code"):
				var before = cfg.get_value(s, "version/code")
				cfg.set_value(s, "version/code", patch)
				updated += 1
				print("[ver_tools]   %s version/code %s -> %d" % [s, str(before), patch])
		var save_err := cfg.save(path)
		print("[ver_tools] matched %d preset(s); ConfigFile.save err=%d" % [updated, save_err])
		if save_err != OK:
			push_error("[ver_tools] ConfigFile.save(%s) FAILED, err=%d" % [path, save_err])
			msg = "Version %s set, but export_presets.cfg SAVE failed (err %d)" % [new_version, save_err]
		elif updated == 0:
			push_warning("[ver_tools] No 'preset.*.options' section had a 'version/code' key")
			msg = "Version %s set, but found NO Android preset (version/code) to update" % new_version
		else:
			# Re-read from disk to confirm the write actually landed (catches editor clobber).
			var verify := ConfigFile.new()
			if verify.load(path) == OK:
				for s in verify.get_sections():
					if s.begins_with("preset.") and s.ends_with(".options") and verify.has_section_key(s, "version/code"):
						print("[ver_tools]   on-disk after save: %s version/code = %s" % [s, str(verify.get_value(s, "version/code"))])
			msg = "Version bumped to %s (Android code %d, %d preset(s))" % [new_version, patch, updated]

	print("[ver_tools] ", msg)
	EditorInterface.get_editor_toaster().push_toast(msg)
