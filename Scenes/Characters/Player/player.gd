class_name Player extends CharacterBody3D

@onready var logger := %Logger as Logger
@onready var name_label := %NameLabel as Label3D
@onready var camera := %Camera3d as Camera3D
@onready var view_container := %ViewContainer
@onready var ui := %UI as CanvasLayer
@onready var ui_animations := %UIAnimationPlayer as AnimationPlayer
@onready var left_damage_ui := %LeftDamage
@onready var right_damage_ui := %RightDamage
@onready var firing_cast := %FiringCast as RayCast3D
@onready var grapple_cast := %GrappleCast as RayCast3D
@onready var grapple_source := %GrappleSource as Marker3D
@onready var right_hand_marker := %RightHandMarker as Marker3D
@onready var grapple_check_cast := %GrappleCheckCast as RayCast3D
@onready var camera_position := %CameraPosition as Marker3D
@onready var rope_template := %RopeTemplate as Node3D
@onready var rope_segments := %RopeSegments
@onready var current_target_marker := %CurrentTargetMarker
@onready var sync := %MultiplayerSynchronizer as MultiplayerSynchronizer
@onready var animation_tree := %AnimationTree as AnimationTree
@onready var grapple_marker := %GrappleMarker as Marker3D
@onready var grapple_ik := %GrappleSkeletonIk3D as SkeletonIK3D
@onready var target_marker := %TargetMarker as Marker3D
@onready var target_ik := %TargetSkeletonIk3D as SkeletonIK3D
@onready var rifle_trigger_ik := %RifleTriggerSkeletonIk3D as SkeletonIK3D
@onready var rifle_stablizing_ik := %RifleStabilizingSkeletonIk3D as SkeletonIK3D
@onready var health_display := %HealthValue as Label
@onready var ammo_display := %AmmoValue as Label
@onready var speed_display := %SpeedValue as Label
@onready var thrust_display := %ThrustValue as Label
@onready var rifle := %Rifle as Node3D
@onready var one_handed_rifle_container := %OneHandedRifleContainer as Node3D
@onready var shouldered_rifle_container := %ShoulderedRifleContainer as Node3D
@onready var shouldered_rifle_pivot := %ShoulderedRiflePivot as Node3D
@onready var rocket_launcher := %RocketLauncher as Node3D
@onready var freeze_timer := %FreezeTimer as Timer
@onready var freeze_recharge_timer := %FreezeRechargeTimer as Timer
@onready var grapple_success_sound := %GrappleSuccessSound as AudioStreamPlayer3D
@onready var thrust_sound := %ThrustSound as AudioStreamPlayer3D
@onready var wind_sound := %WindSound as AudioStreamPlayer
@onready var freeze_sound := %FreezeSound as AudioStreamPlayer
@onready var crosshair := %Crosshair as Sprite2D

const SPEED := 20.0
const FROZEN_SPEED := 4.0
const AIR_ACCELERATION := 30.0
const AIR_DAMPING := 0.25
const EXTERNAL_IMPULSE_DAMPING := 0.05
const JUMP_SPEED := 12.0
const THRUST_SPEED := 25.0
const MAX_THRUSTS := 4
const THRUST_UP_BIAS := 0.35
const MAX_SPEED := 65.0
const WALL_RUN_SPEED := 6.0
const MINIMUM_WALL_RUN_SPEED = 4.0
const MAX_CAMERA_ROTATION = deg_to_rad(10.0)
const BOOST_JUMP_MULTIPLIER := 1.5
const DAMAGE_MULTIPLIER := 40.0
const IMPULSE_MULTIPLIER := 100.0
const MOUSE_SENSITIVITY = 300.0
const JOYSTICK_SENSITIVITY = 20.0
const GRAVITY := 25.0
const GRAPPLE_RETRACT_SPEED := 18.0
const MINIMUM_GRAPPLE_LENGTH := 1.0
const MAXIMUM_GRAPPLE_LENGTH := 150.0
const GRAPPLE_LENGTH_FUDGE_FACTOR := 1.0
const OCCLUDED_GRAPPLE_OFFSET = 0.25
const DEATH_PLANE_HEIGHT = -200.0
const RUN_BLEND_SPEED = 3.0
const FALL_SWING_BLEND_SPEED = 2.0
const FALL_DIRECTION_BLEND_SPEED = 2.0
const IN_AIR_BLEND_SPEED = 2.0
const CROSSHAIR_GRAPPLE_COLOR := Color.DARK_GREEN
const CROSSHAIR_ENEMY_COLOR := Color.DARK_RED
const CROSSHAIR_DEFAULT_COLOR := Color.BLACK
const FIRING_SWEEP_AXIS_COUNT := 5.0
const FIRING_SWEEP_ANGLE := deg_to_rad(5.0)

