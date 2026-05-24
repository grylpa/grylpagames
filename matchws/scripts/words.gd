extends RefCounted
class_name Words

signal words_ready(actually_got:bool)
signal collections_ready
signal stats_ready(actually_got:bool)

var languages = {}#{1:'Gr', 2:'Eng'}
var collections = []
var hard_words = []
var easy_words = []
var is_user_word = []
var word_indices = []
var next_word_index = 0

var collection = null
var groups = []
var all_words = []
var stats_dict = {}

var selected_new_lang_id = 1
var selected_known_lang_id = 2
var selected_collection_id = 0

var waiting_for_words := false
var failed_getting_words := false

func _init():
	# for i in 20:
	# 	hard_words.append("hard_" + str(i))
	# 	easy_words.append("easy_" + str(i))
	word_indices = range(easy_words.size())

func has_got_words():
	return all_words.size() > 0 and hard_words.size() > 0

func get_another_lang(id):
	for lang in languages:
		if lang != id:
			return lang
	return -1

func load_all():
	var dict = MatchwsG.game.load_game_data()
	if dict.size() == 0:
		return false
	languages = dict.get("languages", {})
	collections = dict.get("collections", [])
	groups = dict.get("groups", [])
	all_words = dict.get("words", [])
	return all_words.size() > 0
	
func request_global_data():
	# var body = JSON.stringify({"p_user_id": BE.get_user_id()})
	var body = {"p_user_id": BE.get_user_id()}
	BE.send_rpc_data("get_matchws_global_data", body, "", Callable(self, "_on_got_global_data"))
	# BE.get_table("rpc/get_matchws_global_data", Callable(self, "_on_got_global_data"),body, "")
	# BE.get_table("matchws_langs", Callable(self, "_on_got_langs"), "")
	# BE.get_table("matchws_groups", Callable(self, "_on_got_groups"), "")
	# BE.get_table("matchws_collections", Callable(self, "_on_got_collections"), "")
	# get_words_per_langs()
	# create_words_from_collection()

func _on_got_global_data(data):
	Log.dbg("got global data")
	if data is Dictionary:
		var _langs = data.get("matchws_langs", [])
		var _collections = data.get("matchws_collections", [])
		var _groups = data.get("matchws_groups", [])

		_on_got_langs(_langs)
		_on_got_collections(_collections)
		_on_got_groups(_groups)	

func _on_got_langs(langs):
	if langs is Array and langs.size() > 0:
		for row in langs:
			var lang_index = int(row.get("lang_index", -1))
			var lang_name = row.get("lang", "unknown")
			Log.dbg("lang_index: ", lang_index, " lang_name: ", lang_name)
			if lang_index >= 0:
				languages[lang_index] = lang_name

func _on_got_collections(dbcollections):
	if dbcollections is Array and dbcollections.size() > 0:
		Log.dbg("got %d collections" % dbcollections.size())
		collections = dbcollections
		collections_ready.emit()
		get_words_per_langs()

func _on_got_groups(dbgroups):
	if dbgroups is Array and dbgroups.size() > 0:
		Log.dbg("got %d groups" % dbgroups.size())
		groups = dbgroups

func redownload_all():
	all_words = []
	request_global_data()

func get_words_per_langs(rowrange:Vector2i = Vector2i(0,999)) -> bool:
	waiting_for_words = true
	failed_getting_words = false
	var cond = "lang_index=in.(" + str(selected_new_lang_id) + "," + str(selected_known_lang_id) + ")"
	cond += "&order=word_index.asc,lang_index.asc"
	cond += "&" + BE.cond_me_or_null()
	# Log.dbg("cond: ", cond)
	if rowrange[0] == 0:
		all_words = []
	BE.get_table("matchws_words", Callable(self, "_on_got_words"), "", cond, rowrange)
	return true

