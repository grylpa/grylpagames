extends CanvasLayer

# The look is the app's, not this screen's own: the drawn ground from scripts/screen_backdrop.gd,
# the card from ScreenBackdrop.card_style(), the buttons from GameButton, the fields and tabs from
# ScreenBackdrop.style_field / style_tab. Nothing about the layout, the flow or the logic changed —
# only what it is made of.
#
# What it was: a tiled `res://pneumo/art/grass_dark.png` (one GAME's art, worn by an app-level
# screen), a black 25%-alpha panel with a hard black border, tab buttons drawn as a yellow 3px
# outline open at the bottom over a form panel with a yellow 3px outline open at the top, and
# near-black flat rectangles for the text fields. It matched no other screen in the app, including
# the menu it is opened from.

const ACCENT: Color = ScreenBackdrop.ACCENT

var _bg: Control = null
var _bg_t: float = 0.0

var hide_after_hide: bool = false
var quiet: bool = true
enum TabMode { LOGIN, SIGNUP, GUEST }

var _tab_mode: TabMode = TabMode.LOGIN
var _forgot_mode: bool = false
var _is_processing: bool = false
var _pending_password: String = ""
var _force_name_entry: bool = false
var _guest_local_margin: MarginContainer = null
var _standalone_name_editor: bool = false

func _ready() -> void:
	%LoginMessage.hide()
	BE.sig_created_player.connect(_on_BE_sig_created_player)
	BE.sig_logged_in.connect(_on_BE_sig_logged_in)
	BE.sig_password_reset_sent.connect(_on_password_reset_sent)
	$FullScreenMessage.message_timer_timeout.connect(_on_message_timer_timeout)
	$FullScreenMessage.message_pressed.connect(_on_full_screen_message_pressed)
	visibility_changed.connect(_on_visibility_changed)
	if not %LoginCloseBtn.button_pressed.is_connected(_on_close_btn_pressed):
		%LoginCloseBtn.button_pressed.connect(_on_close_btn_pressed)
	_guest_local_margin = MarginContainer.new()
	_guest_local_margin.name = "GuestLocalMargin"
	_guest_local_margin.add_theme_constant_override("margin_left", 40)
	_guest_local_margin.add_theme_constant_override("margin_right", 40)
	_guest_local_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guest_local_margin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	%ShowPasswordBtn.text = ""
	%ShowPasswordBtn.icon = load("res://art/eye_open.svg")
	%ShowPasswordBtn.expand_icon = true
	%ShowPasswordBtn.modulate = Color(0.6, 0.6, 0.6, 1)
	_apply_look()
	_apply_tab()

