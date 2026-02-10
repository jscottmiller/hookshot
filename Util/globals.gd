extends Node

signal client_removed
signal client_added

var minimum_log_level := Logger.LogLevel.TRACE
var version: String
var _connected_clients := {}


func _ready() -> void:
	var f := FileAccess.open("res://version", FileAccess.READ)
	version = f.get_as_text(true)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func all_clients() -> Array:
	return _connected_clients.values()


func add_client(client: ConnectedClient) -> void:
	if _connected_clients.has(client.id):
		return
	
	_connected_clients[client.id] = client
	
	emit_signal("client_added", client)


func has_client(client_id: int) -> bool:
	return _connected_clients.has(client_id)


func get_client(client_id: int) -> ConnectedClient:
	return _connected_clients.get(client_id)


func clear_clients() -> void:
	var clients := _connected_clients.values()
	_connected_clients.clear()
	
	for client in clients:
		emit_signal("client_removed", client)


func remove_client_by_id(id: int) -> void:
	var client := _connected_clients.get(id) as ConnectedClient
	if client == null:
		return
	
	_connected_clients.erase(id)
	
	emit_signal("client_removed", client)
