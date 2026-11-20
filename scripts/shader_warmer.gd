class_name ShaderWarmer
extends Node
# COMPILE ONE GAME'S MENU-POSTER SHADERS, THE FIRST TIME THAT GAME IS OPENED (2026-11-19).
#
# The first time a 3-D menu poster opened after an install, its shaders were compiled on the spot: 1.2-3.6 s of frozen
# screen on a mid-range phone (Aliens 1.5 s, Whack 3.6 s), 2-4 s on a desktop. Godot keeps compiled shaders in its cache
# (user://shader_cache), so later openings were fast -- the cost was the first one. Warming EVERY game up front, behind
# a screen of its own, was tried and turned down the same day (the user: "it's not logical to wait so long for games I
# will never even play"); so a game is warmed when it is first tapped, behind PrepCard (prep_card.gd), and only then.
#
# The poster is built OFF SCREEN (a SubViewport no one sees) -- its own materials, lights and environment, so exactly the
# shader variants the real menu will need are compiled -- with all its meshes hidden, and then shown a STEP at a time:
# one kind of material under one kind of light (the base pass with the directional lights first, then each kind of
# omni and spot light), so a frame compiles one variant of one shader. After each step `step_done` is emitted and the
# next waits for `proceed()`: the card lights a dot, and nothing on screen is moving while a compile holds the frame.
#
# Done once per game per POSTER and GPU (`STAMPS`, 2026-11-20): the stamp is the engine's version, the GPU and a
# FINGERPRINT of the game's own files (scripts, shaders, scenes under its folder) and of the shared poster files
# (`SHARED_DEPS`) -- so an update that changes one game's poster prepares that game again, and only it; an update that
# leaves a game alone opens it at once. (It was the app's version: every update re-prepared every game, and a poster
# changed without a new version number was never prepared -- its first opening froze.) On the web, where WebGL keeps no
# compiled shaders between visits, once per visit.

signal step_done(step: int, steps: int)
signal finished

const STAMPS: String = "user://shader_warm.cfg"
const TAIL_FRAMES: int = 2               # frames the poster stays up after its last step, before it is let go

static var _warmed_this_visit: Dictionary = {}
static var _prints: Dictionary = {}       # game folder -> its fingerprint (worked out once a run)

# the shared files a poster's shaders can come from (each game's own folder is taken whole)
const SHARED_DEPS: Array = ["res://scripts/menu_poster.gd", "res://scripts/menu_poster3d.gd", "res://scripts/drawn_once.gd",
	"res://scripts/menu_darkness.gdshader", "res://scripts/menu_light.gdshader", "res://scripts/ball_art.gd",
	"res://scripts/monster_art.gd", "res://scripts/sleek.gd", "res://shared/scripts/card.gd"]
const PRINT_EXTS: Array = ["gd", "gdc", "gdshader", "gdshaderinc", "tscn", "tres", "remap"]

var folder: String = ""
var _waiting: bool = false
var _box: SubViewport = null             # the off-screen place the poster is built in
var _poster: Control = null
var _groups: Array = []                  # [[node, ...], ...] -- one group per kind of material, in order
var _steps: Array = []                   # [light stage, group] in order
var _next_step: int = 0
var _stage: String = ""
var _shown: int = -1                     # the group showing now
var _lights: Array = []
var _tail: int = 0
var _settle: int = -1                    # frames the poster has had to build itself (some make their 3-D late)
var _arrived: Array = []                 # its meshes, hidden as they entered the tree
var done: bool = false

static func _stamp_text(game_folder: String) -> String:
	return "%s|%s|%s|%s" % [Engine.get_version_info()["string"], RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(), _game_print(game_folder)]

# the game's fingerprint: an md5 of the md5s of its files. In an exported build a script is its tokenized .gdc (a change
# to a comment does not count) and a scene or resource its .remap's target
static func _game_print(game_folder: String) -> String:
	if _prints.has(game_folder):
		return _prints[game_folder]
	var sums: PackedStringArray = PackedStringArray()
	_sum_dir("res://" + game_folder, sums)
	for f in SHARED_DEPS:
		sums.append("%s=%s" % [f, _sum_file(f)])
	sums.sort()
	var pr: String = "\n".join(sums).md5_text()
	_prints[game_folder] = pr
	return pr

static func _sum_dir(dir_path: String, sums: PackedStringArray) -> void:
	for n in DirAccess.get_files_at(dir_path):
		if PRINT_EXTS.has(n.get_extension()):
			var full: String = dir_path.path_join(n)
			sums.append("%s=%s" % [full, _sum_file(full)])
	for sub in DirAccess.get_directories_at(dir_path):
		if sub != "art" and not sub.begins_with("."):
			_sum_dir(dir_path.path_join(sub), sums)

static func _sum_file(path: String) -> String:
	if path.get_extension() == "remap":
		var cf: ConfigFile = ConfigFile.new()
		if cf.load(path) == OK:
			return _sum_file(str(cf.get_value("remap", "path", "")))
		return ""
	if FileAccess.file_exists(path):
		return FileAccess.get_md5(path)
	if FileAccess.file_exists(path + "c"):            # a script in an export: its tokens
		return FileAccess.get_md5(path + "c")
	if FileAccess.file_exists(path + ".remap"):
		return _sum_file(path + ".remap")
	return ""

