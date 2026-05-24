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

func _on_stay_offline_pressed() -> void:
	BE.offline_mode = true
	MainGlobals.set_popup_open(false)
	queue_free()
