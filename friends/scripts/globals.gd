extends Node

var starting_level := 1
var p_scale := Vector2(200,300)
var board_top := 0

var game := GenericGameUtil.new("Friends", "friends", 0,5,0)

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

var _people = []
var _people_names = []
var _people_idx = []
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

func load_people():
	if _people.size() > 0:
		return
	for fname in _people_file_names:
		var path = "res://art/people/%s.jpg" % fname
		var tex = load(path)
		_people.append(tex)
		_people_names.append(fname.replace("_"," ").capitalize())
	_people_idx = range(_people.size())
	_people_idx.shuffle()
	

func get_num_people():
	return _people.size()

func get_rand_person_id():
	var r = game.rng.randi_range(0,_people.size()-1)
	return r

func shuffle_people():
	_people_idx.shuffle()

func get_person_image(idx: int):	
	if _people.size() == 0:
		return null
	return _people[_people_idx[idx % _people_idx.size()]]
	# if idx >= 0 and idx < people_idx.size():
	# 	return people[people_idx[idx]]
	# return null

func first_name(full_name: String) -> String:
	var parts = full_name.split(" ")
	if parts.size() > 0:
		return parts[0]
	return full_name

func last_name(full_name: String) -> String:
	var parts = full_name.split(" ")
	if parts.size() > 1:
		return parts[parts.size() - 1]
	return full_name

func get_person_name(idx: int):	
	if _people.size() == 0:
		return null
	return _people_names[_people_idx[idx % _people_idx.size()]]

func save_settings():
	game.save_settings([starting_level])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 0:
		starting_level = settings[0]

func _ref():
	var ref = game.get_viewport_center()
	# ref.y = game.header_height + px_scale / 2 + board_top
	# ref.y = p_scale.y / 2 + board_top
	ref.y = board_top
	return ref

func px_to_board(p):
	var q = p - _ref()
	q.x /= p_scale.x
	q.y /= p_scale.y
	return Vector2i(q)

func board_to_px(p):
	var q = p
	q.x *= p_scale.x
	q.y *= p_scale.y
	return Vector2(q) + _ref()
