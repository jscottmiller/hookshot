class_name Tracer extends Node3D

@onready var mesh := %MeshInstance3D as MeshInstance3D


func set_tracer(start: Vector3, end: Vector3) -> void:
	var midpoint := start + (end - start)/2.0
	var length := start.distance_to(end)
	
	mesh.mesh.height = length
	global_position = midpoint
	look_at(end)


func _on_timer_timeout() -> void:
	queue_free()
