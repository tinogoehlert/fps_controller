class_name FPSSwimState
extends FPSState
## Quake-style swimming in Area3Ds of liquid_group: move where you look, jump rises, crouch sinks.

@export var liquid_group := &"liquid"
## Share of the standing height under the surface.
@export_range(0.0, 1.0) var submerge_depth := 0.5
@export var swim_speed := 5.0
@export var acceleration := 8.0
@export var friction := 3.0
@export var sink_speed := 1.0
@export var exit_jump_velocity := 7.0


func _init() -> void:
	priority = 20


func can_enter() -> bool:
	return _is_submerged()


func can_exit() -> bool:
	return not _is_submerged()


func enter(_previous: FPSState) -> void:
	controller.set_crouched(false)


func physics_update(delta: float) -> void:
	if not _is_in_liquid(controller.head.global_position) and controller.consume_jump():
		controller.jump(exit_jump_velocity)
		return

	_apply_friction(delta)
	var wish := _wish_direction()
	if wish.is_zero_approx():
		controller.velocity.y = move_toward(controller.velocity.y, -sink_speed, acceleration * delta)
	else:
		controller.accelerate(wish.normalized(), swim_speed * wish.length(), acceleration, delta)


func _wish_direction() -> Vector3:
	var input := controller.input
	var wish := controller.head.global_basis * Vector3(input.move.x, 0.0, input.move.y)
	if input.jump_held:
		wish += Vector3.UP
	if input.crouch_held:
		wish += Vector3.DOWN
	# the length is the speed share
	return wish.limit_length(1.0)


func _apply_friction(delta: float) -> void:
	var speed := controller.velocity.length()
	if speed < 0.001:
		controller.velocity = Vector3.ZERO
		return
	controller.velocity *= maxf(speed - speed * friction * delta, 0.0) / speed


func _is_submerged() -> bool:
	return _is_in_liquid(controller.global_position + Vector3.UP * controller.stand_height * submerge_depth)


func _is_in_liquid(point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in controller.get_world_3d().direct_space_state.intersect_point(query):
		if hit.collider.is_in_group(liquid_group):
			return true
	return false