# Cosmetics only. Every node here already existed and keeps its place in the tree; this just says
# what each one is made of.
func _apply_look() -> void:
	var ground: TextureRect = $BackgroundPanel/TextureRect
	ground.texture = null
	_bg = ScreenBackdrop.attach(ground)
	if _bg.draw.get_connections().is_empty():
		_bg.draw.connect(func() -> void:
			ScreenBackdrop.draw(_bg, _bg_t, ScreenBackdrop.LOGIN_TOP, ScreenBackdrop.LOGIN_BOT, ACCENT))
	set_process(true)

	# The panel behind everything was a black rectangle with a hard black border drawn over the
	# grass. With a drawn ground under it, it only has to hold the ground still.
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = ScreenBackdrop.LOGIN_BOT
	$BackgroundPanel.add_theme_stylebox_override("panel", flat)
	$BackgroundPanel/BorderPanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	%FormBorderPanel.add_theme_stylebox_override("panel", ScreenBackdrop.card_style(20))

	%TabHBox.add_theme_constant_override("separation", 8)

	for le: LineEdit in [%Username, %Email, %Password, %GuestName]:
		ScreenBackdrop.style_field(le, ACCENT)
	for lb: Label in [%UsernameLabel, %EmailLabel, %PasswordLabel, %GuestPromptLabel]:
		ScreenBackdrop.style_caption(lb, true)
	ScreenBackdrop.style_title(%GuestTitleLabel, ACCENT)
	ScreenBackdrop.style_close(%LoginCloseBtn, ACCENT)
	ScreenBackdrop.style_caption(%GuestNameMessage, true)
	ScreenBackdrop.style_caption(%LoginMessage)

	# The one button that finishes the job is the filled one; everything that steps back or sideways
	# is a ghost, the same weight relationship the confirmation dialog uses.
	var ink: Color = ResultCard.HEADER_INK
	var fs: int = 34 if MainGlobals.is_mobile() else 22
	GameButton.style(%ActionButton, ACCENT, ink, fs)
	# GuestMargin's child, which is not a unique name in the scene.
	var guest_btn: Button = %GuestMargin.get_node_or_null("GuestButton") as Button
	if guest_btn != null:
		GameButton.style(guest_btn, ACCENT, ink, fs, true)
	# Back and Play are drawn the SAME. They are not a safe/destructive pair like the confirmation
	# dialog's — one goes on, one goes back, and neither loses anything — so weighting one of them
	# would be saying something about them that is not true.
	for b: Button in [%GuestBackBtn, %GuestPlayBtn]:
		GameButton.style(b, ACCENT, ink, fs)
	GameButton.style(%ForgotPasswordBtn, ACCENT, ink, fs - 6, true)

func _process(delta: float) -> void:
	if _bg != null and is_instance_valid(_bg) and _bg.is_visible_in_tree():
		_bg_t += delta
		_bg.queue_redraw()

func _on_visibility_changed() -> void:
	if visible:
		hide_after_hide = false
		if _is_guest_name_only_mode() or _force_name_entry or _standalone_name_editor:
			_tab_mode = TabMode.GUEST
		elif MainGlobals.user_file_key.begins_with("guest_"):
			_tab_mode = TabMode.GUEST
		else:
			_tab_mode = TabMode.LOGIN
		_apply_tab()

func _apply_tab_style(btn: Button, is_active: bool) -> void:
	ScreenBackdrop.style_tab(btn, ACCENT, is_active)

func _is_guest_tab() -> bool:
	return _tab_mode == TabMode.GUEST

func _is_signup_tab() -> bool:
	return _tab_mode == TabMode.SIGNUP

func _is_login_tab() -> bool:
	return _tab_mode == TabMode.LOGIN

func _is_local_name_mode() -> bool:
	return not MainCfg.use_BE

func _is_guest_name_only_mode() -> bool:
	return not MainCfg.use_BE or MainCfg.is_anonymous_user

func _is_name_only_layout() -> bool:
	return _is_guest_name_only_mode() or _standalone_name_editor

func _apply_guest_panel_texts() -> void:
	if _is_local_name_mode() or _standalone_name_editor:
		%GuestTitleLabel.visible = true
		%GuestTitleLabel.text = "Player Name"
		%GuestPromptLabel.text = "Enter your player name"
		%GuestPlayBtn.text = "Continue"
		%GuestBackBtn.text = "Cancel"
	elif MainCfg.is_anonymous_user:
		%GuestTitleLabel.visible = true
		%GuestTitleLabel.text = "Guest Name"
		%GuestPromptLabel.text = "Choose your guest name"
		%GuestPlayBtn.text = "Continue"
		%GuestBackBtn.text = "Cancel"
	else:
		%GuestTitleLabel.visible = false
		%GuestTitleLabel.text = "Play as Guest"
		%GuestPromptLabel.text = "Choose your player name"
		%GuestPlayBtn.text = "Play"
		%GuestBackBtn.text = "Cancel"

func _current_local_name() -> String:
	if MainGlobals.user_file_key.begins_with("guest_"):
		return MainGlobals.user_file_key.trim_prefix("guest_")
	return ""

