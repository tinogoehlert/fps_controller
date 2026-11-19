class_name FPSDoubleJump
extends FPSModule

@export var air_jumps := 1
@export var velocity_scale := 1.0
## Turns the horizontal speed toward the input on each air jump.
@export var redirect_momentum := true

var _remaining := 0


func physics_update(_delta: float) -> void:
	if not controller.state_machine.current is FPSAirState:
		_remaining = air_jumps
		return
	if _remaining <= 0 or not controller.consume_jump():
		return

	_remaining -= 1
	if redirect_momentum and not controller.wish_dir.is_zero_approx():
		var speed := controller.horizontal_speed()
		controller.velocity.x = controller.wish_dir.x * speed
		controller.velocity.z = controller.wish_dir.z * speed
	controller.jump(controller.jump_velocity * velocity_scale)
