class_name GamePacks
extends RefCounted
# A GAME'S OWN PACK, FETCHED THE FIRST TIME IT IS OPENED -- on the web only (2026-11-20). The web build's one pack was
# 60 MB and every visitor downloaded all of it; most play two or three games. devtools/split_web_pack.py cuts the
# exported pack into a base (the app, everything shared, every game's autoloads and chooser tile) and one pack per game
# (packs/<folder>.pck beside the page). The chooser (`_launch`) asks `needed()` and, if so, `fetch()`es it -- the game's
# "Getting it ready" card (prep_card.gd) shows the download -- before loading the game's scene. A pack is kept in the
# browser's storage (user://packs, one per app version), so a later visit loads it without downloading it again.
# A desktop or Android build has everything in its one pack: `needed()` is false there.

static var _loaded: Dictionary = {}

# whether this game's files are still to be fetched: on the web, and its main scene not yet in any loaded pack
static func needed(folder: String) -> bool:
	if not (OS.has_feature("web") or OS.has_environment("NOMIZO_PACKS_URL")) or _loaded.has(folder):
		return false
	return not ResourceLoader.exists("res://%s/scenes/main.tscn" % folder)

# fetch the game's pack (unless this version's is already stored) and load it; `progress` gets 0..1 as it comes.
# true when the game's files are there
static func fetch(host: Node, folder: String, progress: Callable) -> bool:
	DirAccess.make_dir_recursive_absolute("user://packs")
	var path: String = "user://packs/%s-%s.pck" % [folder, MainGlobals.version]
	if not FileAccess.file_exists(path):
		# an earlier version's copy of this game's pack is of no further use
		for f in DirAccess.get_files_at("user://packs"):
			if f.begins_with(folder + "-"):
				DirAccess.remove_absolute("user://packs/" + f)
		# (the body comes back in memory and is written here: on the web `download_file` wrote nothing; a pack is a few MB)
		var req: HTTPRequest = HTTPRequest.new()
		host.add_child(req)
		# (the lambda writes into the array: a captured local would be a copy)
		var state: Array = [false, 0, 0, PackedByteArray()]
		req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			state[0] = true
			state[1] = result
			state[2] = code
			state[3] = body)
		if req.request(_base_url() + "packs/%s.pck?v=%s" % [folder, MainGlobals.version]) != OK:
			req.queue_free()
			return false
		while not bool(state[0]):
			await host.get_tree().process_frame
			var total: int = req.get_body_size()
			if total > 0:
				progress.call(clampf(float(req.get_downloaded_bytes()) / float(total), 0.0, 1.0))
		req.queue_free()
		var body: PackedByteArray = state[3]
		if int(state[1]) != HTTPRequest.RESULT_SUCCESS or int(state[2]) != 200 or body.size() < 64:
			return false
		var out: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			return false
		out.store_buffer(body)
		out.close()
	progress.call(1.0)
	if not ProjectSettings.load_resource_pack(path, false):
		DirAccess.remove_absolute(path)          # a damaged copy: fetched afresh next time
		return false
	_loaded[folder] = true
	return true

# where the page was loaded from: the packs sit beside it
static func _base_url() -> String:
	# (a test of a split build in the desktop engine names the server: devtools/split_web_pack.py's header)
	if OS.has_environment("NOMIZO_PACKS_URL"):
		return OS.get_environment("NOMIZO_PACKS_URL")
	var href: String = str(JavaScriptBridge.eval("window.location.href.split('#')[0].split('?')[0]", true))
	return href.substr(0, href.rfind("/") + 1)
