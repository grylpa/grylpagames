extends Node

enum LoginFailReasons {OK=0, Unknown=1, EmailNotVerified=2}
enum SignupFailReasons {OK=0, UserExists=1, EmailExists=2, Unknown=3, InvalidEmail=4, WeakPassword=5}

signal sig_logged_in(success: bool, fail_reason: LoginFailReasons)
signal sig_created_player(success: bool, fail_reason: SignupFailReasons)
signal sig_show_login_screen
signal sig_session_expired
signal sig_password_reset_sent(success: bool)

const settings_name := "user://nomizo_settings.tres"

# ---------- Session State ----------

var logged_in := false
var offline_mode: bool = false
var _scores_upload_failed: bool = false
var stored_username := ""
var stored_email := ""
var sent_username := ""

var SUPABASE_URL: String = ""
var SUPABASE_KEY: String = ""

var current_session = null
var current_user = null

# ---------- Request Queues ----------

const n_request_queues := 2
const AUTH_QUEUE := 0
const DATA_QUEUE := 1

var http_requests = []
var pending_requests = []
var is_request_active = []
var current_callable = []
var current_external_callable = []
var time_sent_request_ms = []
var last_sent_request = []

const SESSION_FILE = "user://supabase_session.save"
const REQUEST_WATCHDOG_INTERVAL_MS := 1000
const _PROACTIVE_REFRESH_CHECK_INTERVAL_MS: int = 60000
const _TOKEN_REFRESH_MARGIN_SEC: int = 300  # refresh when < 5 min remain

var _last_request_watchdog_ms := 0
var _last_proactive_refresh_check_ms: int = 0
var _refresh_in_progress: bool = false

func _ready():
	set_process(true)
	_last_request_watchdog_ms = MainGlobals.timems()

func _process(_delta: float) -> void:
	if not MainCfg.use_BE or offline_mode:
		return
	var now: int = MainGlobals.timems()
	if now - _last_request_watchdog_ms >= REQUEST_WATCHDOG_INTERVAL_MS:
		_last_request_watchdog_ms = now
		check_requests()
	if now - _last_proactive_refresh_check_ms >= _PROACTIVE_REFRESH_CHECK_INTERVAL_MS:
		_last_proactive_refresh_check_ms = now
		_maybe_proactive_refresh()

func _json_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	])

