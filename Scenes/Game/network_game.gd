class_name NetworkGame extends Node

signal game_ready
signal game_ended
signal client_out_of_date

@onready var logger := %Logger as Logger
@onready var players := %Players
@onready var level_container := %LevelContainer
@onready var game_mode_container := %GameModeContainer
@onready var chat_panel := %ChatPanel as ChatPanel
@onready var announcer := %Announcer as Announcer

var running := false
var access_token: String
var current_level_path := "res://Scenes/Levels/Test/test_level.tscn"
var current_level: Variant
var current_game_mode: Variant
var local_player: Player
var player_name := "anonymous"
var recent_chat_messages := []

enum RejectReason {
	CLIENT_OUT_OF_DATE,
	INVALID_ACCESS_TOKEN
}


class ChatMessage:
	var sender: int
	var timestamp: float
	var message: String
	
	func _init(sender: int, timestamp: float, message: String) -> void:
		self.sender = sender
		self.timestamp = timestamp
		self.message = message


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func start_server(address: String, port: int) -> void:
	logger.announce("starting server at {0}:{1}, version {2}", [address, port, Globals.version])
	
	var peer := ENetMultiplayerPeer.new()
	
	peer.set_bind_ip(address)
	peer.create_server(port)
	
	multiplayer.set_multiplayer_peer(peer)
	peer.peer_connected.connect(_on_server_peer_connected)
	peer.peer_disconnected.connect(_on_server_peer_disconnected)


func join_server(address: String, port: int, token: String) -> void:
	logger.trace("joining server at {0}:{1}", [address, port])
	
	_unload_current_level()
	
	access_token = token
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	
	multiplayer.set_multiplayer_peer(peer)
	peer.peer_connected.connect(_on_client_peer_connected)
	peer.peer_disconnected.connect(_on_client_peer_disconnected)
	
	#chat_panel.enable()


func start_game():
	logger.trace("starting game")
	
	if running:
		end_game(true)
	
	_load_level(current_level_path)
	running = true
	access_token = ""
	emit_signal("game_ready")


func end_game(silent=false):
	logger.trace("ending game")
	
	for peer_id in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
		
	_unload_current_level()
	running = false
	
	if !silent:
		emit_signal("game_ended")


func set_access_token(token: String) -> void:
	access_token = token


func _on_chat_panel_chat_message(message: String) -> void:
	rpc_id(get_multiplayer_authority(), "store_chat_message", message)


func _on_chat_panel_chat_focus_changed(has_focus: bool) -> void:
	if not local_player:
		return
	if has_focus:
		local_player.disable_inputs()
	else:
		local_player.enable_inputs()


func _on_game_mode_request_respawn(player_id: int) -> void:
	if not is_multiplayer_authority():
		return
	
	logger.trace("respawning player {0}", [player_id])
	var spawn_point := current_level.choose_spawn_point() as Vector3
	
	rpc_id(player_id, "respawn_player", player_id, spawn_point)


func _on_game_mode_game_over() -> void:
	if not is_multiplayer_authority():
		return
	
	logger.trace("ending game on server")
	
	end_game()


func _on_game_mode_enable_player_weapons(enabled: bool) -> void:
	logger.trace("game mode requests weapons enabled = {0}", [enabled])
	rpc("enable_local_weapons", enabled)


func _on_game_mode_announce(announcement: Announcer.Announcement, recipients: Array) -> void:
	for recipient in recipients:
		rpc_id(recipient, "announce", announcement)


func player_died(player_id: int, aggressor_id: int) -> void:
	if multiplayer.get_unique_id() != player_id:
		return
	
	rpc("report_player_death", player_id, aggressor_id)


func _on_server_peer_connected(new_peer_id: int) -> void:
	logger.trace("peer connected {0}", [new_peer_id])
	connect_player(new_peer_id)


func _on_server_peer_disconnected(peer_id: int) -> void:
	logger.trace("peer disconnected", [peer_id])
	
	disconnect_player(peer_id)
	rpc("disconnect_player", peer_id)
	
	if current_game_mode:
		current_game_mode.disconnect_player(peer_id)


func _on_client_peer_connected(peer_id: int) -> void:
	logger.trace("server connected {0}", [peer_id])
	await get_tree().create_timer(1).timeout
	
	rpc_id(peer_id, "register_client", Globals.version, access_token)


