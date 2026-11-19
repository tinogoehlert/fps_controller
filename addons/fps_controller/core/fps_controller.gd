class_name FPSController
extends CharacterBody3D

signal jumped
signal landed(impact_speed: float)
signal stepped(height: float)
signal looked(degrees: Vector2)
## A foot touched the floor, at the low point of the head bob.
signal footstep(speed: float)

const MIN_STEP_HEIGHT := 0.01
const SURFACE_PROBE_OFFSET := 0.02
const SURFACE_PROBE_LENGTH := 0.1

@export var head: Node3D
## Its fov follows base_fov and zoom.
@export var camera: Camera3D
@export var collision: CollisionShape3D
## Ground and Air in the prefab. Assign your own FPSStateMachine for more states.
@export var state_machine: FPSStateMachine

@export_group("Look")
@export_range(0.01, 1.0, 0.01, "suffix:°/px") var mouse_sensitivity := 0.12
@export var invert_mouse_y := false
@export_range(0.0, 90.0, 0.1, "suffix:°") var max_pitch := 89.0
@export var capture_mouse := true
## Field of view without zoom, 0 takes the camera's.
@export_range(0.0, 179.0, 0.1, "suffix:°") var base_fov := 0.0
## Look slowdown while zoomed: 1 keeps the distance on screen, 0 the degrees.
@export_range(0.0, 1.0, 0.05) var zoom_sensitivity := 1.0

@export_group("Gamepad Look")
## Degrees per second at full tilt: yaw, pitch.
@export var stick_look_speed := Vector2(220.0, 150.0)
## Multiplies stick_look_speed.
@export_range(0.1, 3.0, 0.05) var stick_sensitivity := 1.0
## Round deadzone of the right stick.
@export_range(0.0, 0.5, 0.01) var stick_deadzone := 0.12
## Response curve exponent, 1 is linear.
@export_range(1.0, 4.0, 0.05) var stick_curve := 2.0
## Speed multiplier while the stick stays at the edge.
@export_range(1.0, 3.0, 0.05) var stick_edge_boost := 1.6
## Seconds at the edge until the boost is full.
@export_range(0.0, 2.0, 0.05, "suffix:s") var stick_edge_ramp := 0.4
@export var invert_stick_y := false

@export_group("Body")
@export var stand_height := 1.75
@export var crouch_height := 1.1
## From the top of the body down to the eyes.
@export var eye_offset := 0.25
@export var crouch_smoothing := 12.0
## Meters per step, for footsteps and bob.
@export_range(0.1, 20.0, 0.05, "suffix:m") var step_length := 5.0

@export_group("Jump")
@export var gravity := 25.0
@export var jump_velocity := 8.4
@export var jump_buffer_time := 0.1
@export var coyote_time := 0.1
@export var auto_jump := false

@export_group("Stairs")
@export var step_height := 0.5
@export var step_smoothing := 14.0

var input := FPSInput.new()
var wish_dir := Vector3.ZERO
## 0 to 1, keys always 1.
var wish_strength := 0.0
## What accelerate() aimed for this frame, before collisions.
var wish_velocity := Vector3.ZERO
var is_crouched := false
var just_landed := false
var time_since_floor := 0.0
## On the floor only.
var distance_walked := 0.0
## Set by FPSAimState.
var aiming := false
## Product of all fov_zoom().
var zoom := 1.0

var _modules: Array[FPSModule] = []
var _body_height := 0.0
var _eye_height := 0.0
var _step_offset := 0.0
var _jump_buffer := 0.0
var _jumped_since_floor := false
var _stick_edge_time := 0.0