func _auth_json_headers(access_token: String, extra_headers: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var headers: PackedStringArray = _json_headers()
	headers.append("Authorization: Bearer " + access_token)
	headers.append_array(extra_headers)
	return headers

func _remember_identity(email: String, username: String = "") -> void:
	stored_email = email
	if not username.is_empty():
		stored_username = username

func _clear_session_state(clear_identity: bool = false) -> void:
	current_session = null
	current_user = null
	logged_in = false
	if clear_identity:
		stored_email = ""
		stored_username = ""

func _apply_session_tokens(response: Variant) -> bool:
	if response == null or not response is Dictionary:
		return false
	if response.has("access_token"):
		current_session = {
			"access_token": response["access_token"],
		}
		if response.has("refresh_token"):
			current_session["refresh_token"] = response["refresh_token"]
		return true
	return false

func _handle_auth_success(response: Variant, is_anonymous: bool, force_username_refresh: bool = false) -> bool:
	if not _apply_session_tokens(response):
		logged_in = false
		Log.info("Missing token data in auth response")
		return false
	MainCfg.is_anonymous_user = is_anonymous
	if is_anonymous:
		stored_email = ""
		stored_username = ""
	logged_in = true
	save_session()
	MainGlobals.save_settings()
	sig_logged_in.emit(true, LoginFailReasons.OK)
	if not is_anonymous:
		get_username(force_username_refresh)
	return true

func _handle_auth_refresh_failure(response: Variant) -> void:
	Log.info("Failed to refresh token: ", response)
	_clear_session_state()
	clear_saved_session()
	auto_login_user()

func _load_supabase_config() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load("res://config/supabase.cfg") != OK:
		return
	SUPABASE_URL = cfg.get_value("supabase", "url", "")
	SUPABASE_KEY = cfg.get_value("supabase", "anon_key", "")

func start():
	_load_supabase_config()
	for i in n_request_queues:
		is_request_active.append(false)
		current_callable.append(Callable())
		current_external_callable.append(Callable())
		time_sent_request_ms.append(0)
		last_sent_request.append(null)
		pending_requests.append([])
		var hreq = HTTPRequest.new()
		hreq.timeout = 10
		http_requests.append(hreq)
		add_child(hreq)
		hreq.request_completed.connect(_on_http_request_completed.bind(str(i)))	
	if not MainCfg.use_BE:
		return
	if MainCfg.is_anonymous_user:
		_clear_session_state(true)
		clear_saved_session()
		sign_in_anon()
	elif stored_email.is_empty():
		_clear_session_state(true)
		clear_saved_session()
		auto_login_user()
	elif !load_session():
		auto_login_user()

func _readd_request(r: OneRequest):
	pending_requests[r.queue_id].push_front(r)
	_send_next_request(r.queue_id)

func _add_request(callable: Callable, url: String, headers: PackedStringArray, method: int,
	body: String, external_callable = Callable(), retries = 4, insert_front = false, queue_id=0):
	if not MainCfg.use_BE or offline_mode:
		return
	queue_id = clampi(queue_id, 0, n_request_queues - 1)
	var r = OneRequest.new(url, method, body, headers, callable, external_callable, retries, queue_id)
	if insert_front:
		pending_requests[queue_id].push_front(r)
	else:
		pending_requests[queue_id].append(r)
	_send_next_request(queue_id)

func _defer_send_next_request(queue_id):
	is_request_active[queue_id] = false
	call_deferred("_send_next_request",queue_id)

func print_last_sent_request(queue_id):
	if last_sent_request[queue_id] != null:
		var url = last_sent_request[queue_id].url
		# var headers = last_sent_request.headers
		var method = last_sent_request[queue_id].method
		var body = last_sent_request[queue_id].body
		var bodystr = ",[%s]" % str(body) if !body.is_empty() else ""
		Log.dbg("Last sent request (%s):%s%s" % [_method_name(method), str(url).replace(SUPABASE_URL,""), bodystr])
		# Log.dbg("Last sent request:\nurl: %s\nheaders: %s\nmethod: %s\nbody: %s" % [str(url), str(headers), str(method), str(body)])

class OneRequest:
	var url: String
	var method: int
	var body: String
	var headers: PackedStringArray
	var external_callable: Callable = Callable()
	var completion_callable: Callable = Callable()
	var retries: int
	var queue_id: int

	func _init(_url, _method, _body, _headers, _completion_callable, _external_callable, _retries, _queue_id):
		url = _url
		method = _method
		body = _body
		headers = _headers
		completion_callable = _completion_callable
		external_callable = _external_callable
		retries = _retries
		queue_id = _queue_id

func _send_next_request(queue_id):
	if pending_requests[queue_id].is_empty() or is_request_active[queue_id]:
		return
	if not MainCfg.use_BE:
		return
	
	var request_row = pending_requests[queue_id].pop_front()
	current_callable[queue_id] = request_row.completion_callable
	var url = request_row.url
	var headers = request_row.headers
	var method = request_row.method
	var body = request_row.body
	current_external_callable[queue_id] = request_row.external_callable
	last_sent_request[queue_id] = request_row
	time_sent_request_ms[queue_id] = MainGlobals.timems()
	# var bodystr = ",[%s]" % str(body) if !body.is_empty() else ""
	# Log.dbg("Sending Q%d %s:%s%s" % [queue_id, _method_name(method), str(url).replace(SUPABASE_URL,""), bodystr])
	var err = http_requests[queue_id].request(url, headers, method, body)
	if err == OK:
		is_request_active[queue_id] = true
	else:
		Log.info("❌ Failed to send request:", err)
		_send_next_request(queue_id)

func _method_name(method: int) -> String:
	match method:
		HTTPClient.METHOD_POST: return "POST"
		HTTPClient.METHOD_GET: return "GET"
		HTTPClient.METHOD_PUT: return "PUT"
		HTTPClient.METHOD_DELETE: return "DELETE"
		_: return str(method)	

func register_user(email: String, password: String, username: String):
	var body = JSON.stringify({
		"email": email,
		"password": password,
		"data": {
			"username": username
		}
	})
	
	var headers: PackedStringArray = _json_headers()
	
	http_requests[0].set_meta("username", username)
	http_requests[0].set_meta("email", email)
	http_requests[0].set_meta("password", password)
	
	_add_request(Callable(self, "_on_signup_completed"),
		SUPABASE_URL + "/auth/v1/signup",
		headers,
		HTTPClient.METHOD_POST,
		body,
		Callable(),
		4,
		false,
		AUTH_QUEUE
	)

func _on_signup_completed(response_code, body, _queue_id, _total_rows, _last_row_index):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	# print("response_code: ",response_code, "\nheaders: ",_headers, "\nresult: ",_result, "\nresponse: ",response)
	if response_code != 200 and response_code != 201:
		Log.info("Signup failed: ", response)
		if response != null and response.has("error_code"):
			var err = response["error_code"]
			if err == "user_already_exists":
				sig_created_player.emit(false, SignupFailReasons.UserExists)
			elif err == "email_address_invalid":
				sig_created_player.emit(false, SignupFailReasons.InvalidEmail)
			elif err == "weak_password":
				sig_created_player.emit(false, SignupFailReasons.WeakPassword)
			else:
				sig_created_player.emit(false, SignupFailReasons.Unknown)
		else:
			sig_created_player.emit(false, SignupFailReasons.Unknown)
		return
	
	Log.info("User registered successfully!")
	sig_created_player.emit(true, SignupFailReasons.OK)
	# Log.dbg("emit BE.sig_created_player")

	_remember_identity(http_requests[0].get_meta("email"), http_requests[0].get_meta("username"))
	MainGlobals.save_settings()
	
	if response.has("session"):
		current_session = response["session"]
		current_user = response["user"]
		save_session()
		Log.info("Session saved after signup")
		logged_in = true
		update_username(stored_username)
		sig_logged_in.emit(true, LoginFailReasons.OK)
	else:
		Log.info("no session data in signup response, logging in")
		login_user(
			http_requests[0].get_meta("email"), 
			http_requests[0].get_meta("password"),
			http_requests[0].get_meta("username")
		)

var times_tried_auto_login := 0

func auto_login_user():
	if not MainCfg.use_BE:
		return
	times_tried_auto_login += 1
	if times_tried_auto_login > 3:
		Log.info("Auto login failed after %d tries, giving up" % (times_tried_auto_login-1))
		sig_session_expired.emit()
		return
	if MainCfg.is_anonymous_user:
		sign_in_anon()
	elif MainGlobals.user_file_key.begins_with("guest_"):
		logged_in = false
	else:
		sig_show_login_screen.emit()

func login_user(email: String, password: String, username: String):
	if not MainCfg.use_BE:
		return
	var body = JSON.stringify({
		"email": email,
		"password": password
		# "password": "asdfasdfasdf"
	})
	
	var headers: PackedStringArray = _json_headers()
	
	_remember_identity(email, username)
	http_requests[0].set_meta("username", username)
	_add_request(Callable(self, "_on_login_completed"),
		SUPABASE_URL + "/auth/v1/token?grant_type=password",
		headers,
		HTTPClient.METHOD_POST,
		body,
		Callable(),
		4,
		true,
		AUTH_QUEUE
	)

func _on_login_completed(response_code, body, _queue_id, _total_rows, _last_row_index):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code != 200 and response_code != 201:
		Log.info("Login failed: ", response)
		if response.has("error_code"):
			var err = response["error_code"]
			if err == "email_not_confirmed":
				sig_logged_in.emit(false, LoginFailReasons.EmailNotVerified)
			else:
				sig_logged_in.emit(false, LoginFailReasons.Unknown)
		return		
	
	if _handle_auth_success(response, false, true):
		Log.info("got access and refresh tokens after logging in")
		Log.info("User logged in successfully!")
	else:
		logged_in = false

func get_user():
	if current_session == null or not current_session.has("access_token"):
		Log.info("No session available")
		return ERR_UNAUTHORIZED
	
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + current_session["access_token"]
	]
	
	_add_request(Callable(self, "_on_get_user_completed"),
		SUPABASE_URL + "/auth/v1/user",
		headers,
		HTTPClient.METHOD_GET,
		""
	)

