class_name FPSAimState
extends FPSGroundState
## Aim down sights while fps_aim is held: slower on the floor, zoomed through fov_zoom().

## 1.3 turns 73.74° into about 60°.
@export_range(1.0, 10.0, 0.05, "suffix:×") var zoom := 1.3
@export var aim_speed := 4.0
@export var zoom_smoothing := 14.0
## Keeps aiming while the Air state is active.
@export var aim_in_air := true

var _amount := 0.0


func _init() -> void:
	priority = 5


func _process(delta: float) -> void:
	if not controller:
		return
	var in_air := aim_in_air and machine.current is FPSAirState and controller.input.aim_held
	controller.aiming = machine.current == self or in_air
	_amount = lerpf(_amount, 1.0 if controller.aiming else 0.0, FPSMath.damp(zoom_smoothing, delta))


func fov_zoom() -> float:
	return lerpf(1.0, zoom, _amount)


func can_enter() -> bool:
	return controller.input.aim_held and super()


func can_exit() -> bool:
	return not can_enter()


func _wish_speed() -> float:
	return minf(super(), aim_speed)
