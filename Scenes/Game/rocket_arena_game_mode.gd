class_name RocketArenaGameMode extends Node

signal request_respawn
signal enable_player_weapons
signal game_over
signal announce

@onready var logger := %Logger as Logger
@onready var sync := %MultiplayerSynchronizer as MultiplayerSynchronizer
@onready var state_machine := %AnimationTree["parameters/playback"] as AnimationNodeStateMachinePlayback

const MINIMUM_PLAYERS := 2
const TEAM_PLAYERS := 1
const ROUNDS_TO_WIN := 1
const LIVES_PER_ROUND := 2
const RESPAWN_SECONDS := 3.0

enum Team {
	RED,
	BLUE,
	SPECTATOR
}

enum RoundOutcome {
	RED,
	BLUE,
	DRAW
}

@export var player_info := {}
@export var red_wins := 0
@export var blue_wins := 0

var red_members := []
var blue_members := []
var spectator_queue := []
var respawn_queue := []


var state: String:
	get:
		return String(state_machine.get_current_node())


func _process(delta: float) -> void:
	_check_respawn_queue(delta)


func reset() -> void:
	red_wins = 0
	blue_wins = 0
	for player_id in player_info:
		var info = player_info[player_id]
		info.lives = LIVES_PER_ROUND


func register_player(player_id: int, name: String) -> void:
	logger.trace("registering player {0}", [player_id])
	
	if player_id in player_info:
		logger.warn("player {0} already registered", [player_id])
		return
	
	sync.set_visibility_for(player_id, true)
	sync.update_visibility()
	
	var team := _assign_team(player_id)
	
	player_info[player_id] = {
		"name": name,
		"kills": 0,
		"deaths": 0,
		"lives": LIVES_PER_ROUND,
		"team": team,
	}
	
	if team != Team.SPECTATOR:
		_respawn_player(player_id)
	
	var total_players := red_members.size() + blue_members.size()
	if total_players == TEAM_PLAYERS * 2:
		state_machine.travel("Intro")
	elif state == "WaitingForPlayers" and total_players == MINIMUM_PLAYERS:
		state_machine.travel("MinimumPlayersMet")


func disconnect_player(player_id: int) -> void:
	logger.trace("unregistering player {0}", [player_id])
	
	var info = player_info.get(player_id)
	if info == null:
		return
	
	player_info.erase(player_id)
	
	match info.team:
		Team.RED:
			red_members.erase(player_id)
		Team.BLUE:
			blue_members.erase(player_id)
		Team.SPECTATOR:
			spectator_queue.erase(player_id)
	
	var total_players := red_members.size() + blue_members.size()
	if state == "MinimumPlayersMet" and total_players == 1:
		state_machine.travel("WaitingForPlayers")
	
	_maybe_balance_teams()
	_maybe_end_game()


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
		"Intro", "WaitingForPlayers", "MinimumPlayersMet", "WaitingForRoundToStart":
			_respawn_player(player_id, RESPAWN_SECONDS)
			
		"RoundInProgress":
			var aggressor_info = player_info.get(aggressor_id)
			if aggressor_info:
				_announce(Announcer.Announcement.KILL, [aggressor_id])
				aggressor_info.kills += 1
			
			var info = player_info.get(player_id)
			if info:
				_announce(Announcer.Announcement.DEATH, [player_id])
				info.deaths += 1
				info.lives -= 1
				if info.lives > 0:
					_respawn_player(player_id, RESPAWN_SECONDS)
			
			_maybe_end_round()
		
		"RoundComplete", "GameComplete":
			pass


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


func _assign_team(player_id: int) -> int:
	var team := Team.SPECTATOR

	var accepting_players = (
		(state == "WaitingForPlayers" or state == "MinimumPlayersMet") and
		(red_members.size() != TEAM_PLAYERS or blue_members.size() != TEAM_PLAYERS)
	)
	
	if accepting_players:
		if red_members.size() < blue_members.size():
			team = Team.RED
		elif blue_members.size() < red_members.size():
			team = Team.BLUE
		elif randi_range(0, 1) == 0:
			team = Team.BLUE
		else:
			team = Team.RED
	
	match team:
		Team.RED:
			red_members.append(player_id)
		Team.BLUE:
			blue_members.append(player_id)
		Team.SPECTATOR:
			spectator_queue.append(player_id)
	
	return team