func _on_get_user_completed(response_code, body, _queue_id, _total_rows, _last_row_index):
	if response_code != 200:
		Log.info("Failed to get user data: ", response_code)
		return
	
	current_user = JSON.parse_string(body.get_string_from_utf8())
	Log.info("User data retrieved successfully")
	get_username()
	# update_username(stored_username)
	# Log.info("User data retrieved successfully: " + str(current_user))

func _on_refresh_token_completed(response_code, body, _queue_id, _total_rows, _last_row_index):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code < 200 or response_code > 299:
		_handle_auth_refresh_failure(response)
		return
	
	# Log.info("Token refreshed successfully")
	
	if _handle_auth_success(response, MainCfg.is_anonymous_user):
		# Log.info("User considered logged in after token refresh")
		# Don't touch is_anonymous_user here — it was correctly loaded from settings
		pass
	else:
		logged_in = false

func save_session():
	if not MainCfg.use_BE:
		return
	if current_session == null:
		return
		
	var file = FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_session))
		file.close()
	else:
		Log.info("Failed to save session")

func load_session() -> bool:
	if not MainCfg.use_BE:
		return false
	if not FileAccess.file_exists(SESSION_FILE):
		Log.info("No saved session found")
		return false
		
	var file = FileAccess.open(SESSION_FILE, FileAccess.READ)
	if file:
		var data = file.get_as_text()
		file.close()
		
		current_session = JSON.parse_string(data)
		# Log.info("Session loaded from disk")
		if typeof(current_session) != TYPE_DICTIONARY:
			return false

		var _refresh_token = current_session.get("refresh_token", null)
		# _refresh_token = 'AsdFASdfASDF'
		if _refresh_token == null or _refresh_token == "":
			return false
		
		var body = JSON.stringify({
			"refresh_token": _refresh_token
		})
		
		var headers: PackedStringArray = _json_headers()
		
		current_session = null
		_add_request(Callable(self, "_on_refresh_token_completed"),
			SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token",
			headers,
			HTTPClient.METHOD_POST,
			body
		)
		return true
	else:
		Log.info("Failed to load be session")
		return false

func clear_saved_session():
	if FileAccess.file_exists(SESSION_FILE):
		var dir := DirAccess.open("user://")
		if dir != null:
			var err := dir.remove(SESSION_FILE.replace("user://", ""))
			if err == OK:
				Log.info("Saved session cleared")
			else:
				Log.info("Failed to clear saved session: ", err)

func logout():
	if not MainCfg.use_BE:
		return
	_clear_session_state(true)
	clear_saved_session()
	MainGlobals.save_settings()
	Log.info("User logged out")

