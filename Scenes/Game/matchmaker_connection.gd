class_name MatchmakerConnection extends Node

signal status
signal server_found
signal server_allocated
signal server_registered
signal disconnected
signal connected

@export var server := true

@onready var logger := %Logger as Logger
@onready var ping_timer := %PingTimer as Timer
@onready var reconnect_timer := %ReconnectTimer as Timer

var client: WebSocketPeer
var initialized := false
var message_queue := []


func _ready() -> void:
	_connect()


func _connect() -> void:
	logger.trace("connecting to matchmaker")
	if client:
		logger.error("connection already created")
		return
	
	client = WebSocketPeer.new()
	
	var url := (
		"ws://hookshot-matchmaker.cowboyscott.games/server?{0}" 
		if server else 
		"ws://hookshot-matchmaker.cowboyscott.games/client?{0}"
	)
	
	# When the matchmaker restarts, it will get a new public IP. Therefore,
	# we want to clear the cache on all reconnects (which call _connect).
	IP.clear_cache("hookshot-matchmaker.cowboyscott.games")
	client.connect_to_url(url)


func connect_server() -> void:
	logger.trace("connecting to server endpoint")
	if client:
		logger.error("connection already created")
		return
	
	client = WebSocketPeer.new()
	client.connect_to_url("ws://hookshot-matchmaker.cowboyscott.games/server")


func unregister() -> void:
	logger.trace("unregistering server")
	
	if !server:
		logger.error("only server connections may unregister")
		return
	
	message_queue.append({
		"message_type": "unregister"
	})


func register(address: String, port: int) -> void:
	logger.trace("registering server")
	
	if !server:
		logger.error("only server connections may register")
		return
	
	message_queue.append({
		"message_type": "register",
		"address": address,
		"port": port,
		"capacity": 8
	})


func request_match() -> void:
	if server:
		logger.error("only client connections may request a match")
		return
	
	message_queue.append({
		"message_type": "request-match",
	})


func _process(delta: float) -> void:
	_handle_websocket_connection()


func _on_ping_timer_timeout() -> void:
	if client:
		message_queue.append({
			"message_type": "ping"
		})


func _handle_websocket_connection():
	if client == null:
		return
	
	client.poll()
	
	var state = client.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not initialized:
				initialized = true
				logger.trace("connected to matchmaker")
				ping_timer.start()
				emit_signal("connected")
			
			while message_queue.size():
				var message := message_queue.pop_front() as Dictionary
				client.send_text(JSON.stringify(message))
			
			while client.get_available_packet_count():
				var data := client.get_packet()
				var message := JSON.parse_string(data.get_string_from_utf8()) as Dictionary
				_on_websocket_message(message)
		
		WebSocketPeer.STATE_CLOSED:
			var code := client.get_close_code()
			var reason := client.get_close_reason()
			logger.warn("socket closed with code: {0}, reason {1}. Clean: {2}", [code, reason, code != -1])
			
			client.close()
			client = null
			if initialized:
				initialized = false
				ping_timer.stop()
				message_queue.clear()
			
			reconnect_timer.start()
			emit_signal("disconnected")


func _on_websocket_message(message: Dictionary) -> void:
	match message.message_type:
		"server-found":
			emit_signal("server_found", message.address, message.port, message.ticket_id)
		
		"server-registered":
			emit_signal("server_registered", message.ticket_id)
		
		"server-allocated":
			emit_signal("server_allocated", message.ticket_id)
		
		"status":
			emit_signal("status", message.player_count)
		
		"ping":
			pass
		
		_:
			logger.warn("unknown message type: {0}", [message.message_type])


func _on_reconnect_timer_timeout() -> void:
	_connect()