enum Weapons {
	ROCKET_LAUNCHER,
	RIFLE
}

@export var health := 100
@export var current_weapon := Weapons.RIFLE
@export var in_grapple := false
@export var grapple_targets: PackedVector3Array
@export var grapple_lengths: PackedFloat64Array
@export var grapple_plane_normals: PackedVector3Array
@export var grapple_plane_points: PackedVector3Array
@export var wall_run_count := 0
@export var wall_run_direction: Vector3
@export var motion: Vector3
@export var external_impulse: Vector3
@export var in_freeze: bool
@export var frozen_velocity: Vector3
@export var shield_active: bool

var head_motion_read := true
@export var head_motion: Vector2:
	get:
		head_motion_read = true
		return head_motion
	set(value):
		head_motion_read = false
		head_motion = value

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

var active := true
var player_name := "anonymous"
var inputs_enabled := true
var weapons_enabled := true
var thrusts_available := MAX_THRUSTS
var mouse_motion_since_last_frame: Vector2
var run_blend_amount := 0.0
var fall_swing_blend_amount := 0.0
var fall_direction_blend_amount := 0.0
var in_air_blend_amount := 0.0
var last_aggressor_id: int
var can_freeze := true
var end_freeze := false
var zoom_tween: Tween
var camera_rotate_tween: Tween

var weapon: Node3D:
	get:
		match current_weapon:
			Weapons.RIFLE:
				return rifle
			
			Weapons.ROCKET_LAUNCHER:
				return rocket_launcher
		
		return null


func _ready() -> void:
	logger.trace("init for {0}", [player_name])
	
	make_visible_to(1)
	name_label.text = player_name
	
	ui.visible = is_multiplayer_authority()
	if is_multiplayer_authority():
		ui.visible = true
		camera.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		name_label.hide()
	else:
		ui.visible = false
		collision_layer &= ~1
		collision_layer |= 64
	
	left_damage_ui.hide()
	right_damage_ui.hide()
	
	animation_tree.active = true
	
	rifle.activate()
	rocket_launcher.deactivate()


func _physics_process(delta: float) -> void:
	_check_death_plane()
	
	_update_inputs()
	_read_synced_position()
	_process_inputs()
	_update_synced_state()
	
	_move(delta)
	
	_update_camera()
	_update_target()
	_update_rope_segments()
	
	_animate(delta)
	_paint_crosshair()
	_add_wind_sound()
	_update_ui()


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			disable_inputs()
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			enable_inputs()
	
	if not inputs_enabled:
		return
	
	var mouse_event := event as InputEventMouseMotion
	if mouse_event:
		mouse_motion_since_last_frame.x += mouse_event.relative.x
		mouse_motion_since_last_frame.y += mouse_event.relative.y
	
	if Input.is_action_just_pressed("switch_weapon"):
		weapon.deactivate()
		match current_weapon:
			Weapons.RIFLE:
				current_weapon = Weapons.ROCKET_LAUNCHER
			Weapons.ROCKET_LAUNCHER:
				current_weapon = Weapons.RIFLE
		weapon.activate()
	
	if Input.is_action_just_pressed("zoom"):
		if zoom_tween:
			zoom_tween.kill()
			zoom_tween = null
		zoom_tween = get_tree().create_tween()
		zoom_tween.tween_property(camera, "fov", 25, 0.2)
	elif Input.is_action_just_released("zoom"):
		if zoom_tween:
			zoom_tween.kill()
			zoom_tween = null
		zoom_tween = get_tree().create_tween()
		zoom_tween.tween_property(camera, "fov", 80, 0.2)