func get_current_user():
	return current_user

func get_user_id() -> String:
	var access_token = get_access_token()
	var user_id = get_user_id_from_token(access_token)
	return user_id
	# if current_user != null:
	# 	return current_user["id"]
	# return ""

func get_access_token() -> String:
	if current_session != null and current_session.has("access_token"):
		return current_session["access_token"]
	return ""

# ---------- Generic Authenticated RPC / REST ----------

func send_rpc_data(rpc_name: String, payload: Dictionary, payload_var_name: String, callback:Callable):
	if not MainCfg.use_BE:
		return
	var access_token = get_access_token()
	# var user_id = get_user_id()
	var user_id = get_user_id_from_token(access_token)

	var rpc_body_payload = {}
	if payload.size() > 0 and payload_var_name.length() > 0:
		payload["user_id"] = user_id
		rpc_body_payload = {
			payload_var_name: payload
		}
	else:
		rpc_body_payload = payload

	var url = SUPABASE_URL + "/rest/v1/rpc/" + rpc_name
	var headers: PackedStringArray = _auth_json_headers(access_token)
	var jsonbody = JSON.stringify(rpc_body_payload)
	_add_request(Callable(self, "_on_send_rpc_data"),
		url, headers, HTTPClient.METHOD_POST, jsonbody, callback, 4, false, DATA_QUEUE)

func _on_send_rpc_data(_response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index):
	var text = body.get_string_from_utf8()
	if text.strip_edges() == "":
		# Log.info("✅ Event inserted successfully (empty body)")
		return

	# Log.info("Raw RPC response body:", text)
	var json = JSON.new()
	var parse_err = json.parse(text)
	if parse_err != OK:
		Log.info("❌ Failed to parse JSON:", text)
		return

	if _response_code == 201 or _response_code == 200:
		# Log.info("✅ Event inserted successfully")
		# var intval = int(json.get_data())
		if current_external_callable[_queue_id].is_valid():
			current_external_callable[_queue_id].call(json.get_data())
	else:
		Log.info("❌ Error inserting event. Code:", _response_code)

func send_event(event_name: String, game_name: String, event_data: Dictionary):
	if MainCfg.is_anonymous_user:
		return
	if not MainCfg.use_BE or not MainCfg.use_BE_logging:
		return
	var access_token = get_access_token()
	# var user_id = get_user_id()
	var user_id = get_user_id_from_token(access_token)
	var url = SUPABASE_URL + "/rest/v1/user_events"
	var headers: PackedStringArray = _auth_json_headers(access_token)
	
	var event_payload = {
		"user_id": user_id,
		"game_name": game_name,
		"event_name": event_name,
		"event_data": event_data
	}

	_add_request(Callable(self, "_on_event_sent"),
		url, headers, HTTPClient.METHOD_POST, JSON.stringify(event_payload), 
		Callable(), 4, false, DATA_QUEUE)

func _on_event_sent(_response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index):
	var text = body.get_string_from_utf8()
	if text.strip_edges() == "":
		# Log.info("✅ Event inserted successfully (empty body)")
		return

	Log.info("🧾 Raw response body:", text)
	var json = JSON.new()
	var parse_err = json.parse(text)
	if parse_err != OK:
		Log.info("❌ Failed to parse JSON:", text)
		return

	if _response_code == 201:
		# Log.info("✅ Event inserted successfully")
		pass
	else:
		Log.info("❌ Error inserting event. Code:", _response_code)

