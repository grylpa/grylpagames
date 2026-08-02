extends Node

# DinobackG autoload — shared state, card categories and settings for Dino N-Back.
#
# Five CATEGORIES supply the card faces. Two are photographs, three are drawn:
#
#   dinos, people    images from the shared res://art folders
#   letters          A..Z minus the confusable ones
#   digits           2..9
#   shapes           filled geometric shapes
#
# The three drawn categories carry a second, implied dimension: COLOR. A level's rule can ask
# about the symbol, the color, or both — see level_config.gd. Photographs have no color of their
# own, so an image category can only ever be matched on identity.

var starting_level_id: int = 1

var game: GenericGameUtil = GenericGameUtil.new("Dino N-Back", "dinoback", 0, 2, 0)

const IMAGE_CATEGORIES: Array = ["dinos", "people"]
const DRAWN_CATEGORIES: Array = ["letters", "digits", "shapes"]

const CARD_WHITE: Color = Color(1, 1, 1, 1)
const CARD_YELLOW: Color = Color(1, 0.8039216, 0, 1)  # exact weris/friends card-border yellow

# --- symbol pools -------------------------------------------------------------------------------
# Ordered MOST DISTINCT FIRST, and a level takes the first `pool_size` of them, so a small pool is
# always the most legible subset rather than a random one. That matters more here than variety: an
# n-back level lives or dies on whether two cards are instantly telling apart.
#
# The letter and digit lists are chosen so the two can be mixed in one level without a single
# confusable pair — no I/O/Q against 1/0, no S against 5, no Z against 2, no B against 8.
const LETTERS: Array = ["A", "K", "R", "E", "M", "H", "T", "P", "F", "D", "N", "V", "W", "X"]
const DIGITS: Array = ["4", "7", "3", "6", "9"]

# No DIAMOND: a rotated square is not a distinct shape, it is a square that looks tilted.
const SHAPES: Array = ["circle", "square", "triangle", "star", "plus", "hexagon", "pentagon"]

# --- color palette ------------------------------------------------------------------------------
# Also ordered most-distinct-first, so `num_colors: 3` gets blue/yellow/red rather than three
# neighbours. Red and green are deliberately far apart in the order: a level with only 2 or 3
# colors never puts that pair together.
const COLORS: Array = [
	Color(0.35, 0.62, 0.98, 1.0),   # blue
	Color(0.99, 0.82, 0.22, 1.0),   # yellow
	Color(0.94, 0.32, 0.29, 1.0),   # red
	Color(0.36, 0.82, 0.42, 1.0),   # green
	Color(0.74, 0.48, 0.95, 1.0),   # purple
	Color(0.99, 0.56, 0.20, 1.0),   # orange
]

# Shared res://art/people set (same list weris/friends/dino use). Kept as an explicit list because
# DirAccess cannot enumerate res:// image sources in exported builds (only the imported textures
# ship) — probing known names with ResourceLoader.exists is export-safe. dinos are contiguous
# dino1..dinoN and are probed numerically.
var _people_file_names: Array = [
	"Alina Vetrova", "Anand_Iyer", "Barbara_Coleman", "Beverly_Mitchel", "Carolyn_Ramirez",
	"Curtis_Scott", "David_Okoro", "Dmitri Volodin", "Eleni Makri", "Emma_Harris",
	"Erik Lundgren", "Evelyn_Thompson", "Farida_Abbasi", "Freja Nyberg", "Gladys_Rivera",
	"Gloria_Navarro", "Hassan_Odeh", "Helen_Stein", "Ingrid Holmgaard", "Irina Koval",
	"Ivan Korchev", "James_Carter", "Joe_Hamilton", "Karl_Schulz", "Katerina Theodorou",
	"Kenji_Nakamura", "Leonard_Hicks", "Linnea Rautio", "Lucia_Moretti", "Marcia_Wallace",
	"Maria_Alvarez", "Maria Kyrgiou", "Mattias Haugen", "Molly_Bishop", "Naomi_Blake",
	"Natalia Rudnikova", "Nikos Manolaris", "Oscar_Vargas", "Patricia_O_Connor", "Pavel Serkin",
	"Petros Kalivis", "Rajesh_Mehta", "Samir_Haddad", "Sofia Mantzou", "Soren Vikström",
	"Stavros Kanelos", "SungWoo_Kim", "Takeo_Yamamoto", "Tanya_Greene", "Yannis Drepanos",
]

var _folder_cache: Dictionary = {}

func is_drawn(category: String) -> bool:
	return DRAWN_CATEGORIES.has(category.strip_edges())

func is_image(category: String) -> bool:
	return IMAGE_CATEGORIES.has(category.strip_edges())

# The symbols a drawn category can pose, most distinct first.
func symbols_of(category: String) -> Array:
	match category.strip_edges():
		"letters":
			return LETTERS
		"digits":
			return DIGITS
		"shapes":
			return SHAPES
	return []

func color_at(idx: int) -> Color:
	return COLORS[idx % COLORS.size()]

# --- image categories ---------------------------------------------------------------------------

func _load_folder(folder: String) -> Array:
	var key: String = folder.strip_edges()
	if _folder_cache.has(key):
		return _folder_cache[key]
	var texs: Array = []
	if key == "dinos":
		for i in range(1, 400):
			var p: String = "res://art/dinos/dino%d.jpg" % i
			if ResourceLoader.exists(p):
				texs.append(load(p))
	elif key == "people":
		for fn in _people_file_names:
			var p: String = "res://art/people/%s.jpg" % fn
			if ResourceLoader.exists(p):
				texs.append(load(p))
	_folder_cache[key] = texs
	return texs

func num_images(folder: String) -> int:
	return _load_folder(folder).size()

func image_at(folder: String, idx: int) -> Texture2D:
	var a: Array = _load_folder(folder)
	if a.is_empty():
		return null
	return a[idx % a.size()]

# White is reserved for the dino photos, as in the Dino game. Everything else — people and all
# three drawn categories — gets the yellow zigzag: the drawn faces are a dark plate with one bright
# symbol, and a white frame around that reads as a second bright element competing with the symbol.
func default_border(category: String) -> Color:
	if category.strip_edges() == "dinos":
		return CARD_WHITE
	return CARD_YELLOW

func background_for(_categories: Array) -> String:
	# the dino background for every level, drawn or photographic, so the game reads as one place
	return "res://art/dinos/bk1.jpg"

# --- settings -----------------------------------------------------------------------------------

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = int(settings[0])
