@tool
extends EditorScript

const PROJECT_VERSION_KEY := "application/config/version"

func _run() -> void:
	var v := str(ProjectSettings.get_setting(PROJECT_VERSION_KEY, "0.0.0"))
	var parts := v.split(".")
	while parts.size() < 3:
		parts.append("0")

	var major := int(parts[0])
	var minor := int(parts[1])
	var patch := int(parts[2]) + 1

	var new_version := "%d.%d.%d" % [major, minor, patch]

	# 1) Update project version (this is the "config/version" field)
	ProjectSettings.set_setting(PROJECT_VERSION_KEY, new_version)
	ProjectSettings.save()

	# 2) Update Android export preset version/code to match patch
	_sync_android_version_code(patch, new_version)

	print("Version bumped to ", new_version, " (Android version/code = ", patch, ")")

func _sync_android_version_code(patch: int, _new_version: String) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	if err != OK:
		push_error("Couldn't load res://export_presets.cfg (err %d). Did you create an export preset yet?" % err)
		return

	var changed := false

	for section in cfg.get_sections():
		# Android presets store options under: "preset.N.options"
		if not section.begins_with("preset.") or not section.ends_with(".options"):
			continue

		# Heuristic: only touch presets that look like Android (they have version/code)
		if not cfg.has_section_key(section, "version/code"):
			continue

		cfg.set_value(section, "version/code", patch)
		# Optional: force the preset version string to match too.
		# (If you prefer relying on project version fallback, comment this out.)
		# if cfg.has_section_key(section, "version/name"):
		# 	cfg.set_value(section, "version/name", _new_version)

		changed = true

	if changed:
		cfg.save("res://export_presets.cfg")
	else:
		print("No Android-like presets found (no preset.*.options with version/code).")