func update_username(username: String):
	if MainCfg.is_anonymous_user:
		return
	if not MainCfg.use_BE:
		return

	sent_username = username
	var access_token = get_access_token()
	# var user_id = get_user_id()
	var user_id = get_user_id_from_token(access_token)
	var url = SUPABASE_URL + "/rest/v1/profiles"

	var headers: PackedStringArray = _auth_json_headers(access_token,
		PackedStringArray(["Prefer: resolution=merge-duplicates"]))

	var payload = {
		"id": user_id,
		"username": username
	}

	_add_request(Callable(self, "_on_update_profile_completed"),
		url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func _on_update_profile_completed(response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index):
	var text = body.get_string_from_utf8()
	if text.strip_edges() == "" and response_code == 201:
		Log.info("✅ Username inserted")
		if stored_username != sent_username:
			stored_username = sent_username
			MainGlobals.save_settings()
		return
	elif response_code == 409:		
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var v = rng.randi_range(10000, 99999)
		var try_username = stored_username + "_" + str(v)
		update_username(try_username)
		Log.info("⚠️ Conflict: username might already exist. trying %s" % try_username)
		return

	var json = JSON.parse_string(text)
	if json == null:
		Log.info("❌ Failed to parse username update response:", text)
		return

	Log.info("ℹ️ Response:", json)

func _decode_jwt_payload(access_token: String) -> Dictionary:
	var parts = access_token.split(".")
	if parts.size() != 3:
		return {}
	var b64: String = parts[1]
	while b64.length() % 4 != 0:
		b64 += "="
	var decoded_bytes: PackedByteArray = Marshalls.base64_to_raw(b64)
	if decoded_bytes.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(decoded_bytes.get_string_from_utf8()) != OK:
		return {}
	var data = json.get_data()
	if data is Dictionary:
		return data
	return {}

func get_user_id_from_token(access_token: String) -> String:
	var payload: Dictionary = _decode_jwt_payload(access_token)
	if payload.has("sub"):
		return str(payload["sub"])
	return ""

func _maybe_proactive_refresh() -> void:
	if not logged_in or MainCfg.is_anonymous_user or _refresh_in_progress:
		return
	if current_session == null or not current_session.has("refresh_token"):
		return
	var access_token: String = get_access_token()
	if access_token.is_empty():
		return
	var payload: Dictionary = _decode_jwt_payload(access_token)
	if not payload.has("exp"):
		return
	var secs_remaining: int = int(payload["exp"]) - int(Time.get_unix_time_from_system())
	if secs_remaining <= _TOKEN_REFRESH_MARGIN_SEC:
		Log.info("Token expiring in %ds — proactively refreshing" % secs_remaining)
		_refresh_in_progress = true
		var body: String = JSON.stringify({"refresh_token": current_session["refresh_token"]})
		_add_request(Callable(self, "_on_proactive_refresh_completed"),
			SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token",
			_json_headers(), HTTPClient.METHOD_POST, body,
			Callable(), 4, true, AUTH_QUEUE)

func _on_proactive_refresh_completed(response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index) -> void:
	_refresh_in_progress = false
	var response = JSON.parse_string(body.get_string_from_utf8())
	if response_code < 200 or response_code > 299:
		Log.info("Proactive token refresh failed: %d" % response_code)
		return
	if _apply_session_tokens(response):
		save_session()
		Log.info("Proactive token refresh succeeded")

func upsert_user_activity():
	if not MainCfg.use_BE or MainCfg.is_anonymous_user:
		return
	var url = SUPABASE_URL + "/rest/v1/user_activity?on_conflict=user_id"
	var access_token = get_access_token()

	var headers: PackedStringArray = _auth_json_headers(access_token,
		PackedStringArray(["Prefer: resolution=merge-duplicates"]))

	var payload = {
		"user_id": get_user_id_from_token(access_token),
	}

	_add_request(Callable(self, "_on_upsert_user_activity"),
		url, headers, HTTPClient.METHOD_POST, JSON.stringify([payload]),
		Callable(), 4, false, DATA_QUEUE)

func _on_upsert_user_activity(response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index):
	var text = body.get_string_from_utf8()
	if text.strip_edges() == "":
		if response_code == 201 or response_code == 200:
			# Log.info("✅ user activity upserted successfully")
			pass
		else:
			Log.info("❌ Error upserting user activity. Response code:", response_code)
		return

	Log.info("🧾 Raw response body:", text)
	var json = JSON.parse_string(text)
	if json == null:
		Log.info("❌ Failed to parse JSON:", text)
		return

	if response_code == 201:
		# Log.info("✅ Game state upserted successfully")
		pass
	else:
		Log.info("❌ Error upserting user activity. Code:", response_code)
		Log.info("❌ Response:", json)

func upsert_game_state(game_name: String, state_data: Dictionary):
	if MainCfg.is_anonymous_user:
		return
	if not MainCfg.use_BE or not MainCfg.use_BE_logging:
		return

	var url = SUPABASE_URL + "/rest/v1/user_game_states"
	var access_token = get_access_token()

	var headers: PackedStringArray = _auth_json_headers(access_token,
		PackedStringArray(["Prefer: resolution=merge-duplicates"]))

	var payload = {
		"user_id": get_user_id_from_token(access_token),
		"game_name": game_name,
		"state": state_data
	}

	_add_request(Callable(self, "_on_upsert_game_state_completed"),
		url, headers, HTTPClient.METHOD_POST, JSON.stringify([payload]),
		Callable(), 4, false, DATA_QUEUE)

func _on_upsert_game_state_completed(response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index):
	var text = body.get_string_from_utf8()
	if text.strip_edges() == "":
		if response_code == 201 or response_code == 200:
			# Log.info("✅ Game state upserted successfully")
			pass
		else:
			Log.info("❌ Error upserting game state. Response code:", response_code)
		return

	Log.info("🧾 Raw response body:", text)
	var json = JSON.parse_string(text)
	if json == null:
		Log.info("❌ Failed to parse JSON:", text)
		return

	if response_code == 201:
		# Log.info("✅ Game state upserted successfully")
		pass
	else:
		Log.info("❌ Error upserting game state. Code:", response_code)
		Log.info("❌ Response:", json)


func get_username(force := false):
	if MainCfg.is_anonymous_user or (!force and !stored_username.is_empty()):
		return
	var access_token = get_access_token()
	var user_id = get_user_id_from_token(access_token)
	var url = SUPABASE_URL + "/rest/v1/profiles?id=eq." + user_id

	var headers: PackedStringArray = _auth_json_headers(access_token)

	_add_request(Callable(self, "_on_username_received"),url, headers, HTTPClient.METHOD_GET, "", Callable(), 4, false, AUTH_QUEUE)

func _on_username_received(response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index):
	if response_code != 200:
		Log.info("❌ Error getting username. Response code:", response_code)
		return

	var text = body.get_string_from_utf8()
	var json = JSON.parse_string(text)
	if json == null:
		Log.info("❌ Failed to parse response:", text)
		return

	if json.size() > 0:
		var username = json[0]["username"]
		Log.info("Current username:", username)
		if stored_username != username:
			stored_username = username
			MainGlobals.save_settings()
	elif !stored_username.is_empty():
		Log.info("⚠️ Username not set for this user.")
		update_username(stored_username)

func lookup_email_by_username(username: String, callback: Callable) -> void:
	var url = SUPABASE_URL + "/rest/v1/rpc/get_email_by_username"
	var headers: PackedStringArray = _json_headers()
	var body = JSON.stringify({"p_username": username})
	_add_request(Callable(self, "_on_email_lookup_completed"),
		url, headers, HTTPClient.METHOD_POST, body, callback, 4, false, AUTH_QUEUE)

func _on_email_lookup_completed(response_code: int, body: PackedByteArray, queue_id, _total_rows, _last_row_index) -> void:
	var callback: Callable = current_external_callable[queue_id]
	if response_code != 200:
		Log.info("❌ Email lookup failed. Code:", response_code)
		if callback.is_valid():
			callback.call("")
		return
	var text = body.get_string_from_utf8().strip_edges()
	# RPC returning TEXT comes back as a JSON-encoded string (with quotes) or null
	var result = JSON.parse_string(text)
	if result == null or not result is String:
		Log.info("❌ Email lookup: no result for username, response:", text)
		if callback.is_valid():
			callback.call("")
		return
	if callback.is_valid():
		callback.call(result)

func cond_me_or_null():
	var access_token = get_access_token()
	var user_id = get_user_id_from_token(access_token)
	var raw_cond = "(user_id.is.null,user_id.eq." + user_id + ",open_to.eq.0)"
	var cond = "or=" + raw_cond#.uri_encode()
	Log.dbg("cond: %s" % cond)
	return cond

func get_table(table_name: String, callback, body: String, cond: String, rowrange: Vector2i = Vector2i(0,999)):
	if not MainCfg.use_BE:
		return
	var access_token = get_access_token()
	var url = SUPABASE_URL + "/rest/v1/" + table_name + "?select=*"
	if !cond.is_empty():
		url += "&" + cond

	var headers: PackedStringArray = _auth_json_headers(access_token,
		PackedStringArray([
			"Prefer: count=exact",
			"Range: %d-%d" % [rowrange[0],rowrange[1]]
		]))
	_add_request(Callable(self, "_on_generic_request_completed"), url, headers, HTTPClient.METHOD_GET, body, callback)

func _on_generic_request_completed(_response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index):
	var text = body.get_string_from_utf8()
	var json = JSON.parse_string(text)
	if json == null:
		Log.info("❌ Failed to parse response:", text)
		return

	print("_on_generic_request_completed: _last_row_index %d _total_rows %d " % [_last_row_index, _total_rows])
	if json is Array:
		json = {"data": json}
	if json is Dictionary:
		json["total_rows"] = _total_rows
		json["last_row_retrieved"] = _last_row_index
	# Log.dbg("✅ Table Data: ", json)
	if current_external_callable[_queue_id].is_valid():
		current_external_callable[_queue_id].call(json)

# ---------- Request Completion / Retry ----------

var retriable_codes = [0,408,429,500,502,503,504, 425]
var unretriable_codes = [400, 403, 404, 405, 422]
var retriable_after_auth_codes = [401]

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_name) -> void:
	var queue_id = int(request_name)
	_defer_send_next_request(queue_id)
	if response_code < 200 or response_code > 299:
		var istimeout = _result == ERR_TIMEOUT or response_code == 0
		Log.info("❌ Error getting request. Response code %d result %d istimeout %d" % [response_code, _result, int(istimeout)])
		print_last_sent_request(queue_id)
		var r = last_sent_request[queue_id]
		last_sent_request[queue_id] = null
		var was_token_refresh = false
		var was_login = false
		if r != null:
			was_token_refresh = r.url.find("token?grant_type=refresh_token") >= 0
			was_login = r.url.find("token?grant_type=password") >= 0
		
		Log.dbg("was_token_refresh %d was_login %d" % [int(was_token_refresh),int(was_login)])
		if retriable_codes.has(response_code):
			if r != null and r.retries > 0:
				r.retries -= 1
				Log.info("Retrying request retry %d" % r.retries)
				pending_requests[queue_id].push_front(r)
				return  # don't call callable while retrying
			elif current_session == null:
				auto_login_user()
			# retries exhausted — fall through to call the callable so error handlers run
		# Non-retriable error: let the callable handle it (it already checks response_code)
		if current_callable[queue_id].is_valid():
			current_callable[queue_id].call(response_code, body, queue_id, 0, -1)
		elif current_session == null and !MainCfg.is_anonymous_user:
			if unretriable_codes.has(response_code):
				sig_show_login_screen.emit()
			else:
				auto_login_user()
		return

	last_sent_request[queue_id] = null

	var total_rows = 0
	var last_row_index = -1
	for header in _headers:
		if "Content-Range" in header and not header.contains("*/"):
			var range_string = header.split(":")
			var count_string = range_string[1].strip_edges().split("/")
			total_rows = int(count_string[1])
			if total_rows > 0:
				var range_parts = count_string[0].split("-")
				if range_parts.size() > 1:
					last_row_index = int(range_parts[1])
					print("Received up to row %d from total_rows %d" % [last_row_index, total_rows])
			break
				
	# var json = null
	# var text = body.get_string_from_utf8()
	# if !text.is_empty():
	# 	json = JSON.parse_string(text)
	# if json == null:
	# 	Log.info("❌ Failed to parse response:", text)
	# 	return

	if current_callable[queue_id].is_valid():
		current_callable[queue_id].call(response_code,body, queue_id, total_rows, last_row_index)
		# current_callable[queue_id] = Callable()
	if _scores_upload_failed and logged_in and not MainCfg.is_anonymous_user:
		_scores_upload_failed = false
		MainGlobals.on_logged_in_sync()

