@tool
class_name FPSRecoilProfile
extends Resource
## A weapon's recoil for FPSRecoil. The curves run over a burst, x 0 the first shot, x 1 shot pattern_shots;
## y is degrees per shot.

@export_group("Pattern")
@export_range(1, 100) var pattern_shots := 20
## Up.
@export var vertical: Curve
@export var vertical_scale := 1.0
## Right, negative is left.
@export var horizontal: Curve
@export var horizontal_scale := 1.0
## Random degrees per shot, right and up.
@export var spread := Vector2(0.15, 0.08)
## Seconds without a shot until the burst starts over.
@export_range(0.0, 2.0, 0.01, "suffix:s") var reset_time := 0.3

@export_group("Kick")
## How fast the view reaches the kick.
@export_range(1.0, 100.0, 0.5) var snap := 30.0
## Share of the climb that falls back after the burst.
@export_range(0.0, 1.0, 0.01) var recovery := 0.75
@export_range(0.0, 100.0, 0.5, "suffix:°/s") var recovery_speed := 14.0
## Keep it longer than the time between shots, else the view sinks mid-burst.
@export_range(0.0, 1.0, 0.01, "suffix:s") var recovery_delay := 0.15

@export_group("Weapon")
## Meters back, degrees up.
@export var weapon_kick := Vector2(0.035, 3.0)
@export_range(1.0, 60.0, 0.5) var weapon_return := 16.0

@export_group("Shake")
## For FPSScreenShake.
@export_range(0.0, 1.0, 0.01) var shake_trauma := 0.15


## Degrees right and up, without spread.
func pattern_kick(shot: int) -> Vector2:
	var t := clampf(float(shot) / maxf(pattern_shots - 1, 1), 0.0, 1.0)
	var up := vertical.sample_baked(t) if vertical else 1.0
	var right := horizontal.sample_baked(t) if horizontal else 0.0
	return Vector2(right * horizontal_scale, up * vertical_scale)
