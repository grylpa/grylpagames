extends RefCounted
class_name GameTile

# A game's chooser tile, in the frame the chooser's LIST rows put it in.
#
# Used by the tutorial's opening balloon and by the instructions screen's title bar, so a player sees
# the same picture in the same frame wherever the app tells them which game they are in.
#
# The frame is THREE stacked nodes, not one bordered box — copied from
# scenes/game_select_button.tscn, where each one is load-bearing:
#
#   clipper   rounded, BORDERLESS, clip_children = CLIP_CHILDREN_ONLY. Its drawn shape is the mask,
#             which is what rounds the picture's corners.
#   texture   fills the clipper, scaled without regard to aspect, so the tile reaches the frame on
#             every side.
#   frame     the bordered panel, drawn ON TOP, so the border sits over the image edge.
#
# Approximating it — one frame with the texture inset and KEEP_ASPECT_CENTERED — was tried first and
# failed in exactly the two ways those nodes prevent: the tile floated inside the frame instead of
# filling it, and its square corners cut across the rounding.

# The values game_chooser.gd::add_game() applies over that stylebox in list_mode. The radius is NOT
# scaled for mobile, because the chooser does not scale it either — scaling here would make the two
# frames visibly disagree on a device.
const FRAME_COLOR: Color = Color(155.0 / 255.0, 100.0 / 255.0, 0.0, 1.0)
const FRAME_WIDTH: int = 2
const FRAME_RADIUS: int = 8

# `side` is the square's size in board units; callers pass a DESKTOP size and this scales it.
#
# ATTACH, not make-and-return. The nodes are built only AFTER the box is in the tree, because that
# is the one thing that separated this from the tutorial balloon's working copy: `clip_children` is
# a property of the CANVAS ITEM, and a subtree built detached has no canvas item to set it on. Built
# detached, the flag silently did nothing and the tile came out as the clipper's own panel with a
# round frame over it — first grey, then white when the mask colour was made explicit.
#
# So the order here is load-bearing and matches scripts/tutorial.gd exactly: parent the box, then
# the clipper, then the picture, then the frame.
static func attach(parent: Node, side: int) -> Control:
	if parent == null or not is_instance_valid(parent):
		return null
	var box: Control = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px: float = float(MainGlobals.ui_font_size(side))
	box.custom_minimum_size = Vector2(px, px)
	box.size = Vector2(px, px)
	parent.add_child(box)

	var clip: PanelContainer = PanelContainer.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var clip_sb: StyleBoxFlat = StyleBoxFlat.new()
	clip_sb.set_corner_radius_all(FRAME_RADIUS)
	clip.add_theme_stylebox_override("panel", clip_sb)
	box.add_child(clip)

	var pic: TextureRect = TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(pic)

	var frame: PanelContainer = PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(FRAME_WIDTH)
	sb.border_color = FRAME_COLOR
	sb.border_blend = true
	sb.set_corner_radius_all(FRAME_RADIUS)
	frame.add_theme_stylebox_override("panel", sb)
	box.add_child(frame)
	return box

# Put a game's tile into an attached box. Returns false when the game has no icon, so the caller can
# drop the whole box rather than leave an empty frame on screen.
static func set_icon(box: Control, folder: String) -> bool:
	if box == null or box.get_child_count() == 0:
		return false
	var tex: Texture2D = load_icon(folder)
	var pic: TextureRect = (box.get_child(0) as Control).get_child(0) as TextureRect
	if tex == null or pic == null:
		return false
	pic.texture = tex
	return true

# The game's own chooser thumbnail. Every game that ships has one.
static func load_icon(folder: String) -> Texture2D:
	if folder.is_empty():
		return null
	var path: String = "res://%s/art/game_screen_200.png" % folder
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

# The folder a game's scene belongs to, from its SCRIPT PATH (`res://<folder>/scripts/main.gd`).
#
# Not from the game's save prefix or from MainCfg: those equal the folder today but are independent
# strings, and the icon must not be the thing that breaks if a folder is ever renamed.
static func folder_of(host: Node) -> String:
	if host == null or not is_instance_valid(host):
		return ""
	var script: Script = host.get_script()
	if script == null:
		return ""
	var parts: PackedStringArray = script.resource_path.replace("res://", "").split("/")
	return parts[0] if parts.size() >= 2 else ""
