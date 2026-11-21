@tool
extends RefCounted
# SPLIT THE WEB BUILD'S PACK (2026-11-21; run by split_export.gd at the end of every Web export): a base pack for the
# app, and one small pack per game, fetched the first time the game is opened (scripts/game_packs.gd). The web build's
# one pack held every game (~50 MB, all downloaded before the chooser came up); most visitors play two or three games.
# In GDScript, inside the project, so a fresh clone of this repo needs nothing but the editor to export the web build.
#
# split("res://export/web") reads <dir>/nomizo.pck (as the "Web" export wrote it) and writes:
#   <dir>/nomizo.pck         the BASE: the engine's own files, everything shared, every game's AUTOLOADS and every
#                            script they reach (the app registers them at start), and each game's chooser tile
#   <dir>/packs/<game>.pck   the rest of the game's folder, the sounds named after it (art/sounds/<game>_*), any
#                            shared art/ file only that game uses, and the imported / converted files those point to
# and puts the base pack's new size into <dir>/nomizo.html (the loader's progress bar reads it).
# HIDDEN games (MainCfg.HIDDEN_GAMES, or a row commented out of MainCfg.games) get no pack: their files are left out.
# It REFUSES to write when a game names a file (by path, or a script by its class_name) that would land in another
# game's pack. Run on a pack already split, it changes nothing.

const ALIGN: int = 32
const PACK_REL_FILEBASE: int = 2

var log_lines: PackedStringArray = []

var _games: Dictionary = {}          # folder -> true
var _hidden: Dictionary = {}         # folder -> true
var _autoloads: Dictionary = {}      # path (no res://) -> true: the autoloads and everything they reach
var _classes: Dictionary = {}        # class_name -> path
var _texts: Dictionary = {}          # owner ("shared" or a game folder) -> all its text
var _src_texts: Dictionary = {}      # path -> text, for the scripts, scenes and resources
var _text_parts: Dictionary = {}     # owner -> PackedStringArray, joined into _texts

func _say(line: String) -> void:
	log_lines.append(line)
	print(line)

# true when the export folder now holds a split build (or already did); false, with the reason logged, otherwise
func split(out_dir: String) -> bool:
	var pck: String = out_dir.path_join("nomizo.pck")
	var data: PackedByteArray = FileAccess.get_file_as_bytes(pck)
	if data.size() < 104 or data.slice(0, 4).get_string_from_ascii() != "GDPC":
		_say("split: %s is not a Godot pack" % pck)
		return false
	var ver: int = data.decode_u32(4)
	if ver < 3:
		_say("split: pack format %d not handled" % ver)
		return false
	var head: Dictionary = {
		"ver": ver, "major": data.decode_u32(8), "minor": data.decode_u32(12), "patch": data.decode_u32(16),
		"flags": data.decode_u32(20), "tail": data.slice(40, 104)}
	var entries: Array = _read_entries(data)
	_scan_project()

	# what each .import / .remap points to: a converted file used by more than one owner stays in the base
	var target_owner: Dictionary = {}
	var godot_ref: RegEx = RegEx.create_from_string("\"res://(\\.godot/[^\"]+)\"")
	for e in entries:
		var ename: String = e["name"]
		if ename.ends_with(".import") or ename.ends_with(".remap"):
			var own: String = _owner_of_source(ename)
			var buf: PackedByteArray = e["data"]
			for m in godot_ref.search_all(buf.get_string_from_utf8()):
				var t: String = m.get_string(1)
				var prev: String = str(target_owner.get(t, ""))
				target_owner[t] = own if (prev == "" or prev == own) else "base"

	var packs: Dictionary = {}
	for e in entries:
		var ename: String = e["name"]
		var own: String = "base"
		if ename.begins_with(".godot/imported/") or ename.begins_with(".godot/exported/"):
			own = str(target_owner.get(ename, "base"))
		elif ename.begins_with(".godot/") or not ename.contains("/"):
			own = "base"
		else:
			own = _owner_of_source(ename)
		if own == "drop":
			continue
		if not packs.has(own):
			packs[own] = []
		(packs[own] as Array).append(e)

	if packs.size() == 1:
		_say("split: %s holds no game's own files -- already split; left as it is" % pck)
		return true
	if not _check(packs):
		return false

	var pdir: String = out_dir.path_join("packs")
	DirAccess.make_dir_recursive_absolute(pdir)
	for f in DirAccess.get_files_at(pdir):           # a game no longer listed leaves no stale pack behind
		if f.ends_with(".pck"):
			DirAccess.remove_absolute(pdir.path_join(f))
	var base_entries: Array = packs["base"]
	packs.erase("base")
	var base_size: int = _write_pck(pck, head, base_entries)
	if base_size < 0:
		_say("split: could not write %s" % pck)
		return false
	var games_sorted: Array = packs.keys()
	games_sorted.sort()
	var total: int = 0
	var lines: PackedStringArray = []
	for g in games_sorted:
		var n: int = _write_pck(pdir.path_join(str(g) + ".pck"), head, packs[g])
		if n < 0:
			_say("split: could not write the pack of %s" % g)
			return false
		total += n
		lines.append("  %-14s %.2f MB" % [g, float(n) / 1e6])
	var html: String = out_dir.path_join("nomizo.html")
	if FileAccess.file_exists(html):
		var h: String = FileAccess.get_file_as_string(html)
		h = RegEx.create_from_string("\"nomizo\\.pck\":\\d+").sub(h, "\"nomizo.pck\":%d" % base_size, true)
		var hf: FileAccess = FileAccess.open(html, FileAccess.WRITE)
		hf.store_string(h)
		hf.close()
	_say("base %.1f MB, %d game packs %.1f MB" % [float(base_size) / 1e6, games_sorted.size(), float(total) / 1e6])
	for line in lines:
		_say(line)
	return true