func make_visible_to(other_id: int) -> void:
	sync.set_visibility_for(other_id, true)
	sync.update_visibility(other_id)


func set_player_name(name: String) -> void:
	logger.trace("setting name to {0}", [player_name])
	player_name = name
	if name_label:
		name_label.text = name


func disable_inputs() -> void:
	inputs_enabled = false


func enable_inputs() -> void:
	inputs_enabled = true


func set_weapons_enabled(enabled: bool) -> void:
	weapons_enabled = enabled


func begin_wall_run(track: WallRunTrack) -> void:
	var current_speed := velocity.length()
	if current_speed < MINIMUM_WALL_RUN_SPEED:
		return
	
	wall_run_direction = (
		track.transform.basis.z
			.rotated(Vector3.RIGHT, track.global_rotation.x)
			.rotated(Vector3.UP, track.global_rotation.y)
	)
	wall_run_count += 1


func end_wall_run(_track: WallRunTrack) -> void:
	wall_run_count = max(wall_run_count - 1, 0)


func apply_damage(damage: int, aggressor_id: int, aggressor_position: Vector3) -> void:
	if aggressor_id == multiplayer.get_unique_id():
		rpc_id(get_multiplayer_authority(), "update_health", -damage, aggressor_id, aggressor_position)


func apply_damaging_force(source: Vector3, radius: float, aggressor_id: int, aggressor_position: Vector3) -> void:
	logger.trace("applying damage from {0}", [aggressor_id])
	
	var distance := global_position.distance_to(source)
	var direction := global_position - source
	
	var falloff := 1 - minf(distance / radius, 1)
	
	external_impulse += direction.normalized() * falloff * IMPULSE_MULTIPLIER
	
	if aggressor_id == multiplayer.get_unique_id():
		var damage := int(falloff * DAMAGE_MULTIPLIER)
		rpc_id(get_multiplayer_authority(), "update_health", -damage, aggressor_id, aggressor_position)


@rpc("any_peer", "call_local")
func update_health(delta: int, aggressor_id: int = -1, aggressor_position: Vector3 = Vector3.ZERO) -> void:
	if aggressor_id != -1:
		var forward := -global_transform.basis.z
		var dot := forward.dot(to_local(aggressor_position))
		if dot > 0:
			ui_animations.play("HurtLeft")
		else:
			ui_animations.play("HurtRight")
	
	health = clamp(health + delta, 0, 100)
	health_display.text = str(health)
	if aggressor_id != -1:
		last_aggressor_id = aggressor_id
	if health == 0:
		_set_inactive_and_emit_death(true)


func _on_freeze_timer_timeout() -> void:
	_end_freeze()


func _on_freeze_recharge_timer_timeout() -> void:
	can_freeze = true


func _on_thrust_recharge_timer_timeout() -> void:
	if thrusts_available < MAX_THRUSTS:
		thrusts_available += 1


func _on_rifle_ammo_change(ammo: int) -> void:
	ammo_display.text = str(ammo)


func _on_rocket_launcher_ammo_change(ammo: int) -> void:
	ammo_display.text = str(ammo)


func _check_death_plane() -> void:
	if position.y > DEATH_PLANE_HEIGHT:
		return
	_set_inactive_and_emit_death(false)


