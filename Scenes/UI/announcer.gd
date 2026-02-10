class_name Announcer extends Control

@onready var message_label := %MessageLabel as Label
@onready var countdown_timer := %CountdownTimer as Timer
@onready var animations := %AnimationPlayer as AnimationPlayer

enum Announcement {
	DUEL_INTRO,
	KILL,
	DEATH,
	ROUND_LOST,
	ROUND_WON,
	ROUND_DRAW,
	DUEL_LOST,
	DUEL_WON,
	PREPARE,
	BEGIN,
	GAME_OVER,
}

const MESSAGE_TEXT = {
	Announcement.KILL: "KILL",
	Announcement.DEATH: "DEATH",
	Announcement.ROUND_LOST: "ROUND LOST",
	Announcement.ROUND_WON: "ROUND WON",
	Announcement.ROUND_DRAW: "DRAW",
	Announcement.DUEL_LOST: "DUEL LOST",
	Announcement.DUEL_WON: "DUEL WON",
	Announcement.PREPARE: "PREPARE",
	Announcement.BEGIN: "BEGIN"
}

var announcement_queue := []


func _ready() -> void:
	message_label.hide()


func announce(announcement: Announcement) -> void:
	announcement_queue.append(announcement)
	_check_announcement_queue()


func _check_announcement_queue() -> void:
	if announcement_queue.size() == 0:
		return
	
	if animations.is_playing():
		return
	
	var announcement = announcement_queue.pop_front() as Announcement
	match announcement:
		Announcement.DUEL_INTRO:
			animations.play("duel intro")
		Announcement.KILL:
			animations.play("kill")
		Announcement.DEATH:
			animations.play("death")
		Announcement.ROUND_LOST:
			animations.play("round lost")
		Announcement.ROUND_WON:
			animations.play("round won")
		Announcement.ROUND_DRAW:
			animations.play("round draw")
		Announcement.DUEL_LOST:
			animations.play("duel lost")
		Announcement.DUEL_WON:
			animations.play("duel won")
		Announcement.PREPARE:
			animations.play("prepare")
		Announcement.BEGIN:
			animations.play("begin")
		Announcement.GAME_OVER:
			animations.play("game over")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	_check_announcement_queue()