func _ready() -> void:
	FPSInput.register_defaults()
	collision.shape = collision.shape.duplicate()
	_apply_body_height(stand_height)
	_eye_height = stand_height - eye_offset

	for node in find_children("*", "", true, false):
		if node is FPSModule:
			_modules.append(node)
			node.setup(self)
	state_machine.setup(self)

	if camera and base_fov <= 0.0:
		base_fov = camera.fov
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	input.track_device(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: Vector2 = event.screen_relative * Vector2(1.0, -1.0 if invert_mouse_y else 1.0)
		_look(motion * mouse_sensitivity * _zoom_look_scale())
	elif capture_mouse and event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif capture_mouse and event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_read_input(delta)
	state_machine.physics_update(delta)
	for module in _modules:
		module.physics_update(delta)
	_move(delta)


func _process(delta: float) -> void:
	_update_zoom()
	_stick_look(delta)
	_eye_height = lerpf(_eye_height, _body_height - eye_offset, FPSMath.damp(crouch_smoothing, delta))
	_step_offset = lerpf(_step_offset, 0.0, FPSMath.damp(step_smoothing, delta))
	head.position.y = _eye_height + _step_offset


func teleport(target: Transform3D) -> void:
	global_position = target.origin
	rotation.y = target.basis.get_euler().y
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	_step_offset = 0.0


func get_modules() -> Array[FPSModule]:
	return _modules


## Radians, a step every PI. Feet land where |sin| is 1.
func gait_phase() -> float:
	return distance_walked / step_length * PI


## Degrees right and down, like the mouse. Emits looked.
func turn(degrees: Vector2) -> void:
	_look(degrees)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func apply_gravity(delta: float) -> void:
	velocity.y -= gravity * delta


func accelerate(direction: Vector3, wish_speed: float, acceleration: float, delta: float, speed_cap := INF) -> void:
	wish_velocity = direction * wish_speed
	var missing_speed := minf(wish_speed, speed_cap) - velocity.dot(direction)
	if missing_speed > 0.0:
		velocity += direction * minf(acceleration * wish_speed * delta, missing_speed)


func apply_friction(friction: float, stop_speed: float, delta: float) -> void:
	var speed := horizontal_speed()
	if speed < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var new_speed := maxf(speed - maxf(speed, stop_speed) * friction * delta, 0.0)
	velocity.x *= new_speed / speed
	velocity.z *= new_speed / speed


func consume_jump() -> bool:
	if _jump_buffer <= 0.0:
		return false
	_jump_buffer = 0.0
	return true


func can_coyote_jump() -> bool:
	return not _jumped_since_floor and time_since_floor <= coyote_time


func jump(speed := jump_velocity) -> void:
	velocity.y = speed
	_jumped_since_floor = true
	jumped.emit()


func set_crouched(value: bool) -> void:
	if value == is_crouched or (not value and not _has_headroom()):
		return
	is_crouched = value
	_apply_body_height(crouch_height if value else stand_height)


func _look(degrees: Vector2) -> void:
	rotate_y(deg_to_rad(-degrees.x))
	var pitch_limit := deg_to_rad(max_pitch)
	head.rotation.x = clampf(head.rotation.x - deg_to_rad(degrees.y), -pitch_limit, pitch_limit)
	looked.emit(degrees)


## Modules and states with fov_zoom() -> float magnify the view, their magnifications multiply.
func _update_zoom() -> void:
	zoom = 1.0
	for node in _modules + state_machine.get_children():
		if node.has_method(&"fov_zoom"):
			zoom *= node.fov_zoom()
	if camera:
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) / zoom))


func _zoom_look_scale() -> float:
	return pow(zoom, -zoom_sensitivity)


## Modules with filter_stick_look(degrees, delta) -> Vector2 may change the turn, e.g. aim assist.
func _stick_look(delta: float) -> void:
	var tilt := minf(input.look.length(), 1.0)
	var degrees := Vector2.ZERO
	if tilt > stick_deadzone:
		var amount := pow(inverse_lerp(stick_deadzone, 1.0, tilt), stick_curve)
		var direction := input.look.normalized()
		_stick_edge_time = _stick_edge_time + delta if tilt > 0.95 else 0.0
		var boost := lerpf(1.0, stick_edge_boost, clampf(_stick_edge_time / maxf(stick_edge_ramp, 0.001), 0.0, 1.0))
		var speed := stick_look_speed * Vector2(boost, -1.0 if invert_stick_y else 1.0) * stick_sensitivity
		degrees = direction * speed * amount * delta * _zoom_look_scale()
	else:
		_stick_edge_time = 0.0
	if input.device == FPSInput.Device.GAMEPAD:
		for module in _modules:
			if module.has_method(&"filter_stick_look"):
				degrees = module.filter_stick_look(degrees, delta)
	if not degrees.is_zero_approx():
		_look(degrees)