func _set_inactive_and_emit_death(was_kill: bool) -> void:
	if not is_multiplayer_authority():
		return
	
	if not active:
		return
	active = false
	
	var aggressor_id := -1
	if was_kill and last_aggressor_id != get_multiplayer_authority():
		aggressor_id = last_aggressor_id
	
	get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, "Game", "player_died", get_multiplayer_authority(), aggressor_id)


func _update_inputs() -> void:
	if not is_multiplayer_authority() or not inputs_enabled:
		return
	
	var motion_direction := Input.get_vector("strafe_left", "strafe_right", "forward", "backward")
	motion = Vector3(motion_direction.x, 0, motion_direction.y)
	
	head_motion = Vector2.ZERO
	
	var stick_direction := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var stick_fov_adjust = 1 / (camera.fov / 80)
	head_motion += Vector2(
		stick_direction.x / (JOYSTICK_SENSITIVITY * stick_fov_adjust),
		stick_direction.y / (JOYSTICK_SENSITIVITY * stick_fov_adjust)
	)
	
	var mouse_fov_adjust = 1 / (camera.fov / 80)
	head_motion += Vector2(
		mouse_motion_since_last_frame.x / (MOUSE_SENSITIVITY * mouse_fov_adjust),
		mouse_motion_since_last_frame.y / (MOUSE_SENSITIVITY * mouse_fov_adjust)
	)
	mouse_motion_since_last_frame = Vector2.ZERO
	
	if Input.is_action_just_pressed("grapple_fire"):
		if in_grapple:
			_release_grappling_hook()
		else:
			_fire_grappling_hook()
	
	if weapons_enabled:
		var reload_pressed := Input.is_action_just_pressed("reload")
		var weapon_fired := Input.is_action_pressed("fire")
		if reload_pressed:
			weapon.reload()
		elif weapon_fired:
			_fire_weapon()
	
	var freeze_activated := Input.is_action_just_pressed("freeze")
	if freeze_activated:
		if in_freeze:
			_end_freeze()
		elif can_freeze:
			_start_freeze()
	
	var shield_activated := Input.is_action_just_pressed("use_shield")
	if shield_activated:
		if shield_active:
			_end_shield()
		else:
			_start_shield()


func _fire_grappling_hook() -> void:
	var target := grapple_cast.get_collider() as CollisionObject3D
	
	# 3 is the grapple layer
	if not target or not target.get_collision_layer_value(3):
		return
	
	rpc("play_grapple_success_sound")
	
	var target_point := grapple_cast.get_collision_point()
	var target_distance := grapple_cast.global_position.distance_to(target_point)
	grapple_targets.append(target_point)
	grapple_lengths.append(target_distance + GRAPPLE_LENGTH_FUDGE_FACTOR)
	current_target_marker.show()
	in_grapple = true


func _fire_weapon() -> void:
	var kick: Vector2 = weapon.fire(velocity, in_grapple, target_marker.global_position, multiplayer.get_unique_id())
	
	head_motion += kick


func _release_grappling_hook() -> void:
	if not in_grapple:
		return
	
	grapple_targets.clear()
	grapple_lengths.clear()
	grapple_plane_normals.clear()
	grapple_plane_points.clear()
	current_target_marker.hide()
	in_grapple = false


func _start_freeze() -> void:
	if not can_freeze:
		return
	
	in_freeze = true
	can_freeze = false
	freeze_timer.start()
	freeze_recharge_timer.start()
	
	freeze_sound.play()
	var bus_idx := AudioServer.get_bus_index("InWorldSound")
	AudioServer.set_bus_effect_enabled(bus_idx, 0, true)


func _end_freeze() -> void:
	if not in_freeze:
		return
	
	end_freeze = true


func _finish_freeze() -> void:
	if not (in_freeze and end_freeze):
		return
	
	velocity = frozen_velocity
	in_freeze = false
	end_freeze = false
	
	freeze_sound.stop()
	var bus_idx := AudioServer.get_bus_index("InWorldSound")
	AudioServer.set_bus_effect_enabled(bus_idx, 0, false)


