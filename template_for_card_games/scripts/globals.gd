extends Node

var starting_difficulty := 1
var px_scale := 200


var game := GenericGameUtil.new("Friends", "friends", 0,2,0,0)

var back_textures = [
	"res://art/cards/CardBack1.png",
	"res://art/cards/CardBack2.png",
	"res://art/cards/CardBack3.png",
	"res://art/cards/CardBack4.png",
	"res://art/cards/CardBack5.png",
	"res://art/cards/CardBack6.png",
	"res://art/cards/CardBack7.png",
	"res://art/cards/CardBack8.png",
	"res://art/cards/CardBack9.png",
]

var people = []
var people_names = []
var people_idx = []
var people_file_names = [
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

func load_people():
	if people.size() > 0:
		return
	for fname in people_file_names:
		var path = "res://art/people/%s.jpg" % fname
		var tex = load(path)
		people.append(tex)
		people_names.append(fname.replace("_"," ").capitalize())
	people_idx = range(people.size())
	people_idx.shuffle()

func shuffle_people():
	people_idx.shuffle()

func get_person(idx: int):	
	if people.size() == 0:
		return null
	return people[people_idx[idx % people.size()]]
	# if idx >= 0 and idx < people_idx.size():
	# 	return people[people_idx[idx]]
	# return null

func save_settings():
	game.save_settings([starting_difficulty])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 0:
		starting_difficulty = settings[0]

func px_to_board(p):
	return Vector2i((p - game.get_viewport_center()) / px_scale)

func board_to_px(p):
	return Vector2(p) * px_scale + game.get_viewport_center()