# func get_collection(collection_id: int = -1) -> bool:
# 	if collection_id < 0:
# 		collection_id = selected_collection_id
# 	for one_collection in collections:
# 		if collection_id == one_collection.get("collection_id", -1):
# 			collection = one_collection
# 			var _collection_name = collection.get("collection_name", "unknown")
# 			var group_ids: Array = collection.get("group_ids", []).map(func(x): return int(x))
# 			var cond = "group_id?=in." + str(group_ids)
# 			Log.dbg("cond: ", cond)
# 			BE.get_table("matchws_words", Callable(self, "_on_got_words"), cond)
# 			return true
# 	return false

func _on_got_words(_words_dict):
	waiting_for_words = false
	var _words
	var _total_rows := -1
	var _last_row_index := -1

	if _words_dict is Dictionary and _words_dict.has("data"):
		_words = _words_dict["data"]
		_total_rows = _words_dict.get("total_rows",-1)
		_last_row_index = _words_dict.get("last_row_retrieved",-1)
	else:
		_words = _words_dict
	if _words is Array and _words.size() > 0:
		Log.dbg("got %d words" % _words.size())
		all_words.append_array(_words)
		# all_words = _words
		failed_getting_words = false
		# all_words.sort_custom(func(a, b): return a["word_index"] < b["word_index"])		
		if _total_rows > 0 and _last_row_index >= 0 && _last_row_index + 1 < _total_rows:
			get_words_per_langs(Vector2i(_last_row_index + 1, min(_total_rows, _last_row_index + 1000)))
		else:
			words_ready.emit(true)
	else:
		failed_getting_words = true
		words_ready.emit(false)

func save_all():
	var dict := {
		"languages": languages,
		"collections": collections,
		"groups": groups,
		"words": all_words,
	}
	MatchwsG.game.save_game_data(dict)

func get_real_word_index_and_advance():
	var i = word_indices[next_word_index]
	next_word_index = (next_word_index + 1) % easy_words.size()
	if next_word_index == 0:
		var first_idx = word_indices[0]
		while first_idx == word_indices[0]:
			word_indices.shuffle()
	return i

func group_from_id(group_id):
	for group in groups:
		if group.get("group_id", -1) == group_id:
			return group
	return null

func create_words_from_collection():
	var useall := false
	var allowed_word_indices = []
	if selected_collection_id == -1000:
		useall = true
	else:
		var this_collection = null
		for one_collection in collections:
			if selected_collection_id == one_collection.get("collection_id", -1):
				this_collection = one_collection
		if this_collection == null:
			this_collection = collections[0]
		collection = this_collection
		var group_ids: Array = collection.get("group_ids", []).map(func(x): return int(x))		
		for group_id in group_ids:
			var group = group_from_id(group_id)
			if group != null:
				var _indices = group.get("word_indices", [])
				if _indices == null:
					_indices = []
				_indices = _indices.map(func(x): return int(x))
				var _ranges = group.get("word_ranges", [])
				if _ranges != null and _ranges.size() > 0:
					_ranges = _ranges.map(func(x): return int(x))
					for i in range(0, _ranges.size(), 2):
						_indices.append_array(range(_ranges[i],_ranges[i+1]+1))
				allowed_word_indices.append_array(_indices)

		# make allowed_word_indices values unique
		var dict:Dictionary = allowed_word_indices.reduce(
			func(acc, x) -> Dictionary:
				acc[x] = true
				return acc,
			{} as Dictionary
		)
		allowed_word_indices = dict.keys()
		allowed_word_indices.sort()

	# Log.dbg(_collection_name, group_ids)
	hard_words = []
	easy_words = []
	is_user_word = []	
	var available_pairs = {}	
	for i in all_words.size():
		var w = all_words[i]
		var iword = int(w.get("word_index", -1))
		if useall or iword in allowed_word_indices:
			var ilang = int(w.get("lang_index", -1))
			var user_id = w.get("user_id", "")
			var is_from_user = typeof(user_id) != TYPE_NIL and typeof(user_id) == TYPE_STRING and user_id.length() > 0
			var word_dict = available_pairs.get(iword, {})
			word_dict["is_from_user"] = is_from_user
			if ilang == selected_new_lang_id:
				word_dict["hard"] = w.get("word", "")
				# is_user_word.append(is_from_user)
				# hard_words.append(w.get("word", ""))
			elif ilang == selected_known_lang_id:
				word_dict["easy"] = w.get("word", "")
				# easy_words.append(w.get("word", ""))
			available_pairs[iword] = word_dict

	# make sure all used words actually have both language values and there are no duplicates
	var used_pairs = {}
	for word_pair in available_pairs:
		var h:String = available_pairs[word_pair].get("hard", "").strip_edges()
		var e:String = available_pairs[word_pair].get("easy", "").strip_edges()
		if !h.is_empty() and !e.is_empty():
			var str_words = h + "," + e
			if !used_pairs.has(str_words):
				used_pairs[str_words] = null
				is_user_word.append(available_pairs[word_pair].get("is_from_user", false))
				hard_words.append(h)
				easy_words.append(e)

	var N = min(hard_words.size(), easy_words.size())
	word_indices = range(N)
	word_indices.shuffle()
	next_word_index = 0

