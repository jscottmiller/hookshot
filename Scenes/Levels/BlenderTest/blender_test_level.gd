class_name BlenderTestLevel extends Node3D

@onready var entities := %Entities
@onready var spawn_points := %SpawnPoints


func _ready() -> void:
	set_multiplayer_authority(1)


func _sync_entities() -> void:
	var live_entities: PackedStringArray = []
	for entity in entities.get_children():
		live_entities.append(entity.name)
	
	rpc("update_live_entities", live_entities)


@rpc
func update_live_entities(live_entities: PackedStringArray) -> void:
	for entity in entities.get_children():
		if live_entities.find(entity.name) == -1:
			entity.queue_free()


func choose_spawn_point() -> Vector3:
	var candidates := spawn_points.get_children()
	candidates.shuffle()
	
	var point := candidates[0] as SpawnPoint
	for candidate in candidates:
		var candidate_point := candidate as SpawnPoint
		if candidate_point.occupant_count == 0:
			point = candidate_point
	
	return point.position


func connect_peer(peer_id: int) -> void:
	if not is_multiplayer_authority():
		return
	
	for child in entities.get_children():
		child.make_visible_to(peer_id)
	
	_sync_entities()


func _on_entity_sync_timer_timeout() -> void:
	_sync_entities()
