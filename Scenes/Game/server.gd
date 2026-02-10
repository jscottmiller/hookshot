class_name Server extends Node

@onready var logger := %Logger as Logger
@onready var game := %NetworkGame as NetworkGame
@onready var matchmaker := %MatchmakerConnection as MatchmakerConnection

var address: String
var port: int


func _ready() -> void:
	if not OS.has_environment("SERVER_ADDRESS"):
		logger.error("SERVER_ADDRESS must be defined")
		get_tree().quit()
	
	if not OS.has_environment("SERVER_PORT"):
		logger.error("SERVER_PORT must be defined")
		get_tree().quit()
	
	address = OS.get_environment("SERVER_ADDRESS")
	port = int(OS.get_environment("SERVER_PORT"))
	
	game.start_server("0.0.0.0", port)
	game.start_game()


func _on_network_game_game_ended() -> void:
	game.start_game()


func _on_network_game_game_ready() -> void:
	matchmaker.register(address, port)


func _on_matchmaker_connection_server_registered(ticket_id: String) -> void:
	game.set_access_token(ticket_id)


func _on_matchmaker_connection_connected() -> void:
	if game.running:
		matchmaker.register(address, port)
