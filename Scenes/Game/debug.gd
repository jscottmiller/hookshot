class_name Debug extends Node

@onready var ui := %UI as Control
@onready var game := %NetworkGame as NetworkGame

var server := true


func _on_host_button_pressed() -> void:
	game.start_server("127.0.0.1", 9999)
	game.start_game()
	game.set_access_token("abc")
	ui.hide()


func _on_join_button_pressed() -> void:
	server = false
	game.join_server("127.0.0.1", 9999, "abc")
	ui.hide()


func _on_network_game_game_ended() -> void:
	if server:
		game.start_game()
		game.set_access_token("abc")
	else:
		get_tree().reload_current_scene()


func _on_network_game_game_ready() -> void:
	pass # Replace with function body.