func _set_auth_form_visible(show_auth_form: bool) -> void:
	%FormBorderPanel.get_node("FormVBox/TabSpacerMargin").visible = show_auth_form
	%FormBorderPanel.get_node("FormVBox/MarginContainer").visible = show_auth_form
	%FormBorderPanel.get_node("FormVBox/MarginContainer2").visible = show_auth_form
	%FormBorderPanel.get_node("FormVBox/PasswordRow").visible = show_auth_form and not _forgot_mode
	%FormBorderPanel.get_node("FormVBox/ButtonMargin").visible = show_auth_form
	%EmailLabel.visible = show_auth_form
	%Email.visible = show_auth_form
	%PasswordLabel.visible = show_auth_form and not _forgot_mode
	%ActionButton.visible = show_auth_form
	%UsernameLabel.visible = show_auth_form and _is_signup_tab()
	%Username.visible = show_auth_form and _is_signup_tab()
	%ForgotPasswordBtn.visible = show_auth_form and _is_login_tab() and not _forgot_mode

func _place_guest_panel(name_only_layout: bool) -> void:
	if name_only_layout:
		if _guest_local_margin.get_parent() != %VBoxContainer:
			%VBoxContainer.add_child(_guest_local_margin)
		if %GuestNamePanel.get_parent() != _guest_local_margin:
			%GuestNamePanel.reparent(_guest_local_margin)
	else:
		if _guest_local_margin.get_parent() != null and _guest_local_margin.get_child_count() == 0:
			_guest_local_margin.get_parent().remove_child(_guest_local_margin)
		var target_parent: Node = %FormBorderPanel.get_node("FormVBox")
		if %GuestNamePanel.get_parent() != target_parent:
			%GuestNamePanel.reparent(target_parent)

func _apply_tab() -> void:
	hide_after_hide = false
	_forgot_mode = false
	_is_processing = false
	_apply_guest_panel_texts()
	var guest_name_only: bool = _is_guest_name_only_mode()
	var name_only_layout: bool = _is_name_only_layout()
	var show_guest: bool = _is_guest_tab() or guest_name_only
	_place_guest_panel(name_only_layout)
	%VBoxContainer.visible = true
	%FormBorderPanel.visible = not name_only_layout
	%GuestNamePanel.visible = show_guest
	_set_auth_form_visible(not show_guest and not name_only_layout)
	%GuestMargin.visible = false
	%LoginTabBtn.visible = MainCfg.use_BE and not MainCfg.is_anonymous_user and not _standalone_name_editor
	%SignupTabBtn.visible = MainCfg.use_BE and not MainCfg.is_anonymous_user and not _standalone_name_editor
	%GuestTabBtn.visible = MainCfg.use_BE and not MainCfg.is_anonymous_user and not _standalone_name_editor
	%LoginCloseBtn.visible = not _force_name_entry
	%TabHBox.visible = MainCfg.use_BE and not MainCfg.is_anonymous_user and not _standalone_name_editor
	if MainCfg.use_BE and not MainCfg.is_anonymous_user and not _standalone_name_editor:
		_apply_tab_style(%LoginTabBtn, _is_login_tab())
		_apply_tab_style(%SignupTabBtn, _is_signup_tab())
		_apply_tab_style(%GuestTabBtn, _is_guest_tab())
	if _is_login_tab() and not name_only_layout:
		%ActionButton.text = "Log In"
		%EmailLabel.text = "Email or Username"
	elif _is_signup_tab() and not name_only_layout:
		%ActionButton.text = "Sign Up"
		%EmailLabel.text = "Email"
	if show_guest:
		%GuestBackBtn.visible = _is_name_only_layout() and not _force_name_entry
		if %GuestName.text.is_empty():
			%GuestName.text = _current_local_name()
		%GuestNameMessage.hide()
		if not MainGlobals.is_mobile():
			%GuestName.call_deferred("grab_focus")
	else:
		if not MainGlobals.is_mobile():
			%Email.call_deferred("grab_focus")

