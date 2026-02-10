extends Area3D
class_name SpawnPoint

var occupant_count := 0


func _on_spawn_point_body_entered(_body: PhysicsBody3D):
	occupant_count += 1


func _on_spawn_point_body_exited(_body: PhysicsBody3D):
	occupant_count -= 1
