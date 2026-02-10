class_name Rifle extends Node3D

signal ammo_change

@onready var shot_ray := %ShotRay as RayCast3D
@onready var animations := %AnimationPlayer as AnimationPlayer
@onready var reload_timer := %ReloadTimer as Timer
@onready var shot_sound := %ShotSound as AudioStreamPlayer3D

const DAMAGE := 20
const RANGE := 200.0
const CAPACITY := 36
const SPEED_ACCURACY_INFLUENCE := 0.05
const ONE_HANDED_ACCURACY_INFLUENCE := 10.0
const TWO_HANDED_MIN_KICK := 0.01
const ONE_HANDED_MIN_KICK := 0.05
const RELOAD_ROTATION_RADIANS = 0.8

@export var in_cooldown := false

var is_reloading := false
var ammo_count := CAPACITY


func activate() -> void:
	emit_signal("ammo_change", ammo_count)
	reload_timer.paused = false
	show()


func deactivate() -> void:
	reload_timer.paused = true
	hide()


func fire(current_motion: Vector3, one_handed: bool, target: Vector3, player_id: int) -> Vector2:
	var kick := Vector2.ZERO
	
	if in_cooldown or is_reloading or ammo_count == 0:
		return kick
	
	var speed := current_motion.length()
	var max_deflection = (
		speed * SPEED_ACCURACY_INFLUENCE +
		int(one_handed) * ONE_HANDED_ACCURACY_INFLUENCE
	)
	
	var deflected_target := Vector3(
		randf_range(-max_deflection, max_deflection),
		randf_range(-max_deflection, max_deflection),
		-RANGE
	)
	
	var min_kick := ONE_HANDED_MIN_KICK if one_handed else TWO_HANDED_MIN_KICK
	var max_kick := min_kick * 1.5
	
	kick.y = -randf_range(min_kick, max_kick)
	kick.x = randf_range(min_kick, max_kick) * 0.5 * (-1.0 if randf() > 0.5 else 1.0)
	
	shot_ray.look_at(target)
	shot_ray.target_position = deflected_target
	shot_ray.force_raycast_update()
	
	var hit := shot_ray.get_collider() as Node3D
	if hit and hit.has_method("apply_damage"):
		hit.apply_damage(DAMAGE, player_id, global_position)
	
	var tracer_target := target + deflected_target
	if hit:
		tracer_target = hit.global_position
	rpc("animate_firing", shot_ray.to_global(deflected_target))
	
	ammo_count -= 1
	emit_signal("ammo_change", ammo_count)
	if ammo_count == 0:
		reload()
		
	return kick


func reload() -> void:
	if is_reloading:
		return
	is_reloading = true
	rotation.x += RELOAD_ROTATION_RADIANS
	reload_timer.start()


@rpc("call_local")
func animate_firing(target: Vector3) -> void:
	animations.play("shoot")
	
	var tracer := preload("res://Scenes/Weapons/Rifle/tracer.tscn").instantiate() as Tracer
	get_tree().get_root().add_child(tracer)
	tracer.set_tracer(shot_ray.global_position, target)


func _on_shot_timer_timeout() -> void:
	in_cooldown = false


func _on_reload_timer_timeout() -> void:
	ammo_count = CAPACITY
	is_reloading = false
	rotation.x -= RELOAD_ROTATION_RADIANS
	emit_signal("ammo_change", ammo_count)
