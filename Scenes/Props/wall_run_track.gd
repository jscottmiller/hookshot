extends Area3D
class_name WallRunTrack


func _on_wall_run_track_body_entered(body: PhysicsBody3D) -> void:
	var player := body as Player
	if not player:
		return
	
	player.begin_wall_run(self)


func _on_wall_run_track_body_exited(body: PhysicsBody3D) -> void:
	var player := body as Player
	if not player:
		return
	
	player.end_wall_run(self)