func _maybe_balance_teams() -> void:	
	var total_players := red_members.size() + blue_members.size()
	if total_players == TEAM_PLAYERS * 2:
		return
	
	while spectator_queue.size() > 0 and total_players < TEAM_PLAYERS * 2:
		var next = spectator_queue.pop_front()
		var info = player_info.get(next)
		if info == null:
			continue
		
		info.team = _assign_team(next)
		_respawn_player(next)
		total_players += 1
	
	var red_blue_difference = red_members.size() - blue_members.size()
	if abs(red_blue_difference) > 1:
		var smaller_team := Team.BLUE
		var larger_membership := red_members
		var smaller_membership := blue_members
		if red_blue_difference < 0:
			smaller_team = Team.RED
			larger_membership = blue_members
			smaller_membership = red_members
		
		var changes_to_make = abs(red_blue_difference) - 1
		while changes_to_make:
			var to_move = larger_membership.pop_back()
			var info = player_info.get(to_move)
			if not info:
				continue
			
			smaller_membership.append(to_move)
			info.team = smaller_team
			_respawn_player(to_move)
			changes_to_make -= 1


func _respawn_player(player_id: int, delay_seconds: float = 0.0) -> void:
	respawn_queue = respawn_queue.filter(func (pair: Array): pair[0] != player_id)
	
	if delay_seconds > 0.0:
		respawn_queue.append([player_id, delay_seconds])
		return
		
	emit_signal("request_respawn", player_id)


func _disable_player_weapons() -> void:
	emit_signal("enable_player_weapons", false)


func _enable_player_weapons() -> void:
	emit_signal("enable_player_weapons", true)


func _intro() -> void:
	logger.trace("running intro")
	
	_announce(Announcer.Announcement.DUEL_INTRO, red_members + blue_members)


func _start_round_countdown() -> void:
	logger.trace("starting round countdown")
	
	_announce(Announcer.Announcement.PREPARE, red_members + blue_members)
	
	for player_id in red_members:
		_respawn_player(player_id)
	for player_id in blue_members:
		_respawn_player(player_id)
	_disable_player_weapons()
	
	for player_id in player_info:
		var info = player_info[player_id]
		info.lives = LIVES_PER_ROUND
	
	state_machine.travel("WaitingForRoundToStart")


func _start_round() -> void:
	logger.trace("starting round")
	
	_announce(Announcer.Announcement.BEGIN, red_members + blue_members)
	
	_enable_player_weapons()
	
	state_machine.travel("RoundInProgress")


func _maybe_end_game() -> void:
	if player_info.size() >= 2:
		_maybe_end_round()
		return
	
	_end_game()


func _maybe_end_round() -> void:
	var red_alive_players := 0
	var blue_alive_players := 0
	for player_id in player_info:
		var info = player_info[player_id]
		if info.lives == 0:
			continue
		match info.team:
			Team.RED:
				red_alive_players += 1
			Team.BLUE:
				blue_alive_players += 1
	
	if red_alive_players > 0 and blue_alive_players > 0:
		return
	
	_end_round()


func _end_round() -> void:
	logger.trace("ending round")
	
	var red_players := 0
	var blue_players := 0
	for player_id in player_info:
		var info = player_info[player_id]
		if info.lives == 0:
			continue
		if info.team == Team.RED:
			red_players += 1
		elif info.team == Team.BLUE:
			blue_players += 1
	
	var outcome := RoundOutcome.DRAW
	if red_players > blue_players:
		outcome = RoundOutcome.RED
		red_wins += 1
	elif blue_players > red_players:
		outcome = RoundOutcome.BLUE
		blue_wins += 1
	
	if red_wins >= ROUNDS_TO_WIN or blue_wins >= ROUNDS_TO_WIN:
		_on_game_complete(outcome)
	else:
		_on_round_over(outcome)


func _on_game_complete(outcome: RoundOutcome) -> void:
	logger.trace("game over")
	
	if outcome == RoundOutcome.RED:
		_announce(Announcer.Announcement.DUEL_WON, red_members)
		_announce(Announcer.Announcement.DUEL_LOST, blue_members)
	elif outcome == RoundOutcome.BLUE:
		_announce(Announcer.Announcement.DUEL_WON, blue_members)
		_announce(Announcer.Announcement.DUEL_LOST, red_members)
	
	state_machine.travel("GameComplete")


func _on_round_over(outcome: RoundOutcome) -> void:
	logger.trace("round over")
	
	if outcome == RoundOutcome.RED:
		_announce(Announcer.Announcement.ROUND_WON, red_members)
		_announce(Announcer.Announcement.ROUND_LOST, blue_members)
	elif outcome == RoundOutcome.BLUE:
		_announce(Announcer.Announcement.ROUND_WON, blue_members)
		_announce(Announcer.Announcement.ROUND_LOST, red_members)
	else:
		_announce(Announcer.Announcement.ROUND_DRAW, red_members + blue_members)
	
	state_machine.travel("RoundComplete")


func _end_game() -> void:
	emit_signal("game_over")
