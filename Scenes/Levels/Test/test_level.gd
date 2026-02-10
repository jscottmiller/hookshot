class_name TestLevel extends Node3D

@onready var spawn_points := %SpawnPoints
@onready var cameras := %Cameras

var current_camera: PlayerDetectingCamera


func _ready() -> void:
	current_camera = cameras.get_child(0) as PlayerDetectingCamera
	current_camera.current = true


func _on_camera_timer_timeout() -> void:
	if multiplayer.is_server():
		update_server_camera()


func connect_peer(peer_id: int) -> void:
	pass


func choose_spawn_point() -> Vector3:
	var candidates := spawn_points.get_children()
	candidates.shuffle()
	
	var point := candidates[0] as SpawnPoint
	for candidate in candidates:
		var candidate_point := candidate as SpawnPoint
		if candidate_point.occupant_count == 0:
			point = candidate_point
	
	return point.position


func update_server_camera() -> void:
	for child in cameras.get_children():
		var candidate_camera := child as PlayerDetectingCamera
		if candidate_camera.players_in_viewable_area > current_camera.players_in_viewable_area:
			current_camera = candidate_camera
	current_camera.current = true
