class_name FPSViewRoll
extends FPSModule
## Rolls the target into strafes like Quake's V_CalcRoll, and into slides. Sets only its roll.

@export var target: Node3D

@export_group("Strafe")
## Quake's cl_rollangle.
@export_range(0.0, 15.0, 0.1, "suffix:°") var strafe_angle := 2.0
## Quake's cl_rollspeed, 200 units/s.
@export var strafe_speed := 6.25

@export_group("Slide")
@export_range(0.0, 30.0, 0.1, "suffix:°") var slide_angle := 8.0
## Lean when looking along the slide, as a share of slide_angle.
@export_range(-1.0, 1.0, 0.05) var slide_forward_lean := 0.5
@export var slide_smoothing := 8.0

var _slide_lean := 0.0


func _process(delta: float) -> void:
	if not controller:
		return
	var right := controller.global_basis.x
	var sliding := controller.state_machine.current is FPSSlideState
	var slide_target := _slide_lean_target(right) if sliding else 0.0
	_slide_lean = lerpf(_slide_lean, slide_target, FPSMath.damp(slide_smoothing, delta))

	var lean := _slide_lean if sliding else _strafe_lean(right) + _slide_lean
	target.rotation.z = -deg_to_rad(lean)


## Degrees right, instant like Quake.
func _strafe_lean(right: Vector3) -> float:
	var side := controller.velocity.dot(right)
	return signf(side) * minf(absf(side) / strafe_speed, 1.0) * strafe_angle


## Degrees right, more when the slide goes right of the view.
func _slide_lean_target(right: Vector3) -> float:
	var direction := Vector3(controller.velocity.x, 0.0, controller.velocity.z).normalized()
	return clampf(slide_forward_lean + direction.dot(right), -1.0, 1.0) * slide_angle
