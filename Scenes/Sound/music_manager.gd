class_name MusicManager extends Node

@onready var tracks := %Tracks

const VOLUME_DB := -15
const FADE_SECONDS := 1.

var current_track: AudioStreamPlayer


var enabled: bool:
	get:
		return enabled
	set(value):
		enabled = value
		if !enabled:
			_stop_all_music()


func play_track(name: String) -> void:
	if !enabled:
		return
	
	if current_track != null:
		var tween := get_tree().create_tween()
		tween.tween_property(current_track, "volume_db", -80, FADE_SECONDS)
		tween.tween_callback(current_track.stop)
	
	for track in tracks.get_children():
		var player := track as AudioStreamPlayer
		if player.name != name:
			continue
		current_track = player
		current_track.play()
		current_track.volume_db = -80
		var tween := get_tree().create_tween()
		tween.tween_property(current_track, "volume_db", VOLUME_DB, FADE_SECONDS)


func _stop_all_music() -> void:
	for track in tracks.get_children():
		var player := track as AudioStreamPlayer
		player.stop()