func _on_client_peer_disconnected(peer_id: int) -> void:
	logger.trace("server disconnected", [peer_id])
	
	_end_game_on_client()


func _unload_current_level() -> void:
	remove_all_player_characters()
	
	if current_level:
		current_level.queue_free()
		current_level = null
	
	if current_game_mode:
		current_game_mode.queue_free()
		current_game_mode.disconnect("request_respawn", _on_game_mode_request_respawn)
		current_game_mode.disconnect("game_over", _on_game_mode_game_over)
		current_game_mode.disconnect("enable_player_weapons", _on_game_mode_enable_player_weapons)
		current_game_mode.disconnect("announce", _on_game_mode_announce)
		current_game_mode = null
	
	Globals.clear_clients()


func _load_level(path: String) -> void:
	logger.trace("loading level: {0}", [path])
	
	var Level := load(path)
	
	current_level = Level.instantiate()
	level_container.add_child(current_level)
	
	current_game_mode = load("res://Scenes/Game/rocket_arena_game_mode.tscn").instantiate()
	game_mode_container.add_child(current_game_mode)
	
	current_game_mode.connect("request_respawn", _on_game_mode_request_respawn)
	current_game_mode.connect("game_over", _on_game_mode_game_over)
	current_game_mode.connect("enable_player_weapons", _on_game_mode_enable_player_weapons)
	current_game_mode.connect("announce", _on_game_mode_announce)
	
	logger.trace("level loaded: {0}", [path])


func _end_game_on_client() -> void:
	_unload_current_level()
	
	multiplayer.multiplayer_peer.peer_connected.disconnect(_on_client_peer_connected)
	multiplayer.multiplayer_peer.peer_disconnected.connect(_on_client_peer_disconnected)
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
	if running:
		emit_signal("game_ended")


func _add_player_character(peer_id: int, spawn_point: Vector3) -> Player:
	logger.trace("adding player character {0}", [peer_id])
	
	var client := Globals.get_client(peer_id)
	if client == null:
		logger.warn("_add_player_character: no client")
		return
	
	if client.player:
		_remove_player_character(peer_id)
	
	logger.trace("player name set to {0}", [client.name])
	
	var player := preload("res://Scenes/Characters/Player/player.tscn").instantiate() as Player
	player.position = spawn_point
	player.name = str(peer_id)
	player.player_name = client.name
	
	player.set_multiplayer_authority(peer_id)
	
	client.player = player
	
	players.add_child(player)
	
	var me := multiplayer.get_unique_id()
	if peer_id == me:
		local_player = player
		rpc("player_ready", peer_id, spawn_point)
	else:
		# This is needed otherwise the `update_health` rpc calls will fail
		player.make_visible_to(peer_id)
		rpc_id(peer_id, "force_visibility", me)
	
	logger.trace("player added")
	return player


func _remove_player_character(peer_id: int) -> bool:
	logger.trace("removing player character {0}", [peer_id])
	
	var client := Globals.get_client(peer_id)
	if client != null:
		logger.warn("_remove_player_character: no client")
		return false
	
	if not client.player:
		return false
	
	# free is used here rather than queue_free to prevent node
	# name collisions that break the sync logic
	client.player.free()
	client.player = null
	
	if peer_id == multiplayer.get_unique_id():
		local_player = null

	logger.trace("player removed")
	return true


@rpc
func connect_player(player_id: int, player_name: String = "") -> void:
	if Globals.has_client(player_id):
		logger.warn("connect_player: client was previously connected")
		_remove_player_character(player_id)
		Globals.remove_client_by_id(player_id)
	
	var new_client := ConnectedClient.new()
	new_client.id = player_id
	if player_name:
		new_client.name = player_name
	
	Globals.add_client(new_client)
	logger.trace("player {0} connected", [player_id])


@rpc
func reject_player(reason: RejectReason) -> void:
	logger.trace("player connection rejected")
	
	multiplayer.multiplayer_peer.disconnect_peer(1)
	
	if reason == RejectReason.CLIENT_OUT_OF_DATE:
		emit_signal("client_out_of_date")


@rpc
func disconnect_player(player_id: int) -> void:
	logger.trace("player {0} disconnected", [player_id])
	
	var client := Globals.get_client(player_id)
	if client == null:
		logger.warn("disconnect_player: no client")
		return
		
	Globals.remove_client_by_id(player_id)
	if client.player:
		client.player.queue_free()


