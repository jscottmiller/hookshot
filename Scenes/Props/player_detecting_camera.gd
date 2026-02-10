class_name PlayerDetectingCamera extends Camera3D

var players_in_viewable_area := 0


func _on_area_3d_body_entered(_body: PhysicsBody3D) -> void:
	players_in_viewable_area += 1


func _on_area_3d_body_exited(_body: PhysicsBody3D) -> void:
	players_in_viewable_area -= 1
