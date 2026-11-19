class_name FPSGroundState
extends FPSState

@export var walk_speed := 8.0
@export var sprint_speed := 11.0
@export var crouch_speed := 4.0
@export var acceleration := 10.0
@export var friction := 6.0
@export var stop_speed := 3.0


func can_enter() -> bool:
	return controller.is_on_floor()


func physics_update(delta: float) -> void:
	controller.set_crouched(controller.input.crouch_held)
	if controller.consume_jump():
		controller.jump()
		return
	controller.apply_friction(friction, stop_speed, delta)
	controller.accelerate(controller.wish_dir, _wish_speed() * controller.wish_strength, acceleration, delta)
	controller.apply_gravity(delta)


func _wish_speed() -> float:
	if controller.is_crouched:
		return crouch_speed
	return sprint_speed if controller.input.sprint_held else walk_speed
