extends Node

# DinoG autoload — shared state + image source handling for the Dino game.

var starting_level_id: int = 1

var game: GenericGameUtil = GenericGameUtil.new("Dino", "dino", 0, 2, 0)

const WHITE: Color = Color(1, 1, 1, 1)
const PEOPLE_YELLOW: Color = Color(1, 0.8039216, 0, 1)

# Shared res://art/people set (same list weris/friends use). Kept as an explicit
# list because DirAccess cannot enumerate res:// image sources in exported builds
# (only the imported textures ship) — probing known names with ResourceLoader.exists
# is export-safe. dinos are contiguous dino1..dinoN and are probed numerically.
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

func default_color(folder: String) -> Color:
	if folder.strip_edges() == "people":
		return PEOPLE_YELLOW
	return WHITE  # dinos and any other folder default to white

func background_for(folders: Array) -> String:
	# any dino folder -> the dino background; otherwise the weris grass background
	for f in folders:
		if str(f).strip_edges() == "dinos":
			return "res://art/dinos/bk1.jpg"
	return "res://art/grass.png"

func save_settings() -> void:
	game.save_settings([starting_level_id])

func load_settings() -> void:
	var settings: Array = game.read_settings()
	if settings.size() > 0:
		starting_level_id = int(settings[0])
