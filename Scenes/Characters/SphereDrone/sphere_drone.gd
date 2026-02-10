class_name SphereDrone extends CharacterBody3D

@onready var logger := %Logger as Logger
@onready var sync := %MultiplayerSynchronizer as MultiplayerSynchronizer
@onready var observation_cast := %ObservationCast3D as RayCast3D

const PATROL_SPEED = 4.0
const ATTACK_SPEED = 10.0
const ASCEND_SPEED = 2.0
const MIN_ATTACK_DISTANCE = 10.0

enum DroneState {
	PATROL,
	ATTACK,
	HUNT
}

var sync_position_read := true
@export var sync_position: Vector3:
	get:
		sync_position_read = true
		return sync_position
	set(value):
		sync_position_read = false
		sync_position = value

var sync_rotation_read := true
@export var sync_rotation: Vector3:
	get:
		sync_rotation_read = true
		return sync_rotation
	set(value):
		sync_rotation_read = false
		sync_rotation = value

var ts := 0.0
var health := 100
var current_state := DroneState.PATROL
var patrol_path := []
var next_patrol_target: Marker3D
var current_target: Player


func _ready() -> void:
	set_multiplayer_authority(1)
	make_visible_to(get_multiplayer_authority())
	
	Globals.client_removed.connect(_on_client_removed)
	
	for child in find_children("*", "Marker3D", true, false):
		patrol_path.append(child)
	
	if patrol_path.size() > 0:
		next_patrol_target = patrol_path[0]


func _physics_process(delta: float) -> void:
	ts += delta
	
	_read_synced_position()
	_act()
	_update_synced_state()


func _on_observation_timer_timeout() -> void:
	_observe()


func _on_client_removed(client: ConnectedClient) -> void:
	if client.player == null or client.player != current_target:
		return
	
	current_target = null
	if current_state == DroneState.ATTACK:
		_change_state(DroneState.PATROL)


func _change_state(new_state: DroneState) -> void:
	current_state = new_state


const OBSERVATION_SWEEP_ANGLE := deg_to_rad(120)
const OBSERVATION_SWEEP_AXIS_COUNT := 5.
var recent_observations := []
enum ObservationType {
	UNKNOWN = 0,
	LEVEL = 1,
	PLAYER = 2,
}


class Observation:
	var ts: float
	var type: ObservationType
	var global_position: Vector3
	var player: Player


func _observe() -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	
	while recent_observations.size() > 0 and ts - recent_observations[0].ts > 60.:
		recent_observations.pop_front()
	
	var sweep_box_extent := observation_cast.target_position.z * tan(OBSERVATION_SWEEP_ANGLE / 2.0)
	var sweep_box_delta := (sweep_box_extent * 2.0) / OBSERVATION_SWEEP_AXIS_COUNT
	
	for i in range(OBSERVATION_SWEEP_AXIS_COUNT + 1):
		for j in range(OBSERVATION_SWEEP_AXIS_COUNT + 1):
			var x := sweep_box_delta * i - sweep_box_extent
			var y := sweep_box_delta * j - sweep_box_extent
			
			observation_cast.target_position.x = x
			observation_cast.target_position.y = y
			observation_cast.force_raycast_update()
			
			if observation_cast.is_colliding():
				var point := observation_cast.get_collision_point()
				var target := observation_cast.get_collider() as CollisionObject3D
				var type := ObservationType.UNKNOWN
				
				var observation := Observation.new()
				observation.ts = ts
				observation.global_position = point
				
				if target.get_collision_layer_value(1):
					observation.type = ObservationType.PLAYER
					observation.player = target
				elif target.get_collision_layer_value(7):
					observation.type = ObservationType.PLAYER
					observation.player = target
				elif target.get_collision_layer_value(2):
					observation.type = ObservationType.LEVEL
				
				recent_observations.append(observation)
	
	observation_cast.target_position.x = 0
	observation_cast.target_position.y = 0


func _act() -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	
	match current_state:
		DroneState.PATROL:
			_patrol()
		
		DroneState.ATTACK:
			_attack()


func _patrol() -> void:
	for observation in recent_observations:
		if ts - observation.ts > 10.:
			continue
		if observation.type == ObservationType.PLAYER:
			current_target = observation.player
			_change_state(DroneState.ATTACK)
	
	if next_patrol_target == null:
		return
	
	var d := global_position.distance_to(next_patrol_target.global_position)
	if d < 0.1:
		var idx := patrol_path.find(next_patrol_target)
		next_patrol_target = patrol_path[(idx + 1) % patrol_path.size()]
	look_at(next_patrol_target.global_position, Vector3.UP)
	velocity = -transform.basis.z.normalized() * PATROL_SPEED
	
	move_and_slide()


func _attack() -> void:
	var obstacles := []
	for observation in recent_observations:
		if ts - observation.ts > 1.:
			continue
		if observation.type == ObservationType.LEVEL:
			var distance := global_position.distance_to(observation.global_position)
			if distance < 5.:
				obstacles.append(observation.global_position)
	
	if obstacles.size() > 0:
		var middle := Vector3.ZERO
		for obstacle in obstacles:
			middle += obstacle
		middle = middle / obstacles.size()
		var height_offset := global_position.y - middle.y
		if abs(height_offset) < 3.:
			velocity.y = ASCEND_SPEED * sign(height_offset)
			move_and_slide()
			return
	
	var target := Vector3(current_target.global_position)

	var displacement := global_position - target
	var height_offset := global_position.y - target.y
	rotation.y = lerp_angle(rotation.y, atan2(displacement.x, displacement.z), 0.1)
	
	velocity = Vector3.ZERO
	if global_position.distance_to(target) > MIN_ATTACK_DISTANCE:
		velocity = -transform.basis.z.normalized() * ATTACK_SPEED
	if abs(height_offset) > 2.:
		velocity.y = ASCEND_SPEED * sign(height_offset) * -1
	
	move_and_slide()


func _update_synced_state() -> void:
	if not multiplayer.has_multiplayer_peer() or not is_multiplayer_authority():
		return
	
	sync_position = position
	sync_rotation = rotation


func _read_synced_position() -> void:
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		return
	
	if not sync_position_read:
		position = lerp(position, sync_position, 0.9)
	
	if not sync_rotation_read:
		rotation = Vector3(
			lerp_angle(rotation.x, sync_rotation.x, 0.9),
			lerp_angle(rotation.y, sync_rotation.y, 0.9),
			lerp_angle(rotation.z, sync_rotation.z, 0.9)
		)


func make_visible_to(other_id: int) -> void:
	logger.trace("setting visibility for {0}", [other_id])
	
	sync.set_visibility_for(other_id, true)
	sync.update_visibility(other_id)


func apply_damage(damage: int, aggressor_id: int, aggressor_position: Vector3) -> void:
	if not is_multiplayer_authority():
		rpc_id(get_multiplayer_authority(), "_apply_damage", damage, aggressor_id, aggressor_position)


@rpc("any_peer")
func _apply_damage(damage: int, aggressor_id: int, aggressor_position: Vector3) -> void:
	health -= damage
	if health <= 0:
		rpc("_die")
	
	if current_target == null:
		var client = Globals.get_client(aggressor_id)
		if client != null and client.player != null:
			current_target = client.player
			_change_state(DroneState.ATTACK)


@rpc("authority", "call_local")
func _die():
	queue_free()