# ---- the pack format (v3+: a header, the files, then the directory; offsets from the file base when flag 2 is set)

func _read_entries(data: PackedByteArray) -> Array:
	var flags: int = data.decode_u32(20)
	var file_base: int = data.decode_u64(24) if (flags & PACK_REL_FILEBASE) != 0 else 0
	var pos: int = data.decode_u64(32)
	var count: int = data.decode_u32(pos)
	pos += 4
	var out: Array = []
	for _i in count:
		var ln: int = data.decode_u32(pos)
		pos += 4
		var ename: String = data.slice(pos, pos + ln).get_string_from_utf8()
		pos += ln
		var off: int = data.decode_u64(pos)
		var sz: int = data.decode_u64(pos + 8)
		var md5: PackedByteArray = data.slice(pos + 16, pos + 32)
		var fflags: int = data.decode_u32(pos + 32)
		pos += 36
		out.append({"name": ename, "data": data.slice(file_base + off, file_base + off + sz), "md5": md5, "flags": fflags})
	return out

func _pad(f: FileAccess) -> void:
	var extra: int = int(f.get_position() % ALIGN)
	if extra != 0:
		var zeros: PackedByteArray = []
		zeros.resize(ALIGN - extra)
		f.store_buffer(zeros)

func _write_pck(path: String, head: Dictionary, entries: Array) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return -1
	f.store_buffer("GDPC".to_ascii_buffer())
	f.store_32(int(head["ver"]))
	f.store_32(int(head["major"]))
	f.store_32(int(head["minor"]))
	f.store_32(int(head["patch"]))
	f.store_32(int(head["flags"]) | PACK_REL_FILEBASE)
	f.store_64(0)                                      # the file base and the directory, filled in below
	f.store_64(0)
	f.store_buffer(head["tail"])
	_pad(f)
	var file_base: int = f.get_position()
	var offsets: Array = []
	for e in entries:
		offsets.append(f.get_position() - file_base)
		f.store_buffer(e["data"])
		_pad(f)
	var dir_off: int = f.get_position()
	f.store_32(entries.size())
	for i in entries.size():
		var e: Dictionary = entries[i]
		var nb: PackedByteArray = str(e["name"]).to_utf8_buffer()
		var pad: int = (4 - nb.size() % 4) % 4
		nb.resize(nb.size() + pad)                      # zero-filled
		f.store_32(nb.size())
		f.store_buffer(nb)
		f.store_64(int(offsets[i]))
		f.store_64((e["data"] as PackedByteArray).size())
		f.store_buffer(e["md5"])
		f.store_32(int(e["flags"]))
	f.seek(24)
	f.store_64(file_base)
	f.store_64(dir_off)
	f.seek_end()
	var n: int = f.get_position()
	f.close()
	return n

