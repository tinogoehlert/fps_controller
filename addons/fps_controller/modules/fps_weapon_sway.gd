class_name FPSWeaponSway
extends FPSModule

@export var target: Node3D

@export_group("Look")
## Radians per degree/second of look.
@export var look_amount := 0.0004
@export var look_limit := 0.12
@export var look_smoothing := 10.0

@export_group("Bob")
## Sideways and down.
@export var bob_amount := Vector2(0.012, 0.008)
@export var bob_reference_speed := 8.0
@export var bob_smoothing := 8.0

@export_group("Pitch")
## At full pitch up.
@export var look_up_offset := Vector3(-0.03, -0.04, 0.05)
## At full pitch down.
@export var look_down_offset := Vector3(-0.04, 0.03, -0.03)

@export_group("Tilt")
@export var tilt_amount := 0.05
@export var tilt_smoothing := 8.0

@export_group("Landing")
## Meters per m/s of impact.
@export var landing_amount := 0.005
@export var landing_limit := 0.08
@export var landing_recovery := 8.0

@export_group("Aim")
## Puts the sights in the center while aiming.
@export var aim_offset := Vector3.ZERO
## Share of the sway left while aiming.
@export_range(0.0, 1.0, 0.05) var aim_sway := 0.2
@export var aim_smoothing := 14.0

var _rest := Transform3D.IDENTITY
var _pending_look := Vector2.ZERO
var _look := Vector2.ZERO
var _bob_weight := 0.0
var _tilt := 0.0
var _landing := 0.0
var _aim := 0.0


func setup(owner_controller: FPSController) -> void:
	super(owner_controller)
	_rest = target.transform
	controller.looked.connect(_on_looked)
	controller.landed.connect(_on_landed)


func _process(delta: float) -> void:
	if not controller or delta <= 0.0:
		return
	_update_look(delta)
	_update_bob(delta)
	_update_tilt(delta)
	_landing = lerpf(_landing, 0.0, FPSMath.damp(landing_recovery, delta))
	_aim = lerpf(_aim, 1.0 if controller.aiming else 0.0, FPSMath.damp(aim_smoothing, delta))

	var phase := controller.gait_phase()
	var bob := Vector3(cos(phase) * bob_amount.x, -absf(sin(phase)) * bob_amount.y, 0.0) * _bob_weight
	var calm := lerpf(1.0, aim_sway, _aim)
	var offset := (bob + _pitch_offset()) * calm + Vector3.DOWN * _landing + aim_offset * _aim
	var sway := Basis.from_euler(Vector3(_look.y, _look.x, _tilt) * calm)
	target.transform = _rest * Transform3D(sway, offset)


func _update_look(delta: float) -> void:
	var look_target := (_pending_look / delta * look_amount).limit_length(look_limit)
	_pending_look = Vector2.ZERO
	_look = _look.lerp(look_target, FPSMath.damp(look_smoothing, delta))


func _update_bob(delta: float) -> void:
	var speed := controller.horizontal_speed()
	var weight := clampf(speed / bob_reference_speed, 0.0, 1.0) if controller.is_on_floor() else 0.0
	_bob_weight = lerpf(_bob_weight, weight, FPSMath.damp(bob_smoothing, delta))


func _pitch_offset() -> Vector3:
	var pitch := controller.head.rotation.x / deg_to_rad(controller.max_pitch)
	return look_up_offset * pitch if pitch > 0.0 else look_down_offset * -pitch


func _update_tilt(delta: float) -> void:
	var strafe_speed := (controller.global_basis.inverse() * controller.velocity).x
	var tilt_target := -strafe_speed / bob_reference_speed * tilt_amount
	_tilt = lerpf(_tilt, tilt_target, FPSMath.damp(tilt_smoothing, delta))


func _on_looked(degrees: Vector2) -> void:
	_pending_look += degrees


func _on_landed(impact_speed: float) -> void:
	_landing = minf(_landing + impact_speed * landing_amount, landing_limit)