func _start_shield() -> void:
	pass


func _end_shield() -> void:
	pass


func _process_inputs() -> void:
	if not head_motion_read:
		rotation += Vector3(0, -head_motion.x, 0)
		camera.rotation.x = clamp(camera.rotation.x - head_motion.y, -PI/2, PI/2)


func _update_synced_state() -> void:
	if not is_multiplayer_authority():
		return
	
	sync_position = position
	sync_rotation = rotation


func _read_synced_position() -> void:
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		return
	
	if not sync_position_read:
		position = lerp(position, sync_position, 0.8)
	
	if not sync_rotation_read:
		rotation = Vector3(
			lerp_angle(rotation.x, sync_rotation.x, 0.8),
			lerp_angle(rotation.y, sync_rotation.y, 0.8),
			lerp_angle(rotation.z, sync_rotation.z, 0.8)
		)


func _move(delta: float) -> void:
	_apply_gravity_and_jump(delta)
	if not in_grapple:
		_apply_movement(delta)
	else:
		_check_grapple_occlusion()
		_apply_grapple_movement(delta)
		_apply_grapple_constraints(delta)
	move_and_slide()


func _animate(delta: float) -> void:
	_set_blend_weights(delta)
	_pose_arms()


func _paint_crosshair() -> void:
	var target := grapple_cast.get_collider() as CollisionObject3D
	if target and target.get_collision_layer_value(3):
		crosshair.self_modulate = CROSSHAIR_GRAPPLE_COLOR
	else:
		crosshair.self_modulate = CROSSHAIR_DEFAULT_COLOR


func _add_wind_sound() -> void:
	if is_on_floor():
		wind_sound.volume_db = lerp(wind_sound.volume_db, -80., 0.1)
		return
	
	var speed := velocity.length()
	var frac := speed / MAX_SPEED
	
	# Maximum wind volume is -5db
	var volume_db := -80. + frac * 75
	
	wind_sound.volume_db = lerp(wind_sound.volume_db, volume_db, 0.1)


func _update_ui() -> void:
	var speed := int(velocity.length())
	speed_display.text = str(speed)
	thrust_display.text = str(thrusts_available)


func _set_blend_weights(delta: float) -> void:
	var run_delta := RUN_BLEND_SPEED * delta if velocity.length() else -RUN_BLEND_SPEED * delta
	var fall_swing_delta := FALL_SWING_BLEND_SPEED * delta if in_grapple else -FALL_SWING_BLEND_SPEED * delta
	var in_air_delta := IN_AIR_BLEND_SPEED * delta if !is_on_floor() else -IN_AIR_BLEND_SPEED * delta
	
	var falling_direction_delta := 0.0
	var forward_velocity := velocity.dot(-transform.basis.z)
	if forward_velocity < 5:
		pass
	elif forward_velocity > 0:
		falling_direction_delta = FALL_DIRECTION_BLEND_SPEED * delta
	elif forward_velocity < 0:
		falling_direction_delta = -FALL_DIRECTION_BLEND_SPEED * delta
	
	run_blend_amount = clampf(run_blend_amount + run_delta, 0, 1)
	fall_swing_blend_amount = clampf(fall_swing_blend_amount + fall_swing_delta, 0, 1)
	in_air_blend_amount = clampf(in_air_blend_amount + in_air_delta, 0, 1)
	fall_direction_blend_amount = move_toward(fall_direction_blend_amount, forward_velocity/MAX_SPEED, FALL_DIRECTION_BLEND_SPEED * delta)
	
	animation_tree.set("parameters/RunBlend/blend_amount", run_blend_amount)
	animation_tree.set("parameters/InAirBlend/blend_amount", in_air_blend_amount)
	
	var fall_swing_blend := Vector2(fall_direction_blend_amount, fall_swing_blend_amount)
	animation_tree.set("parameters/FallSwingSpace/blend_position", fall_swing_blend)