func check_requests():
	for queue_id in n_request_queues:
		if is_request_active[queue_id]:
			var now = MainGlobals.timems()
			if now - time_sent_request_ms[queue_id] > 12000:
				Log.dbg("Reqeusts seem to be stuck for queue %d" % queue_id)
				http_requests[queue_id].queue_free()
				http_requests[queue_id] = HTTPRequest.new()	
				add_child(http_requests[queue_id])
				http_requests[queue_id].request_completed.connect(_on_http_request_completed.bind(str(queue_id)))	
				is_request_active[queue_id] = false
				if last_sent_request[queue_id] != null:
					Log.dbg("Requeuing last sent request for queue %d" % queue_id)
					pending_requests[queue_id].push_front(last_sent_request[queue_id])
					last_sent_request[queue_id] = null
				else:
					Log.dbg("Requeuing next request for queue %d" % queue_id)
				_send_next_request(queue_id)

# A session is a v6 named Dictionary. The four promoted columns keep their own SQL columns; every
# other key rides along in `extra_data`, which is already a JSON blob server-side and so needs no
# schema change as games gain metrics.
func _score_to_payload(user_id: String, game_name: String, rec: Dictionary) -> Dictionary:
	var extra: Dictionary = rec.duplicate()
	for promoted: String in ["ts", "score", "time_left", "times_run"]:
		extra.erase(promoted)
	return {
		"user_id": user_id,
		"game_name": game_name,
		"session_ts": int(rec.get("ts", 0)),
		"score": int(rec.get("score", 0)),
		"time_left": int(rec.get("time_left", 0)),
		"times_run": int(rec.get("times_run", 0)),
		"extra_data": extra,
		"platform": MainGlobals.get_platform_id(),
	}

