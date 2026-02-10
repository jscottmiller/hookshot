class_name Main extends Node

@onready var game := %NetworkGame as NetworkGame
@onready var matchmaker := %MatchmakerConnection as MatchmakerConnection
@onready var ui := %UI as Control
@onready var name_input := %NameInput as TextEdit
@onready var find_match_button := %FindMatchButton as Button
@onready var status_label := %StatusLabel as Label

enum ConnectionState {
	CONNECTING,
	SEARCHING,
	CONNECTED,
	DISCONNECTED,
	MATCH_FOUND,
	CLIENT_OUT_OF_DATE
}

var state := ConnectionState.CONNECTING
var name_strip_re := RegEx.new()


func _ready() -> void:
	name_strip_re.compile("\\W")
	find_match_button.disabled = true
	name_input.editable = false
	
	Music.enabled = true
	Music.play_track("EnergeticUndergroundTechnoLoop")


func _on_name_input_text_changed() -> void:
	var raw := name_input.text
	var name := name_strip_re.sub(raw, "", true)
	
	game.player_name = name
	find_match_button.disabled = name == ""


func _on_find_match_button_pressed() -> void:
	name_input.editable = false
	find_match_button.disabled = true
	
	matchmaker.request_match()
	status_label.text = "searching for a match..."
	state = ConnectionState.SEARCHING


func _on_matchmaker_connection_server_found(address: String, port: int, ticket_id: String) -> void:
	state = ConnectionState.MATCH_FOUND
	game.join_server(address, port, ticket_id)
	ui.hide()
	
	Music.play_track("EnergyCyberpunkLoop")


func _on_matchmaker_connection_status(player_count: int) -> void:
	if state == ConnectionState.CONNECTED:
		status_label.text = "{0} player(s) online".format([player_count])


func _on_link_button_pressed() -> void:
	OS.shell_open("https://discord.gg/96RTJVR9dk")


func _on_network_game_game_ended() -> void:
	get_tree().reload_current_scene()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_matchmaker_connection_connected() -> void:
	state = ConnectionState.CONNECTED
	status_label.text = "Connected"
	name_input.editable = true


func _on_matchmaker_connection_disconnected() -> void:
	state = ConnectionState.CONNECTING
	status_label.text = "Connecting..."
	name_input.editable = true


func _on_network_game_client_out_of_date() -> void:
	state = ConnectionState.CLIENT_OUT_OF_DATE
	status_label.text = "Game out of date, please update"
	find_match_button.disabled = true
	name_input.editable = false
	ui.show()
