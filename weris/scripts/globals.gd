extends Node

var starting_level := 1

# Study phase: time the player has to memorize the person (seconds)
var study_time_sec := 10
# Find phase: time limit to find the person in the grid (seconds)
var find_time_sec := 30

var game := GenericGameUtil.new("Weris", "weris", 0, 5, 0)

var _people_file_names = [
	"Alina Vetrova",
	"Anand_Iyer",
	"Barbara_Coleman",
	"Beverly_Mitchel",
	"Carolyn_Ramirez",
	"Curtis_Scott",
	"David_Okoro",
	"Dmitri Volodin",
	"Eleni Makri",
	"Emma_Harris",
	"Erik Lundgren",
	"Evelyn_Thompson",
	"Farida_Abbasi",
	"Freja Nyberg",
	"Gladys_Rivera",
	"Gloria_Navarro",
	"Hassan_Odeh",
	"Helen_Stein",
	"Ingrid Holmgaard",
	"Irina Koval",
	"Ivan Korchev",
	"James_Carter",
	"Joe_Hamilton",
	"Karl_Schulz",
	"Katerina Theodorou",
	"Kenji_Nakamura",
	"Leonard_Hicks",
	"Linnea Rautio",
	"Lucia_Moretti",
	"Marcia_Wallace",
	"Maria_Alvarez",
	"Maria Kyrgiou",
	"Mattias Haugen",
	"Molly_Bishop",
	"Naomi_Blake",
	"Natalia Rudnikova",
	"Nikos Manolaris",
	"Oscar_Vargas",
	"Patricia_O_Connor",
	"Pavel Serkin",
	"Petros Kalivis",
	"Rajesh_Mehta",
	"Samir_Haddad",
	"Sofia Mantzou",
	"Soren Vikström",
	"Stavros Kanelos",
	"SungWoo_Kim",
	"Takeo_Yamamoto",
	"Tanya_Greene",
	"Yannis Drepanos",
]

var _people = []
var _people_names = []
var _people_idx = []

func load_people():
	if _people.size() > 0:
		return
	for fname in _people_file_names:
		var path = "res://art/people/%s.jpg" % fname
		var tex = load(path)
		_people.append(tex)
		_people_names.append(fname.replace("_", " ").capitalize())
	_people_idx = range(_people.size())
	_people_idx.shuffle()

func get_num_people() -> int:
	return _people.size()

func get_person_image(idx: int):
	if _people.size() == 0:
		return null
	return _people[_people_idx[idx % _people_idx.size()]]

func get_person_name(idx: int) -> String:
	if _people.size() == 0:
		return ""
	return _people_names[_people_idx[idx % _people_idx.size()]]

func shuffle_people():
	_people_idx.shuffle()

func save_settings():
	game.save_settings([starting_level])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]
