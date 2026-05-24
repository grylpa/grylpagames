extends PanelContainer

@onready var button_tex := %GameSelectButton
@onready var desc := %GameSelectDesc

func _ready() -> void:
	if MainGlobals.is_mobile():
		%HBoxContainer.add_theme_constant_override("separation", 8)