func _on_login_tab_pressed() -> void:
	_standalone_name_editor = false
	_tab_mode = TabMode.LOGIN
	_apply_tab()

func _on_signup_tab_pressed() -> void:
	_standalone_name_editor = false
	_tab_mode = TabMode.SIGNUP
	_apply_tab()

func _on_guest_tab_pressed() -> void:
	_standalone_name_editor = false
	_tab_mode = TabMode.GUEST
	_apply_tab()

func _on_forgot_password_pressed() -> void:
	_forgot_mode = true
	%ActionButton.text = "Send Reset Email"
	%EmailLabel.text = "Email or Username"
	_set_auth_form_visible(true)

func _set_processing(value: bool) -> void:
	_is_processing = value
	%ActionButton.disabled = value
	if value:
		%ActionButton.text = "Please wait..."
	elif _forgot_mode:
		%ActionButton.text = "Send Reset Email"
	elif _is_login_tab():
		%ActionButton.text = "Log In"
	else:
		%ActionButton.text = "Sign Up"

func _on_action_button_pressed() -> void:
	if _is_processing:
		return
	var input: String = %Email.text.strip_edges()
	if _forgot_mode:
		if input.is_empty():
			message("Enter your email or username")
			return
		_set_processing(true)
		if "@" in input:
			_do_forgot_with_email(input)
		else:
			BE.lookup_email_by_username(input, Callable(self, "_on_forgot_email_lookup"))
		return
	var password: String = %Password.text.strip_edges()
	if input.is_empty() or password.is_empty():
		message("Email/username and password cannot be empty")
		return
	if _is_login_tab():
		_set_processing(true)
		if "@" in input:
			_do_login_with_email(input, password)
		else:
			_pending_password = password
			BE.lookup_email_by_username(input, Callable(self, "_on_login_email_lookup"))
	else:
		var username: String = %Username.text.strip_edges()
		if username.is_empty():
			message("Username cannot be empty")
			return
		_set_processing(true)
		BE.register_user(input, password, username)

func _do_login_with_email(email: String, password: String) -> void:
	BE.login_user(email, password, "")

func _do_forgot_with_email(email: String) -> void:
	BE.request_password_reset(email)
	message("Sending reset email...")

func _on_login_email_lookup(email: String) -> void:
	if email.is_empty():
		_set_processing(false)
		message("No account found for that username")
		return
	_do_login_with_email(email, _pending_password)

func _on_forgot_email_lookup(email: String) -> void:
	if email.is_empty():
		_set_processing(false)
		message("No account found for that username")
		return
	_do_forgot_with_email(email)

func _on_close_btn_pressed() -> void:
	_standalone_name_editor = false
	hide()

func _on_show_password_pressed() -> void:
	%Password.secret = not %Password.secret
	if %Password.secret:
		%ShowPasswordBtn.icon = load("res://art/eye_open.svg")
		%ShowPasswordBtn.modulate = Color(0.6, 0.6, 0.6, 1)
	else:
		%ShowPasswordBtn.icon = load("res://art/eye_slash.svg")
		%ShowPasswordBtn.modulate = Color(1, 1, 1, 1)

func _on_guest_button_pressed() -> void:
	_tab_mode = TabMode.GUEST
	_apply_tab()

func show_guest_name_only() -> void:
	quiet = false
	_force_name_entry = true
	_standalone_name_editor = true
	_tab_mode = TabMode.GUEST
	show()
	_apply_tab()

func show_local_name_screen() -> void:
	quiet = false
	_force_name_entry = false
	_standalone_name_editor = true
	_tab_mode = TabMode.GUEST
	show()
	_apply_tab()

func show_account_screen(prefer_guest_tab: bool = false) -> void:
	quiet = false
	_force_name_entry = false
	_standalone_name_editor = false
	_tab_mode = TabMode.GUEST if prefer_guest_tab else TabMode.LOGIN
	show()
	_apply_tab()