@rpc
func initialize_client(path: String) -> void:
	logger.trace("loading level {0}", [path])
	
	_load_level(path)
	
	running = true
	
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		rpc_id(get_multiplayer_authority(), "level_loaded")
		rpc("set_player_name", player_name)


@rpc
func enable_local_weapons(enabled: bool) -> void:
	logger.trace("setting player weapons enabled = {0}", [enabled])
	if local_player:
		local_player.set_weapons_enabled(enabled)


@rpc
func remove_all_player_characters() -> void:
	for client in Globals.all_clients():
		_remove_player_character(client.id)


@rpc
func respawn_player(player_id: int, spawn_point: Vector3) -> void:
	_add_player_character(player_id, spawn_point)


@rpc
func add_previously_connected_player_character(other_player_id: int, spawn_point: Vector3) -> void:
	_add_player_character(other_player_id, spawn_point)


@rpc
func announce(announcement: Announcer.Announcement) -> void:
	announcer.announce(announcement)


@rpc("call_local")
func broadcast_chat(sender: int, timestamp: float, text: String) -> void:
	var message := ChatMessage.new(sender, timestamp, text)
	recent_chat_messages.append(message)
	
	var client = Globals.get_client(sender)
	if client == null:
		return
	
	var display_message := "{0}: {1}".format([client.name, text])
	chat_panel.add_message(display_message)


@rpc("any_peer")
func register_client(client_version: String, token: String) -> void:
	var player_id := multiplayer.get_remote_sender_id()
	logger.trace("client {0} registering with version {1}", [player_id, client_version])
	if client_version != Globals.version:
		logger.trace("client version out of date, disconnecting: {0}", [player_id])
		rpc_id(player_id, "reject_player", RejectReason.CLIENT_OUT_OF_DATE)
		disconnect_player(player_id)
		return
	elif access_token == "" or access_token != token:
		logger.trace("invalid access token, disconnecting: {0}", [player_id])
		rpc_id(player_id, "reject_player", RejectReason.INVALID_ACCESS_TOKEN)
		disconnect_player(player_id)
		return
	
	rpc("connect_player", player_id)
	rpc_id(player_id, "initialize_client", current_level_path)


@rpc("any_peer")
func level_loaded() -> void:
	if not is_multiplayer_authority():
		return
	
	logger.trace("level loaded from player {0}", [multiplayer.get_remote_sender_id()])
	
	var player_id := multiplayer.get_remote_sender_id()
	
	var client := Globals.get_client(player_id)
	if not client:
		return
	
	current_game_mode.register_player(player_id, client.name)
	
	current_level.connect_peer(player_id)
	
	for other in Globals.all_clients():
		if other.id == player_id:
			continue
		rpc_id(player_id, "connect_player", other.id, other.name)
		if other.player:
			rpc_id(player_id, "add_previously_connected_player_character", other.id, other.player.position)


@rpc("any_peer")
func player_ready(player_id: int, spawn_point: Vector3):
	_add_player_character(player_id, spawn_point)


@rpc("any_peer")
func store_chat_message(text: String):
	if not is_multiplayer_authority():
		return
	
	var sender := multiplayer.get_remote_sender_id()
	var timestamp := Time.get_unix_time_from_system()
	
	rpc("broadcast_chat", sender, timestamp, text)


@rpc("any_peer")
func force_visibility(player_id: int) -> void:
	logger.trace("forcing visibility to {0}", [player_id])
	
	if local_player == null:
		logger.warn("force_visibility: no local player")
		return
	
	local_player.make_visible_to(player_id)


@rpc("any_peer", "call_local")
func set_player_name(name: String) -> void:
	logger.trace("setting player name to {0}", [name])
	
	var player_id := multiplayer.get_remote_sender_id()
	if current_game_mode:
		current_game_mode.set_player_name(player_id, name)
	
	var client = Globals.get_client(player_id)
	if client != null:
		client.name = name
		if client.player:
			client.player.set_player_name(name)


@rpc("any_peer", "call_local")
func report_player_death(player_id: int, aggressor_id: int) -> void:
	if multiplayer.get_remote_sender_id() != player_id:
		return
	
	if not _remove_player_character(player_id):
		return
	
	if is_multiplayer_authority() and current_game_mode:
		current_game_mode.handle_player_death(player_id, aggressor_id)