func _pose_arms() -> void:
	_pose_grappling_hook()
	_pose_weapons()


func _pose_grappling_hook() -> void:
	if in_grapple:
		if not grapple_ik.is_running():
			grapple_ik.start()
		var last_point := grapple_targets[grapple_targets.size() - 1]
		grapple_marker.global_position = last_point
	elif !in_grapple and grapple_ik.is_running():
		grapple_ik.stop()


func _pose_weapons() -> void:
	match current_weapon:
		Weapons.RIFLE:
			rocket_launcher.hide()
			rifle.show()
			if in_grapple:
				if rifle.get_parent() == shouldered_rifle_container:
					shouldered_rifle_container.remove_child(rifle)
					one_handed_rifle_container.add_child(rifle)
				_pose_weapon_arm_toward_target()
			else:
				if rifle.get_parent() == one_handed_rifle_container:
					one_handed_rifle_container.remove_child(rifle)
					shouldered_rifle_container.add_child(rifle)
				_pose_shouldered_rifle()
		
		Weapons.ROCKET_LAUNCHER:
			rifle.hide()
			rocket_launcher.show()
			_pose_weapon_arm_toward_target()


func _pose_weapon_arm_toward_target() -> void:
	_set_ik(rifle_trigger_ik, false)
	_set_ik(rifle_stablizing_ik, false)
	_set_ik(target_ik, true)
	
	var skeleton := $RobotModel/Armature/Skeleton3D as Skeleton3D
	var idx := skeleton.find_bone("Hand.R")
	var hand_rotation := skeleton.get_bone_pose_rotation(idx)
	#right_hand_marker.look_at(target_marker.global_position)
	target_marker.look_at(right_hand_marker.global_position, Vector3.UP, true)
	target_marker.rotation.x -= PI/2
	#target_marker.look_at(global_position)
	#target_marker.global_rotation = skeleton.global_transform.inverse() * target_marker.global_rotation


func _pose_shouldered_rifle() -> void:
	_set_ik(rifle_trigger_ik, true)
	_set_ik(rifle_stablizing_ik, true)
	_set_ik(target_ik, false)
	
	shouldered_rifle_pivot.look_at(target_marker.global_position)


func _set_ik(ik: SkeletonIK3D, enabled: bool) -> void:
	if enabled and not ik.is_running():
		ik.start()
	elif not enabled and ik.is_running():
		ik.stop()


func _apply_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	if is_multiplayer_authority() and inputs_enabled and Input.is_action_just_pressed("jump"):
		if is_on_floor() or wall_run_count > 0:
			velocity.y = JUMP_SPEED
			wall_run_count = 0
		elif thrusts_available > 0:
			var biased_input_direction := motion + Vector3(0, THRUST_UP_BIAS, 0)
			var thrust_direction := (transform.basis * biased_input_direction).normalized()
			var existing_contribution := maxf(velocity.dot(thrust_direction), 0)
			velocity = thrust_direction * (THRUST_SPEED + existing_contribution)
			rpc("play_thrust_sound")
			thrusts_available -= 1
			wall_run_count = 0
	
	var speed := velocity.length()
	if speed > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED


func _apply_movement(delta: float) -> void:
	if in_freeze:
		_apply_frozen_movement()
	elif is_on_floor():
		_apply_ground_movement(delta)
	else:
		_apply_air_movement(delta)
	
	if not in_freeze:
		frozen_velocity = velocity


func _apply_frozen_movement() -> void:
	if end_freeze:
		_finish_freeze()
	else:
		velocity = frozen_velocity.normalized() * FROZEN_SPEED


func _apply_ground_movement(delta: float) -> void:
	external_impulse = Vector3.ZERO
	var direction = (transform.basis * motion).normalized()
	if direction:
		velocity.x = direction.x * SPEED * max(run_blend_amount, 0.1)
		velocity.z = direction.z * SPEED * max(run_blend_amount, 0.1)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)


