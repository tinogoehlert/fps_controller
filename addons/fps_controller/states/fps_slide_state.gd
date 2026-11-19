class_name FPSSlideState
extends FPSState

@export var min_entry_speed := 6.0
@export var exit_speed := 3.0
@export var boost := 3.0
@export var max_speed := 16.0
@export var friction := 0.8
@export var max_duration := 1.0
@export var cooldown := 0.4

var _elapsed := 0.0
var _available_at := 0.0


func _init() -> void:
	priority = 10


func can_enter() -> bool:
	var input := controller.input
	var wants_slide := input.crouch_pressed or (controller.just_landed and input.crouch_held)
	return (wants_slide
		and controller.is_on_floor()
		and controller.horizontal_speed() >= min_entry_speed
		and _now() >= _available_at)


func can_exit() -> bool:
	return (not controller.is_on_floor()
		or not controller.input.crouch_held
		or _elapsed >= max_duration
		or controller.horizontal_speed() < exit_speed)


func enter(_previous: FPSState) -> void:
	_elapsed = 0.0
	controller.set_crouched(true)
	var velocity := controller.velocity
	var direction := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var speed := minf(controller.horizontal_speed() + boost, max_speed)
	controller.velocity = Vector3(direction.x * speed, velocity.y, direction.z * speed)


func exit(_next: FPSState) -> void:
	_available_at = _now() + cooldown


func physics_update(delta: float) -> void:
	_elapsed += delta
	if controller.consume_jump():
		controller.jump()
		return
	controller.apply_friction(friction, 0.0, delta)
	controller.apply_gravity(delta)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