# whether this game's poster still has shaders to compile on this device
static func needed_for(game_folder: String) -> bool:
	if not ResourceLoader.exists("res://%s/scripts/menu_world.gd" % game_folder):
		return false
	if OS.has_feature("web"):
		return not _warmed_this_visit.has(game_folder)
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(STAMPS) != OK:
		return true
	return str(cf.get_value("games", game_folder, "")) != _stamp_text(game_folder)

static func _mark(game_folder: String) -> void:
	_warmed_this_visit[game_folder] = true
	if OS.has_feature("web"):
		return
	var cf: ConfigFile = ConfigFile.new()
	cf.load(STAMPS)
	cf.set_value("games", game_folder, _stamp_text(game_folder))
	cf.save(STAMPS)

func proceed() -> void:
	_waiting = false

func _ready() -> void:
	_box = SubViewport.new()
	_box.size = Vector2i(340, 600)
	_box.transparent_bg = true
	_box.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_box)
	get_tree().node_added.connect(_on_node_added)
	var p: String = "res://%s/scripts/menu_world.gd" % folder
	var scr: Script = load(p) if ResourceLoader.exists(p) else null
	var inst: Object = scr.new() if scr != null and scr.can_instantiate() else null
	if inst is Control:
		_poster = inst as Control
		_settle = 0
		_box.add_child(_poster)
	else:
		if inst is Node:
			(inst as Node).free()
		_finish.call_deferred()

# every mesh of the poster being warmed is hidden the moment it enters the tree, before it can be drawn
func _on_node_added(n: Node) -> void:
	if _poster != null and n is GeometryInstance3D and _poster.is_ancestor_of(n):
		(n as GeometryInstance3D).visible = false
		_arrived.append(n)

func _finish() -> void:
	if done:
		return
	done = true
	set_process(false)
	_mark(folder)
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if _poster != null:
		_poster.queue_free()
		_poster = null
	if _box != null:
		_box.queue_free()
		_box = null
	finished.emit()

func _process(_delta: float) -> void:
	if _waiting or _poster == null:
		return
	if _settle < 2:
		_settle += 1
		if _settle == 2:
			if _arrived.is_empty():
				_finish()             # a 2-D poster: nothing of its own to compile
			else:
				_plan_steps()
		return
	if _next_step < _steps.size():
		var stp: Array = _steps[_next_step]
		if str(stp[0]) != _stage:
			_stage = str(stp[0])
			for lv in _lights:
				if is_instance_valid(lv):
					var k: String = _light_kind(lv as Light3D)
					(lv as Light3D).visible = k.begins_with("dir") or k == _stage
		_show_group(_shown, false)
		_shown = int(stp[1])
		_show_group(_shown, true)
		_next_step += 1
		_waiting = true
		step_done.emit(_next_step, _steps.size())
		return
	_tail += 1
	if _tail > TAIL_FRAMES:
		_finish()

func _show_group(i: int, on: bool) -> void:
	if i < 0 or i >= _groups.size():
		return
	for n in _groups[i]:
		if is_instance_valid(n):
			(n as Node3D).visible = on

# a light by the shader variant it calls for: the directional ones go with the base pass, the others each add a pass
func _light_kind(l: Light3D) -> String:
	var k: String = "dir" if l is DirectionalLight3D else ("spot" if l is SpotLight3D else "omni")
	return k + (" shadow" if l.shadow_enabled else "")

# the poster's meshes grouped by the kind of material they draw with, and THE STEPS: each kind shown ALONE, first under
# the directional lights only (the base pass), then under each kind of other light in turn
func _plan_steps() -> void:
	_lights = _poster.find_children("*", "Light3D", true, false)
	var by_key: Dictionary = {}
	for n in _arrived:
		if not is_instance_valid(n):
			continue
		var gi: GeometryInstance3D = n
		var key: String = _material_key(gi)
		if not by_key.has(key):
			by_key[key] = []
			_groups.append(by_key[key])
		(by_key[key] as Array).append(gi)
		gi.visible = false
	var stages: Array = ["base"]
	for lv in _lights:
		var k: String = _light_kind(lv as Light3D)
		if not k.begins_with("dir") and not stages.has(k):
			stages.append(k)
	for st in stages:
		for gi2 in _groups.size():
			_steps.append([st, gi2])

func _material_key(gi: GeometryInstance3D) -> String:
	if gi is Label3D:
		return "label3d"
	var m: Material = gi.material_override
	if m == null and gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null and (gi as MeshInstance3D).mesh.get_surface_count() > 0:
		m = (gi as MeshInstance3D).get_active_material(0)
	if m == null and gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null and (gi as MultiMeshInstance3D).multimesh.mesh != null:
		m = (gi as MultiMeshInstance3D).multimesh.mesh.surface_get_material(0)
	if m is ShaderMaterial:
		return "shader %d" % (m as ShaderMaterial).shader.get_instance_id()
	if m is BaseMaterial3D:
		var b: BaseMaterial3D = m
		return "std %d %d %d %d %d %d %d %d %d %d" % [b.shading_mode, b.transparency, int(b.albedo_texture != null), int(b.normal_enabled),
			int(b.emission_enabled), int(b.emission_texture != null), int(b.clearcoat_enabled), b.cull_mode, b.emission_operator,
			b.billboard_mode]
	return "default"