# ---- who owns what

static func _strip_ext(path: String) -> String:
	var s: String = path
	for ext in [".remap", ".import"]:
		if s.ends_with(ext):
			s = s.substr(0, s.length() - str(ext).length())
	if s.ends_with(".gdc"):
		s = s.substr(0, s.length() - 1)
	return s

func _owner_of_source(path: String) -> String:
	var src: String = _strip_ext(path)
	var top: String = src.get_slice("/", 0)
	if _games.has(top):
		if _autoloads.has(src) or src.ends_with("/art/game_screen_200.png"):
			return "base"
		return "drop" if _hidden.has(top) else top
	var m: RegExMatch = RegEx.create_from_string("^art/sounds/([a-z0-9]+)_").search(src)
	if m != null and _games.has(m.get_string(1)):
		return "drop" if _hidden.has(m.get_string(1)) else m.get_string(1)
	if src.begins_with("art/") and not _autoloads.has(src):
		return _shared_asset_owner(src)
	return "base"

# a shared file used by exactly ONE playable game goes to that game's pack; used only by hidden games it is left out;
# named by the shared code, by several games or by nothing it stays in the base
func _shared_asset_owner(src: String) -> String:
	var fname: String = src.get_file()
	var stem: String = fname.get_basename()
	var keys: Array = [fname, stem]
	var m: RegExMatch = RegEx.create_from_string("^(.*?_)\\d+$").search(stem)   # a numbered set ("rain_" + str(k))
	if m != null and m.get_string(1).length() >= 4:
		keys.append(m.get_string(1))
	var users: Dictionary = {}
	for own in _texts:
		var text: String = _texts[own]
		for k in keys:
			if text.contains(str(k)):
				users[own] = true
				break
	if users.is_empty() or users.has("shared"):
		return "base"
	var playable: Array = []
	for u in users:
		if not _hidden.has(u):
			playable.append(u)
	if playable.is_empty():
		return "drop"
	return str(playable[0]) if playable.size() == 1 else "base"

# CHECK: every file a game names (by path, or a script by its class) is in the base or in that game's own pack
func _check(packs: Dictionary) -> bool:
	var where: Dictionary = {}
	for own in packs:
		for e in packs[own]:
			where[_strip_ext(e["name"])] = own
	var ref_rx: RegEx = RegEx.create_from_string("res://([^\"'%]+?\\.[a-z0-9]+)[\"']")
	var problems: Dictionary = {}
	for own in packs:
		if own == "base":
			continue
		for e in packs[own]:
			var src: String = _strip_ext(e["name"])
			if not (src.ends_with(".gd") or src.ends_with(".tscn") or src.ends_with(".tres") or src.ends_with(".gdshader")):
				continue
			if not _src_texts.has(src):
				continue
			var text: String = _src_texts[src]
			var refs: Dictionary = {}
			for m in ref_rx.search_all(text):
				refs[m.get_string(1)] = true
			for cname in _classes:
				if text.contains(cname) and _word(cname).search(text) != null:
					refs[_classes[cname]] = true
			for r in refs:
				var w: String = str(where.get(r, ""))
				if w == "" and FileAccess.file_exists("res://" + r) and not str(r).ends_with(".gd") and not _autoloads.has(r):
					w = "MISSING"
				if w != "" and w != "base" and w != own:
					problems["%s: %s -> %s (in %s)" % [own, src, r, w]] = true
	if problems.is_empty():
		return true
	var keys: Array = problems.keys()
	keys.sort()
	for k in keys:
		_say("  !! " + str(k))
	_say("split: %d files a game needs are not in its reach -- the pack was NOT split" % keys.size())
	return false

