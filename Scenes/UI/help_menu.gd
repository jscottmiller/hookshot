class_name HelpMenu extends Control

@onready var on_panel := %OnPanel as Panel
@onready var off_panel := %OffPanel as Panel

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_help"):
		on_panel.visible = !on_panel.visible
		off_panel.visible = !off_panel.visible