func _read_input(delta: float) -> void:
	input.poll()
	wish_velocity = Vector3.ZERO
	wish_dir = (global_basis * Vector3(input.move.x, 0.0, input.move.y)).normalized()
	wish_strength = minf(input.move.length(), 1.0)
	if input.jump_pressed or (auto_jump and input.jump_held):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)


func _move(delta: float) -> void:
	var was_on_floor := is_on_floor()
	var impact_speed := -velocity.y

	var stepped_up := was_on_floor and velocity.y <= 0.0 and _try_step_up(delta)
	if not stepped_up:
		move_and_slide()
	if was_on_floor and not is_on_floor() and velocity.y <= 0.0:
		_try_step_down()

	just_landed = not was_on_floor and is_on_floor()
	if is_on_floor():
		time_since_floor = 0.0
		_jumped_since_floor = false
		var stride := distance_walked / step_length + 0.5
		distance_walked += horizontal_speed() * delta
		if floorf(distance_walked / step_length + 0.5) > floorf(stride):
			footstep.emit(horizontal_speed())
	else:
		time_since_floor += delta
	if just_landed:
		landed.emit(impact_speed)


## Quake-style: lift, move, drop. True if it stepped.
func _try_step_up(delta: float) -> bool:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.is_zero_approx():
		return false
	var direction := motion.normalized()

	var hit := KinematicCollision3D.new()
	var start := global_transform
	if not test_move(start, motion, hit):
		return false
	# a ramp's foot can report an edge, so check the surface too
	if _is_walkable(hit.get_normal()) and _is_walkable(_surface_normal(hit.get_position() + Vector3.DOWN * SURFACE_PROBE_OFFSET, direction)):
		return false

	var lift := Vector3.UP * step_height
	if test_move(start, lift, hit):
		lift = hit.get_travel()
	var probe := start.translated(lift)
	var forward := hit.get_travel() if test_move(probe, motion, hit) else motion
	probe = probe.translated(forward)

	if not test_move(probe, -lift, hit):
		return false
	if not _is_walkable(_surface_normal(hit.get_position() + direction * SURFACE_PROBE_OFFSET, Vector3.DOWN)):
		return false
	var target := probe.origin + hit.get_travel()
	var height := target.y - start.origin.y
	if height <= MIN_STEP_HEIGHT:
		return false

	global_position = target
	apply_floor_snap()
	_step_offset -= height
	stepped.emit(height)
	return true


func _try_step_down() -> void:
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3.DOWN * step_height, hit):
		return
	if not _is_walkable(_surface_normal(hit.get_position(), Vector3.DOWN)):
		return
	var drop := hit.get_travel()
	global_position += drop
	apply_floor_snap()
	_step_offset -= drop.y


## Contact normals on edges are interpolated, the ray finds the face's.
func _surface_normal(point: Vector3, direction: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		point - direction * SURFACE_PROBE_LENGTH,
		point + direction * SURFACE_PROBE_LENGTH,
		collision_mask,
		[get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.normal if result else Vector3.ZERO


func _has_headroom() -> bool:
	return not test_move(global_transform, Vector3.UP * (stand_height - _body_height))


func _is_walkable(normal: Vector3) -> bool:
	return not normal.is_zero_approx() and normal.angle_to(up_direction) <= floor_max_angle + 0.01


func _apply_body_height(height: float) -> void:
	_body_height = height
	collision.shape.set(&"height", height)
	collision.position.y = height * 0.5