func _apply_air_movement(delta: float) -> void:
	var direction = (transform.basis * motion).normalized()
	if direction and wall_run_count > 0:
		var orientation := signf(velocity.dot(wall_run_direction))
		velocity = wall_run_direction * orientation * WALL_RUN_SPEED
	
	if direction:
		velocity.x += direction.x * AIR_ACCELERATION * delta
		velocity.z += direction.z * AIR_ACCELERATION * delta
	
	velocity.x -= velocity.x * AIR_DAMPING * delta
	velocity.y -= velocity.y * AIR_DAMPING * delta
	
	velocity += external_impulse * delta
	external_impulse = lerp(external_impulse, Vector3.ZERO, EXTERNAL_IMPULSE_DAMPING)


func _check_grapple_occlusion() -> void:
	var current_target := grapple_targets[grapple_targets.size() - 1]
	current_target_marker.position = current_target
	
	if not in_grapple:
		return
	
	while grapple_targets.size() >= 2:
		var last_index := grapple_targets.size() - 1
		var current_plane_normal := grapple_plane_normals[last_index - 1]
		var current_plane_point := grapple_plane_points[last_index - 1]
		var current_plane := Plane(current_plane_normal, current_plane_point)
		var distance := current_plane.distance_to(firing_cast.global_position)
		
		if distance >= 0:
			break
		
		var current_length := grapple_lengths[last_index]
		grapple_lengths[last_index - 1] += current_length
		
		grapple_targets.remove_at(last_index)
		grapple_lengths.remove_at(last_index)
		grapple_plane_normals.remove_at(last_index - 1)
		grapple_plane_points.remove_at(last_index - 1)
		
		var previous_target := grapple_targets[last_index - 1]
		current_target = previous_target
	
	grapple_check_cast.look_at(current_target)
	grapple_check_cast.force_raycast_update()
	
	if not grapple_check_cast.is_colliding():
		return
	
	var candidate_target := grapple_check_cast.get_collision_point()
	var candidate_offset = candidate_target.distance_to(current_target)
	
	if candidate_offset > OCCLUDED_GRAPPLE_OFFSET:
		var rope_direction := candidate_target - current_target
		var grapple_sphere_normal := rope_direction.normalized()
		var sphere_surface_plane := Plane(grapple_sphere_normal)
		var plane_normal := sphere_surface_plane.project(velocity)
		var plane_point := firing_cast.global_position
		
		var rope_segment_length := firing_cast.global_position.distance_to(candidate_target)
		var current_index := grapple_lengths.size() - 1
		
		if rope_segment_length > grapple_lengths[current_index]:
			return
		
		if rope_segment_length < MINIMUM_GRAPPLE_LENGTH:
			return
		
		grapple_lengths[current_index] -= rope_segment_length
		grapple_targets.append(candidate_target)
		grapple_plane_normals.append(plane_normal)
		grapple_plane_points.append(plane_point)
		grapple_lengths.append(rope_segment_length)


func _apply_grapple_movement(delta: float) -> void:
	if in_freeze:
		_apply_frozen_movement()
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	elif motion.z:
		var last_index := grapple_lengths.size() - 1
		var current_value := grapple_lengths[last_index]
		var change :=  GRAPPLE_RETRACT_SPEED * delta * motion.z
		var remaining := MAXIMUM_GRAPPLE_LENGTH
		for i in range(last_index):
			remaining -= grapple_lengths[i]
		var new_value := clampf(current_value + change, MINIMUM_GRAPPLE_LENGTH, remaining)
		grapple_lengths[last_index] = new_value
	
	if not in_freeze:
		frozen_velocity = velocity


