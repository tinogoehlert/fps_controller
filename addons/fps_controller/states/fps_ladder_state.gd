class_name FPSLadderState
extends FPSState
## Climbs while the feet or waist are in an Area3D of ladder_group. Let the volume end a little above the
## upper floor, climbing up carries the player onto the ledge.

@export var ladder_group := &"ladder"
@export var climb_speed := 4.0
@export var strafe_speed := 2.5
## Looking down further, forward climbs down.
@export_range(0.0, 90.0, 1.0, "suffix:°") var look_down_angle := 30.0
@export var acceleration := 30.0
## Backwards, and half of it upwards.
@export var jump_off_speed := 5.0
## Seconds before the ladder catches the player again after a jump off.
@export_range(0.0, 2.0, 0.05, "suffix:s") var regrab_delay := 0.4

var _released := INF


func _init() -> void:
	priority = 15


func can_enter() -> bool:
	if _released < regrab_delay or not _on_ladder():
		return false
	# on the floor only climbing up takes the ladder, walking past stays walking
	return not controller.is_on_floor() or _climb() > 0.0


func can_exit() -> bool:
	return not _on_ladder() or (controller.is_on_floor() and _climb() < 0.0)


## Stops the player, else they pass through the thin volume.
func enter(_previous: FPSState) -> void:
	controller.set_crouched(false)
	controller.velocity = Vector3.UP * clampf(controller.velocity.y, -climb_speed, climb_speed)


func physics_update(delta: float) -> void:
	if controller.consume_jump():
		var back := controller.global_basis.z
		controller.velocity = back * jump_off_speed + Vector3.UP * jump_off_speed * 0.5
		controller.jump(controller.velocity.y)
		_released = 0.0
		return

	var climb := _climb()
	var target := Vector3.UP * climb * climb_speed
	target += controller.global_basis.x * controller.input.move.x * strafe_speed
	if climb > 0.0:
		# into the wall, and over the top onto the ledge
		target -= controller.global_basis.z * climb * climb_speed * 0.5
	controller.wish_velocity = target
	controller.velocity = controller.velocity.move_toward(target, acceleration * delta)


## Also counts while other states are active.
func _physics_process(delta: float) -> void:
	_released += delta


## -1 to 1, positive is up.
func _climb() -> float:
	var forward := -controller.input.move.y
	var looking_down := controller.head.rotation.x < -deg_to_rad(look_down_angle)
	if forward > 0.0 and looking_down:
		return -forward
	return forward


func _on_ladder() -> bool:
	var feet := controller.global_position + Vector3.UP * 0.1
	return _in_ladder(feet) or _in_ladder(feet + Vector3.UP * controller.stand_height * 0.5)


func _in_ladder(point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in controller.get_world_3d().direct_space_state.intersect_point(query):
		if hit.collider.is_in_group(ladder_group):
			return true
	return false
