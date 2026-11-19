class_name FPSAirState
extends FPSState

@export var air_speed := 8.0
@export var air_acceleration := 10.0
## Quake's cap on speed gained along the input, low allows air strafing.
@export var air_speed_cap := 1.0


func can_enter() -> bool:
	return not controller.is_on_floor()


func physics_update(delta: float) -> void:
	controller.set_crouched(controller.input.crouch_held)
	if controller.can_coyote_jump() and controller.consume_jump():
		controller.jump()
	controller.apply_gravity(delta)
	controller.accelerate(controller.wish_dir, air_speed * controller.wish_strength, air_acceleration, delta, air_speed_cap)