func _apply_grapple_constraints(delta: float) -> void:
	var grapple_origin := firing_cast.global_position
	var grapple_target := grapple_targets[grapple_targets.size() - 1]
	var grapple_length := grapple_lengths[grapple_lengths.size() - 1]
	
	var distance_to_grapple := grapple_origin.distance_to(grapple_target)
	var is_loose := distance_to_grapple < grapple_length
	
	if is_loose:
		return
	
	var grapple_sphere_normal := (grapple_origin - grapple_target).normalized()
	var sphere_surface_plane := Plane(grapple_sphere_normal)
	var nearest_point_on_sphere := (
		grapple_target +
		(grapple_sphere_normal * grapple_length)
	)
	
	var projected_velocity := sphere_surface_plane.project(velocity)
	var linear_displacement := delta * projected_velocity
	var radial_displacement := linear_displacement / (grapple_length)
	
	var sphere_displacement := Vector3(
		grapple_length * sin(radial_displacement.x),
		grapple_length * sin(radial_displacement.y),
		grapple_length * sin(radial_displacement.z)
	)
	
	var destination = nearest_point_on_sphere + sphere_displacement
	var target_velocity = (destination - grapple_origin)/delta
	
	velocity = target_velocity


func _update_camera():
	view_container.global_position = camera_position.global_position
	
	var lateral_speed := velocity.dot(transform.basis.x)
	var max_ratio := lateral_speed / MAX_SPEED
	view_container.rotation.z = lerpf(view_container.rotation.z, -max_ratio * MAX_CAMERA_ROTATION, 0.1)


func _update_target():
	if not is_multiplayer_authority():
		target_marker.global_position = camera.to_global(Vector3.FORWARD * 100)
		return
	
	if firing_cast.is_colliding():
		target_marker.global_position = firing_cast.get_collision_point()
		return
	
	var target_found := false
	var target: Vector3
	
	var sweep_box_extent := 150.0 * tan(FIRING_SWEEP_ANGLE / 2.0)
	var sweep_box_delta := (sweep_box_extent * 2.0) / FIRING_SWEEP_AXIS_COUNT
	
	for i in range(FIRING_SWEEP_AXIS_COUNT + 1):
		for j in range(FIRING_SWEEP_AXIS_COUNT + 1):
			var x := sweep_box_delta * i - sweep_box_extent
			var y := sweep_box_delta * j - sweep_box_extent
			
			firing_cast.target_position.x = x
			firing_cast.target_position.y = y
			firing_cast.force_raycast_update()
			
			if firing_cast.is_colliding():
				target = firing_cast.get_collision_point()
				target_found = true
	
	firing_cast.target_position.x = 0
	firing_cast.target_position.y = 0
	
	if not target_found:
		target_marker.global_position = camera.to_global(Vector3.FORWARD * 100)
		return
		
	target_marker.global_position = target


func _update_rope_segments() -> void:
	if not in_grapple:
		for node in rope_segments.get_children():
			rope_segments.remove_child(node)
		return
	
	while grapple_targets.size() != rope_segments.get_child_count():
		if grapple_targets.size() > rope_segments.get_child_count():
			var new_segment := rope_template.duplicate() as Node3D
			rope_segments.add_child(new_segment)
			new_segment.top_level = true
			new_segment.show()
		else:
			var last_child := rope_segments.get_child(rope_segments.get_child_count() - 1)
			rope_segments.remove_child(last_child)
	
	for i in range(grapple_targets.size()):
		var target := grapple_targets[i]
		var next_target := grapple_source.global_position
		if i < grapple_targets.size() - 1:
			next_target = grapple_targets[i + 1]
		
		var length := target.distance_to(next_target)
		var midpoint := target + (next_target - target)/2
		
		var segment := rope_segments.get_child(i) as Node3D
		segment.look_at_from_position(midpoint, next_target)
		segment.scale.z = length


@rpc("call_local")
func play_grapple_success_sound() -> void:
	grapple_success_sound.play()


@rpc("call_local")
func play_thrust_sound() -> void:
	thrust_sound.play()