func _on_guest_back_pressed() -> void:
	if _force_name_entry:
		return
	if _is_name_only_layout():
		_standalone_name_editor = false
		hide()
		return
	_tab_mode = TabMode.LOGIN
	_apply_tab()

func _on_guest_name_changed(new_text: String) -> void:
	if new_text.is_empty():
		%GuestNameMessage.hide()
		return
	var sanitized: String = MainGlobals.sanitize_guest_name(new_text)
	if sanitized.is_empty():
		%GuestNameMessage.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		%GuestNameMessage.text = "Name must contain letters or digits"
		%GuestNameMessage.show()
	else:
		%GuestNameMessage.hide()

func _on_guest_name_submitted(_text: String) -> void:
	_do_guest_play()

func _on_guest_play_pressed() -> void:
	_do_guest_play()

func _do_guest_play() -> void:
	hide_after_hide = false
	var old_key: String = MainGlobals.user_file_key
	var raw: String = %GuestName.text
	var sanitized: String = MainGlobals.sanitize_guest_name(raw)
	if sanitized.is_empty():
		%GuestNameMessage.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		%GuestNameMessage.text = "Name must contain letters or digits"
		%GuestNameMessage.show()
		return
	var is_returning: bool = MainGlobals.is_guest_name_taken(raw)
	MainGlobals.register_guest_name(raw)
	var name_changed: bool = MainGlobals.user_file_key != old_key
	if old_key.begins_with("guest") and old_key != MainGlobals.user_file_key:
		MainGlobals.migrate_scores_to_user_key(old_key)
	MainGlobals.save_settings()
	if MainCfg.use_BE and MainCfg.is_anonymous_user:
		BE.sign_in_anon()
	_force_name_entry = false
	_standalone_name_editor = false
	if is_returning and name_changed:
		message("Welcome back, %s!" % sanitized)
	var chooser: Node = get_tree().root.get_node_or_null("Main/GameChooser")
	if chooser and chooser.has_method("refresh_account_state"):
		chooser.call("refresh_account_state")
	hide()

func message(text: String, timeout_ms: int = 3000) -> void:
	$FullScreenMessage.disp(text, true, timeout_ms)

func _on_full_screen_message_pressed() -> void:
	$FullScreenMessage.reset()
	if hide_after_hide:
		hide_after_hide = false
		hide()

func _on_login_message_timer_timeout() -> void:
	%LoginMessage.hide()

func _on_BE_sig_created_player(success: bool, fail_reason: BE.SignupFailReasons) -> void:
	_set_processing(false)
	if success:
		message("Signed up successfully")
	else:
		hide_after_hide = false
		match fail_reason:
			BE.SignupFailReasons.UserExists:
				message("That username is already taken")
			BE.SignupFailReasons.EmailExists:
				message("That email is already registered")
			BE.SignupFailReasons.InvalidEmail:
				message("Enter a valid email address")
			BE.SignupFailReasons.WeakPassword:
				message("Password is too weak")
			_:
				message("Couldn't create account. Try again.")

func _on_BE_sig_logged_in(success: bool, fail_reason: BE.LoginFailReasons) -> void:
	_set_processing(false)
	if quiet:
		return
	if success:
		if MainCfg.is_anonymous_user:
			if not MainGlobals.has_named_guest():
				hide_after_hide = false
				return
			hide_after_hide = false
			hide()
			return
		hide_after_hide = true
		message("Logged in successfully", 200)
	else:
		hide_after_hide = false
		match fail_reason:
			BE.LoginFailReasons.EmailNotVerified:
				message("Verify your email, then try again")
			_:
				message("Couldn't sign in. Check your details or try again when online.")

func _on_password_reset_sent(success: bool) -> void:
	_set_processing(false)
	if success:
		message("Check your email for a reset link")
	else:
		message("Failed to send reset email. Check your address.")

func _on_message_timer_timeout() -> void:
	if hide_after_hide:
		hide()
