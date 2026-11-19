class_name FPSScreenShake
extends FPSModule
## Trauma-based camera shake (Squirrel Eiserloh, "Juicing Your Cameras") on noise. Moves a node of its own
## between the camera and its parent.

@export var camera: Camera3D
## 0 is off.
@export_range(0.0, 2.0, 0.05) var intensity := 1.0

@export_group("Shake")
## Degrees at full shake.
@export var max_rotation := Vector3(2.5, 2.5, 4.0)
## Meters at full shake.
@export var max_offset := Vector3(0.04, 0.04, 0.0)
## High rattles, low sways.
@export_range(0.1, 60.0, 0.1) var frequency := 16.0
## Per second.
@export_range(0.0, 10.0, 0.05) var decay := 1.5
## shake = trauma ^ exponent.
@export_range(1.0, 4.0, 0.1) var exponent := 2.0

@export_group("Hit")
## Degrees a hit of strength 1 pushes the view away.
@export var hit_kick := 6.0
@export_range(1.0, 100.0, 0.5) var hit_snap := 35.0
@export_range(1.0, 60.0, 0.5) var hit_return := 10.0
@export_range(0.0, 1.0, 0.01) var hit_trauma := 0.3

@export_group("Weapon")
## Share of the shake the weapon follows, 1 holds it to the camera. Needs FPSViewmodel.
@export_range(0.0, 1.0, 0.01) var weapon_follow := 0.8
@export_range(1.0, 60.0, 0.5) var weapon_lag := 14.0

@export_group("Rumble")
## Vibrates the gamepad while it is in use.
@export var rumble := true
@export_range(0.0, 1.0, 0.01) var rumble_strength := 0.8

## 0 to 1.
var trauma := 0.0

var _quakes: Array[Dictionary] = []
var _next_quake := 0
var _noise := FastNoiseLite.new()
var _time := 0.0
var _kick := Vector3.ZERO
var _kick_target := Vector3.ZERO
var _pivot: Node3D
var _rumbling := false
var _weapon_offset := Transform3D.IDENTITY


func setup(owner_controller: FPSController) -> void:
	super(owner_controller)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	_add_pivot.call_deferred()


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Full amount at origin, none from radius on.
func add_trauma_at(origin: Vector3, amount: float, radius: float) -> void:
	var near := 1.0 - clampf(camera.global_position.distance_to(origin) / maxf(radius, 0.001), 0.0, 1.0)
	add_trauma(amount * near * near)


## Pushes the view away from where the hit came from.
func hit(from: Vector3, strength := 1.0) -> void:
	var local := camera.global_basis.inverse() * (from - camera.global_position)
	if local.is_zero_approx():
		local = Vector3.FORWARD
	local = local.normalized()
	# positive yaw and roll go left, local.x is negative on the left
	var away := Vector3(-local.z, local.x * 0.5, local.x) * deg_to_rad(hit_kick) * strength
	_kick_target += away
	add_trauma(hit_trauma * strength)


## A lasting shake, until stop_quake() when duration is negative. Returns its id.
func quake(strength: float, duration := -1.0, fade_in := 0.5, fade_out := 1.0) -> int:
	_next_quake += 1
	_quakes.append({"id": _next_quake, "strength": strength, "time": 0.0, "duration": duration,
			"fade_in": fade_in, "fade_out": fade_out, "stop": INF})
	return _next_quake


func stop_quake(id: int) -> void:
	for active in _quakes:
		if active.id == id:
			active.stop = active.time


## The current shake, 0 to 1, after exponent and intensity.
func shake() -> float:
	return pow(clampf(trauma + _quake_level(), 0.0, 1.0), exponent) * intensity


func _process(delta: float) -> void:
	if not _pivot:
		return
	trauma = maxf(trauma - decay * delta, 0.0)
	_time += delta
	for active in _quakes:
		active.time += delta
	_quakes = _quakes.filter(func(active: Dictionary) -> bool: return _quake_weight(active) > 0.0 or active.time < active.fade_in)
	_kick_target = _kick_target.lerp(Vector3.ZERO, FPSMath.damp(hit_return, delta))
	_kick = _kick.lerp(_kick_target, FPSMath.damp(hit_snap, delta))

	var amount := shake()
	var t := _time * frequency
	var rotation := Vector3(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(t, 100.0), _noise.get_noise_2d(t, 200.0))
	var offset := Vector3(_noise.get_noise_2d(t, 300.0), _noise.get_noise_2d(t, 400.0), _noise.get_noise_2d(t, 500.0))
	var angles := rotation * max_rotation * (deg_to_rad(1.0) * amount) + _kick * intensity
	_pivot.transform = Transform3D(Basis.from_euler(angles), offset * max_offset * amount)
	# the full shake would hold the weapon still in the world
	var weapon_target := Transform3D.IDENTITY.interpolate_with(_pivot.transform, 1.0 - weapon_follow)
	_weapon_offset = _weapon_offset.interpolate_with(weapon_target, FPSMath.damp(weapon_lag, delta))
	_rumble(amount)


## For FPSViewmodel.
func viewmodel_offset() -> Transform3D:
	return _weapon_offset


func _quake_level() -> float:
	var level := 0.0
	for active in _quakes:
		level = maxf(level, active.strength * _quake_weight(active))
	return level


func _quake_weight(active: Dictionary) -> float:
	var time: float = active.time
	var weight := clampf(time / maxf(active.fade_in, 0.001), 0.0, 1.0)
	var end: float = minf(active.stop, active.duration if active.duration >= 0.0 else INF)
	if time > end:
		weight *= 1.0 - clampf((time - end) / maxf(active.fade_out, 0.001), 0.0, 1.0)
	return weight


func _rumble(amount: float) -> void:
	var playing := rumble and controller.input.device == FPSInput.Device.GAMEPAD
	var strength := amount * rumble_strength if playing else 0.0
	if strength < 0.02:
		if _rumbling:
			for pad in Input.get_connected_joypads():
				Input.stop_joy_vibration(pad)
			_rumbling = false
		return
	for pad in Input.get_connected_joypads():
		# strong motor only for big shakes; renewed every frame
		Input.start_joy_vibration(pad, strength, strength * strength, 0.1)
	_rumbling = true


func _add_pivot() -> void:
	_pivot = Node3D.new()
	_pivot.name = "ShakePivot"
	var parent := camera.get_parent()
	parent.add_child(_pivot, false, Node.INTERNAL_MODE_BACK)
	_pivot.transform = Transform3D.IDENTITY
	camera.reparent(_pivot, false)
