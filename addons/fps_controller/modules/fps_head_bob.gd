class_name FPSHeadBob
extends FPSModule
## Bobs the target down at each footfall and dips it on hard landings. Sets only its position.

@export var target: Node3D
@export var amount := 0.03
@export var reference_speed := 8.0
@export var smoothing := 8.0

@export_group("Landing")
## Meters per m/s of impact above landing_min_speed.
@export var landing_amount := 0.012
@export var landing_min_speed := 4.0
@export var landing_limit := 0.2
## How fast the view sinks.
@export var landing_snap := 25.0
## How fast it comes back up.
@export var landing_recovery := 6.0

var _rest_position := Vector3.ZERO
var _weight := 0.0
var _landing := 0.0
var _landing_target := 0.0


func setup(owner_controller: FPSController) -> void:
	super(owner_controller)
	_rest_position = target.position
	controller.landed.connect(_on_landed)


func _process(delta: float) -> void:
	if not controller:
		return
	var speed_weight := clampf(controller.horizontal_speed() / reference_speed, 0.0, 1.0)
	var weight := speed_weight if controller.is_on_floor() else 0.0
	_weight = lerpf(_weight, weight, FPSMath.damp(smoothing, delta))

	# chasing a target that springs back: smooth at both ends
	_landing = lerpf(_landing, _landing_target, FPSMath.damp(landing_snap, delta))
	_landing_target = lerpf(_landing_target, 0.0, FPSMath.damp(landing_recovery, delta))

	var phase := controller.gait_phase()
	var bob := absf(sin(phase)) * amount * _weight
	target.position = _rest_position + Vector3.DOWN * (bob + _landing)


func _on_landed(impact_speed: float) -> void:
	var dip := maxf(impact_speed - landing_min_speed, 0.0) * landing_amount
	_landing_target = minf(_landing_target + dip, landing_limit)