var _word_cache: Dictionary = {}

func _word(cname: String) -> RegEx:
	if not _word_cache.has(cname):
		_word_cache[cname] = RegEx.create_from_string("\\b%s\\b" % cname)
	return _word_cache[cname]

# ---- the project: its games, its autoloads and what they reach, every class, every text

func _scan_project() -> void:
	var cfg: String = FileAccess.get_file_as_string("res://scripts/config.gd")
	var listed: Dictionary = {}
	for m in RegEx.create_from_string("(?m)^\\s*\\[\"([a-z0-9_]+)\",").search_all(cfg):
		listed[m.get_string(1)] = true
	var hb: RegExMatch = RegEx.create_from_string("(?ms)^const HIDDEN_GAMES[^=]*=\\s*\\[(.*?)\\]").search(cfg)
	for d in DirAccess.get_directories_at("res://"):
		if FileAccess.file_exists("res://%s/scripts/globals.gd" % d):
			_games[d] = true
			if not listed.has(d):
				_hidden[d] = true          # a row commented out of MainCfg.games (matchws) cannot be opened either
	if hb != null:
		for m in RegEx.create_from_string("\"([a-z0-9_]+)\"").search_all(hb.get_string(1)):
			_hidden[m.get_string(1)] = true

	_walk("res://")
	for own in _text_parts:
		_texts[own] = "\n" + "\n".join(_text_parts[own])
	var cls_rx: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z0-9_]+)")
	for p in _src_texts:
		if str(p).ends_with(".gd"):
			var m: RegExMatch = cls_rx.search(_src_texts[p])
			if m != null:
				_classes[m.get_string(1)] = p

	var al_rx: RegEx = RegEx.create_from_string("(?m)^[A-Za-z0-9_]+=\"\\*res://(.+)\"\\s*$")
	for m in al_rx.search_all(FileAccess.get_file_as_string("res://project.godot")):
		_autoloads[m.get_string(1)] = true
	var path_rx: RegEx = RegEx.create_from_string("res://([^\"']+)")
	var todo: Array = []
	for k in _autoloads:
		if str(k).ends_with(".gd"):
			todo.append(k)
	while not todo.is_empty():
		var src: String = todo.pop_back()
		if not _src_texts.has(src):
			continue
		var text: String = _src_texts[src]
		var deps: Dictionary = {}
		for m in path_rx.search_all(text):
			deps[m.get_string(1)] = true
		for cname in _classes:
			if text.contains(cname) and _word(cname).search(text) != null:
				deps[_classes[cname]] = true
		for dpath in deps:
			if not _autoloads.has(dpath) and FileAccess.file_exists("res://" + str(dpath)):
				_autoloads[dpath] = true
				if str(dpath).ends_with(".gd"):
					todo.append(dpath)

func _walk(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		if dir == "res://" and (d.begins_with(".") or d == "export"):
			continue
		_walk(dir.path_join(d))
	var rel_dir: String = dir.trim_prefix("res://").lstrip("/")    # ("res://".path_join(d) gives res:///d)
	var top: String = rel_dir.get_slice("/", 0)
	var own: String = top if _games.has(top) else "shared"
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres") or f.ends_with(".gdshader") \
				or f.ends_with(".cfg") or f == "project.godot":
			var text: String = FileAccess.get_file_as_string(dir.path_join(f))
			# (a PackedStringArray is a VALUE: appended through a cast it grew a copy, and every owner's text was empty)
			var parts: PackedStringArray = _text_parts.get(own, PackedStringArray())
			parts.append(text)
			_text_parts[own] = parts
			var rel: String = rel_dir.path_join(f) if rel_dir != "" else f
			_src_texts[rel] = text
