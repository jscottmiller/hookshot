class_name Rocket extends RigidBody3D

const FORCE := 300.0
const INITIAL_VELOCITY := 40.0

var owning_player_id: int
var source_location: Vector3
var near_collider_active := false


func _ready() -> void:
	source_location = global_position
	linear_velocity += -transform.basis.z * INITIAL_VELOCITY


func _physics_process(delta: float) -> void:
	var force := -global_transform.basis.z * FORCE
	apply_force(force)


func _on_fuse_timer_timeout() -> void:
	explode()


func _on_body_entered(body: PhysicsBody3D) -> void:
	explode()


func _on_near_player_collider_body_entered(body):
	if near_collider_active:
		explode()


func explode() -> void:
	var Explosion := preload("res://Scenes/Weapons/Launcher/rocket_explosion.tscn")
	var explosion := Explosion.instantiate() as RocketExplosion
	get_tree().get_root().add_child(explosion)
	explosion.global_position = global_position
	explosion.owning_player_id = owning_player_id
	explosion.owning_player_location = source_location
	queue_free()


func _on_near_collider_timer_timeout():
	near_collider_active = true
