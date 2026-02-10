class_name Intro extends Control


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	if OS.get_cmdline_args().find("--server") >= 0:
		get_tree().change_scene_to_file("res://Scenes/Game/server.tscn")
		return
	
	get_tree().change_scene_to_file("res://Scenes/Game/main.tscn")
