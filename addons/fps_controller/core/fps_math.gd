class_name FPSMath
extends RefCounted


## Frame-rate independent lerp weight.
static func damp(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