func upload_game_score(game_name: String, rec: Dictionary) -> void:
	if not MainCfg.use_BE or offline_mode or MainCfg.is_anonymous_user:
		return
	if not rec.has("ts"):
		return
	var access_token: String = get_access_token()
	var user_id: String = get_user_id_from_token(access_token)
	if user_id.is_empty():
		return
	var url: String = SUPABASE_URL + "/rest/v1/game_scores?on_conflict=user_id,game_name,session_ts"
	var headers: PackedStringArray = _auth_json_headers(access_token,
		PackedStringArray(["Prefer: resolution=merge-duplicates"]))
	var payload: Array = [_score_to_payload(user_id, game_name, rec)]
	var session_ts: int = int(rec.get("ts", 0))
	var ext_callable: Callable = Callable(MainGlobals, "mark_score_uploaded").bind(game_name, session_ts)
	_add_request(Callable(self, "_on_score_uploaded"),
		url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload), ext_callable, 4, false, DATA_QUEUE)

func bulk_upload_game_scores(game_name: String, all_scores: Array) -> void:
	if not MainCfg.use_BE or offline_mode or MainCfg.is_anonymous_user:
		return
	if all_scores.is_empty():
		return
	var access_token: String = get_access_token()
	var user_id: String = get_user_id_from_token(access_token)
	if user_id.is_empty():
		return
	var url: String = SUPABASE_URL + "/rest/v1/game_scores?on_conflict=user_id,game_name,session_ts"
	var headers: PackedStringArray = _auth_json_headers(access_token,
		PackedStringArray(["Prefer: resolution=merge-duplicates"]))
	var payload: Array = []
	var ts_list: Array = []
	for rec in all_scores:
		if rec is Dictionary and rec.has("ts"):
			payload.append(_score_to_payload(user_id, game_name, rec))
			ts_list.append(int(rec["ts"]))
	if payload.is_empty():
		return
	var ext_callable: Callable = Callable(MainGlobals, "mark_scores_uploaded_for_game").bind(game_name, ts_list)
	_add_request(Callable(self, "_on_score_uploaded"),
		url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload), ext_callable, 4, false, DATA_QUEUE)