func get_personal_stats(new_lang_id, known_lang_id, collection_id):
	var cond = "event_name=eq.level_done"
	cond += "&event_data->>new_lang=eq." + str(new_lang_id)
	cond += "&event_data->>known_lang=eq." + str(known_lang_id)
	cond += "&event_data->>collection=eq." + str(collection_id)
	cond += "&order=created_at.asc"
	BE.get_table("user_events", Callable(self, "_on_got_personal_stats"), "", cond)

func _on_got_personal_stats(_stats):
	if _stats is Array and _stats.size() > 0:
		Log.dbg("got %d stats" % _stats.size())
		# data is an array in which first element is for not moving, second is for moving
		# each of those 2 array is itself a size-2 array of fast mode (false,true)
		# the low level dictionaries are for difficulty levels
		var sdict:Dictionary = {"data":[[{}, {}],[{}, {}]]}
		for row in _stats:
			var iso_time_str = row.get("created_at","")
			var dt_dict = Time.get_datetime_dict_from_datetime_string(iso_time_str, false)
			var epoch = Time.get_unix_time_from_datetime_dict(dt_dict)
			var stat = row.get("event_data",{})
			sdict["new_lang"] = int(stat.get("new_lang", 0))
			sdict["known_lang"] = int(stat.get("known_lang", 0))
			sdict["collection_id"] = int(stat.get("collection", 0))
			var moving:int = max(0,min(1,int(stat.get("moving",0))))
			var difficulty: int = int(stat.get("difficulty", 0))
			var speed_mode: int = int(stat.get("speed_mode", 0))
			var mda = sdict["data"][moving][speed_mode].get(difficulty,[])
			if mda.size() == 0:
				sdict["data"][moving][speed_mode][difficulty] = mda
			var short_stat = stat.duplicate()
			short_stat.erase("new_lang")
			short_stat.erase("known_lang")
			short_stat.erase("collection")
			short_stat["epoch"] = epoch
			mda.append(short_stat)
		stats_dict = sdict
		stats_ready.emit(true)
	else:
		stats_ready.emit(false)
	# "didwin": int(didwin),
	# "durationms": roundi(duration*1000),
	# "num_new_cards": num_new_cards,
	# "nmistakes": nmistakes,
	# "timeout_sec": timeout_sec,

func selected_new_lang_name():
	return languages[selected_new_lang_id]

func selected_known_lang_name():
	return languages[selected_known_lang_id]

func selected_collection_name():
	for one_collection in collections:
		if selected_collection_id == one_collection.get("collection_id", -1):
			return one_collection.get("collection_name", "unknown")
	return ""
