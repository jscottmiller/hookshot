class_name RocketExplosion extends Area3D

@export var blast_radius := 8.0

var owning_player_id: int
var owning_player_location: Vector3


func _on_body_entered(body: PhysicsBody3D) -> void:
	if body.has_method("apply_damaging_force"):
		body.apply_damaging_force(global_position, blast_radius, owning_player_id, owning_player_location)


func _on_lifetime_timer_timeout() -> void:
	queue_free()
