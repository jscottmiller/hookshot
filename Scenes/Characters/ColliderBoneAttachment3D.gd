extends BoneAttachment3D

@export var collision_shape: CollisionShape3D

func _physics_process(delta: float) -> void:
	collision_shape.set_global_transform(global_transform)
