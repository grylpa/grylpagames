class_name ReauthPopup
extends CanvasLayer

func _ready() -> void:
	MainGlobals.set_popup_open(true)

func _on_login_again_pressed() -> void:
	MainGlobals.set_popup_open(false)
	queue_free()
	var login_screen: Node = get_tree().root.get_node_or_null("Main/LoginScreen")
	if login_screen:
		login_screen.quiet = false
		if login_screen.has_method("show_account_screen"):
			login_screen.call("show_account_screen", false)
		else:
			login_screen.show()

# The flag is global and sticky: while it is set, scripts/main.gd blanks the digitized-swipe flags
# every frame, which silently kills udbr, mother and crack (the games driven by them) until the app
# is restarted. Clearing it only from the two buttons meant any other way of this popup going away
# — a scene change, a programmatic free — left every breathing game dead. This popup appears when
# the session expires, i.e. after the app has been sitting idle, which is exactly when players hit
# it.
func _exit_tree() -> void:
	MainGlobals.set_popup_open(false)

func _on_stay_offline_pressed() -> void:
	BE.offline_mode = true
	MainGlobals.set_popup_open(false)
	queue_free()
