extends Node

var bkcolor := Color.hex(0xFF8A5CFF)
var starting_difficulty := 1
var level_done := false
var words: Words = Words.new()
var moving := true
var bottom := 0
var statistics_plot_type := 0
var statistics_resolution := "H"
var speed_mode := true

var game := GenericGameUtil.new("Matchws", "matchws", 0,5,0)

func reset():
	if speed_mode:
		moving = false
	game.reset(false)
	level_done = false

func init_globals():
	reset()
	
func save_settings():
	game.save_settings([
		starting_difficulty, 
		moving, 
		words.selected_new_lang_id,
		words.selected_known_lang_id, 
		words.selected_collection_id, 
		statistics_plot_type, 
		statistics_resolution, 
		speed_mode])

func load_settings():
	var settings = game.read_settings()
	if settings.size() > 7:
		starting_difficulty = settings[0]
		moving = settings[1]
		words.selected_new_lang_id = settings[2]
		words.selected_known_lang_id = settings[3]
		words.selected_collection_id = settings[4]
		statistics_plot_type = settings[5]
		statistics_resolution = settings[6]
		speed_mode = settings[7]
