class_name RocketLauncher extends Node3D

signal ammo_change

const MAX_ROCKETS_IN_CHAMBER := 12

@onready var rocket_spawn := %RocketSpawnPoint as Marker3D
@onready var shot_timer := %ShotTimer as Timer
@onready var reload_timer := %ReloadTimer as Timer
@onready var launch_sound := %LaunchSound as AudioStreamPlayer3D

var in_cooldown := false
var ammo_count := MAX_ROCKETS_IN_CHAMBER
var Rocket = preload("res://Scenes/Weapons/Launcher/rocket.tscn")


func activate() -> void:
	emit_signal("ammo_change", ammo_count)
	reload_timer.paused = false


func deactivate() -> void:
	reload_timer.paused = true


func fire(current_motion: Vector3, one_handed: bool, target: Vector3, player_id: int) -> Vector2:
	if in_cooldown or ammo_count == 0:
		return Vector2.ZERO
	
	var rocket_basis := rocket_spawn.global_transform.basis
	var rocket_position := rocket_spawn.global_position + current_motion * 0.01
	var rocket_transform := Transform3D(rocket_basis, rocket_position)
	
	rpc("spawn_rocket", rocket_transform, target, player_id, current_motion)
	
	in_cooldown = true
	shot_timer.start()
	ammo_count -= 1
	emit_signal("ammo_change", ammo_count)
	
	return Vector2.ZERO


func reload() -> void:
	pass


@rpc("call_local")
func spawn_rocket(rocket_transform: Transform3D, target: Vector3, player_id: int, player_motion: Vector3) -> void:
	launch_sound.play()
	
	var rocket := Rocket.instantiate() as Rocket
	rocket.owning_player_id = player_id
	rocket.set_global_transform(rocket_transform)
	rocket.look_at_from_position(rocket_transform.origin, target)
	var local_z_velocity = player_motion.dot(-rocket_transform.basis.z)
	rocket.linear_velocity = -rocket_transform.basis.z * local_z_velocity
	get_tree().get_root().add_child(rocket)


func _on_shot_timer_timeout():
	in_cooldown = false


func _on_reload_timer_timeout():
	if ammo_count < MAX_ROCKETS_IN_CHAMBER:
		ammo_count += 1
		emit_signal("ammo_change", ammo_count)
