class_name DeathmatchGameMode extends Node

signal request_respawn
signal enable_player_weapons
signal game_over
signal announce

@onready var logger := %Logger as Logger
@onready var sync := %MultiplayerSynchronizer as MultiplayerSynchronizer
@onready var state_machine := %AnimationTree["parameters/playback"] as AnimationNodeStateMachinePlayback
@onready var scoreboard := %Scoreboard as Scoreboard

const RESPAWN_SECONDS := 5.0

@export var player_info := {}

var respawn_queue := []


var state: String:
	get:
		return String(state_machine.get_current_node())


func _process(delta: float) -> void:
	_check_respawn_queue(delta)


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("show_scoreboard"):
		scoreboard.visible = !scoreboard.visible
		if scoreboard.visible:
			_populate_scoreboard()


func register_player(player_id: int, name: String) -> void:
	logger.trace("registering player {0}", [player_id])
	
	if player_id in player_info:
		logger.warn("player {0} already registered", [player_id])
		return
	
	sync.set_visibility_for(player_id, true)
	sync.update_visibility()
	
	player_info[player_id] = {
		"name": name,
		"kills": 0,
		"deaths": 0,
	}
	
	_respawn_player(player_id)
	
	var total_players := player_info.size()
	if state == "WaitingForPlayers" and total_players > 1:
		state_machine.travel("GameAboutToStart")


func disconnect_player(player_id: int) -> void:
	logger.trace("unregistering player {0}", [player_id])
	
	var info = player_info.get(player_id)
	if info == null:
		return
	
	player_info.erase(player_id)
	
	var total_players := player_info.size()
	if total_players == 1:
		match state:
			"GameAboutToStart", "GameInProgress":
				state_machine.travel("WaitingForPlayers")


func set_player_name(player_id: int, name: String) -> void:
	logger.trace("updating player {0} name to {1}", [player_id, name])
	
	var info = player_info.get(player_id)
	if info == null:
		logger.warn("player {0} not found", [player_id])
		return
	
	info["name"] = name


func handle_player_death(player_id: int, aggressor_id: int) -> void:
	logger.trace("handling player {0} death", [player_id])
	
	match state:
		"WaitingForPlayers", "GameAboutToStart":
			_respawn_player(player_id, RESPAWN_SECONDS)
			
		"GameInProgress":
			var aggressor_info = player_info.get(aggressor_id)
			if aggressor_info:
				_announce(Announcer.Announcement.KILL, [aggressor_id])
				aggressor_info.kills += 1
			
			var info = player_info.get(player_id)
			if info:
				_announce(Announcer.Announcement.DEATH, [player_id])
				info.deaths += 1
				_respawn_player(player_id, RESPAWN_SECONDS)
		
		"GameOver":
			pass


func _reset_scores() -> void:
	for info in player_info.values():
		info['kills'] = 0
		info['deaths'] = 0


func _populate_scoreboard() -> void:
	var rows := []
	for info in player_info.values():
		rows.append([info["name"], info["kills"], info["deaths"]])
	
	rows.sort_custom(func(a: Array, b: Array): a[1] > b[1]) 
	
	var labels = ["Player", "Kills", "Deaths"]
	scoreboard.set_data(labels, rows)


func _respawn_player(player_id: int, delay_seconds: float = 0.0) -> void:
	respawn_queue = respawn_queue.filter(func (pair: Array): pair[0] != player_id)
	
	if delay_seconds > 0.0:
		respawn_queue.append([player_id, delay_seconds])
		return
		
	emit_signal("request_respawn", player_id)


func _check_respawn_queue(delta: float):
	if respawn_queue.size() == 0:
		return
	
	for pair in respawn_queue:
		pair[1] -= delta
	
	var expired := respawn_queue.filter(func(pair: Array): return pair[1] <= 0)
	for pair in expired:
		var player_id := pair[0] as int
		_respawn_player(player_id)


func _announce(announcment: Announcer.Announcement, targets: Array) -> void:
	emit_signal("announce", announcment, targets)


func _before_game_start() -> void:
	var players := player_info.keys()
	
	_announce(Announcer.Announcement.PREPARE, players)


func _start_game() -> void:
	var players := player_info.keys()
	
	_announce(Announcer.Announcement.BEGIN, players)
	
	_reset_scores()


func _end_game_message() -> void:
	var players := player_info.keys()
	
	_announce(Announcer.Announcement.GAME_OVER, players)


func _end_game() -> void:
	emit_signal("game_over")