func _on_score_uploaded(response_code: int, body: PackedByteArray, _queue_id, _total_rows, _last_row_index) -> void:
	if response_code == 200 or response_code == 201:
		if current_external_callable[_queue_id].is_valid():
			current_external_callable[_queue_id].call()
	else:
		Log.info("❌ Error uploading game score. Code:", response_code, body.get_string_from_utf8())
		_scores_upload_failed = true

func download_game_scores(game_name: String, callback: Callable) -> void:
	if not MainCfg.use_BE or offline_mode or MainCfg.is_anonymous_user:
		return
	var access_token: String = get_access_token()
	var user_id: String = get_user_id_from_token(access_token)
	if user_id.is_empty():
		return
	var url: String = (SUPABASE_URL + "/rest/v1/game_scores?select=*"
		+ "&user_id=eq." + user_id
		+ "&game_name=eq." + game_name
		+ "&order=session_ts.asc")
	var headers: PackedStringArray = _auth_json_headers(access_token)
	_add_request(Callable(self, "_on_scores_downloaded"),
		url, headers, HTTPClient.METHOD_GET, "", callback, 4, false, DATA_QUEUE)

func delete_game_scores(game_name: String, callback: Callable) -> void:
	if not MainCfg.use_BE or offline_mode or MainCfg.is_anonymous_user:
		if callback.is_valid():
			callback.call(true)
		return
	var access_token: String = get_access_token()
	var user_id: String = get_user_id_from_token(access_token)
	if user_id.is_empty():
		if callback.is_valid():
			callback.call(false)
		return
	var url: String = (SUPABASE_URL + "/rest/v1/game_scores"
		+ "?user_id=eq." + user_id
		+ "&game_name=eq." + game_name)
	var headers: PackedStringArray = _auth_json_headers(access_token)
	_add_request(Callable(self, "_on_game_scores_deleted"),
		url, headers, HTTPClient.METHOD_DELETE, "", callback, 4, false, DATA_QUEUE)

func _on_game_scores_deleted(response_code: int, _body: PackedByteArray, _queue_id, _total_rows, _last_row_index) -> void:
	var ok: bool = response_code == 200 or response_code == 204
	if not ok:
		Log.info("❌ Error deleting game scores. Code:", response_code)
	var cb: Callable = current_external_callable[_queue_id]
	if cb.is_valid():
		cb.call(ok)

func _on_scores_downloaded(response_code: int, body: PackedByteArray, queue_id: int, _total_rows, _last_row_index) -> void:
	if response_code != 200:
		Log.info("❌ Error downloading scores. Code:", response_code)
		return
	var text: String = body.get_string_from_utf8()
	var data = JSON.parse_string(text)
	if data == null or not data is Array:
		return
	if current_external_callable[queue_id].is_valid():
		current_external_callable[queue_id].call(data)

func sign_in_anon():
	if not MainCfg.use_BE:
		return
	var url = SUPABASE_URL + "/auth/v1/signup"
	var headers: PackedStringArray = _json_headers()
	var body = {
		# "anon": true,
		# "email": null,
		# "password": null
	}

	print("Attempting anonymous sign-in")
	_add_request(Callable(self, "_on_anon_login_completed"), url, headers, HTTPClient.METHOD_POST, JSON.stringify(body), Callable(), 4, false, AUTH_QUEUE)

func _on_anon_login_completed(response_code, body, _queue_id, _total_rows, _last_row_index):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code != 200 and response_code != 201:		
		Log.info("Anon login failed: ", response)
		if response.has("error_code"):
			# var err = response["error_code"]
			# Log.info("Anon login failed. Error code: ", err)
			sig_logged_in.emit(false, LoginFailReasons.Unknown)
		return		
	
	if response and response.has("access_token"):
		Log.info("got access token after anon sign in")
		if response and response.has("refresh_token"):
			Log.info("got refresh token after anon sign in")
		if _handle_auth_success(response, true):
			Log.info("Anon user signed in successfully!")
			Log.info("Session saved after signup")
	else:
		logged_in = false
		Log.info("Missing token data in login response")

func request_password_reset(email: String) -> void:
	if not MainCfg.use_BE:
		return
	var headers: PackedStringArray = _json_headers()
	var body: Dictionary = {"email": email}
	_add_request(Callable(self, "_on_password_reset_completed"),
		SUPABASE_URL + "/auth/v1/recover",
		headers, HTTPClient.METHOD_POST, JSON.stringify(body), Callable(), 4, false, AUTH_QUEUE)

func _on_password_reset_completed(response_code: int, _body: PackedByteArray, _queue_id: int, _total_rows: int, _last_row_index: int) -> void:
	if response_code >= 200 and response_code < 300:
		Log.info("Password reset email sent")
		sig_password_reset_sent.emit(true)
	else:
		Log.info("Password reset request failed: %d" % response_code)
		sig_password_reset_sent.emit(false)
