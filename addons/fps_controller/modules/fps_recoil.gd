class_name FPSRecoil
extends FPSModule
## A weapon calls fire() per shot. The view climbs along the profile and partly recovers; what the player
## pulled down already is not recovered again.

## For fire() without a profile.
@export var profile: FPSRecoilProfile
## Empty: no weapon kick.
@export var weapon_mount: Node3D
## Empty: no shake.
@export var screen_shake: FPSScreenShake

## Shots in the current burst.
var shot := 0

var _profile: FPSRecoilProfile
var _since_shot := INF
## Look degrees (x right, y down) the view has yet to turn.
var _pending := Vector2.ZERO
## Look degrees left to recover.
var _recoverable := Vector2.ZERO
var _turning := false
var _pivot: Node3D
## x meters back, y radians up.
var _weapon := Vector2.ZERO


func setup(owner_controller: FPSController) -> void:
	super(owner_controller)
	controller.looked.connect(_on_looked)
	if weapon_mount:
		# FPSViewmodel may still add the weapon this frame
		_add_pivot.call_deferred()


## Parent for weapons added later, so they kick.
func weapon_root() -> Node3D:
	return _pivot if _pivot else weapon_mount


## Returns the kick in degrees, right and up.
func fire(with_profile: FPSRecoilProfile = null) -> Vector2:
	_profile = with_profile if with_profile else profile
	if not _profile:
		return Vector2.ZERO
	if _since_shot > _profile.reset_time:
		shot = 0
	var kick := _profile.pattern_kick(shot)
	kick += Vector2(randf_range(-1.0, 1.0) * _profile.spread.x, randf_range(-1.0, 1.0) * _profile.spread.y)
	# look degrees: up is negative y
	var look := Vector2(kick.x, -kick.y)
	_pending += look
	_recoverable += look * _profile.recovery
	shot += 1
	_since_shot = 0.0
	_weapon += Vector2(_profile.weapon_kick.x, deg_to_rad(_profile.weapon_kick.y))
	if screen_shake:
		screen_shake.add_trauma(_profile.shake_trauma)
	return kick


func _process(delta: float) -> void:
	if not controller or not _profile:
		return
	_since_shot += delta

	var step := _pending * FPSMath.damp(_profile.snap, delta)
	_pending -= step
	_turn(step)

	if _since_shot > _profile.recovery_delay and not _recoverable.is_zero_approx():
		var back := -_recoverable.limit_length(_profile.recovery_speed * delta)
		_recoverable += back
		_turn(back)

	_weapon = _weapon.lerp(Vector2.ZERO, FPSMath.damp(_profile.weapon_return, delta))
	if _pivot:
		_pivot.transform = Transform3D(Basis(Vector3.RIGHT, _weapon.y), Vector3.BACK * _weapon.x)


func _turn(degrees: Vector2) -> void:
	if degrees.is_zero_approx():
		return
	_turning = true
	controller.turn(degrees)
	_turning = false


func _on_looked(degrees: Vector2) -> void:
	if _turning:
		return
	for axis in 2:
		if signf(degrees[axis]) == -signf(_recoverable[axis]):
			_recoverable[axis] = move_toward(_recoverable[axis], 0.0, absf(degrees[axis]))


func _add_pivot() -> void:
	_pivot = Node3D.new()
	_pivot.name = "RecoilPivot"
	var weapons := weapon_mount.get_children()
	weapon_mount.add_child(_pivot, false, Node.INTERNAL_MODE_BACK)
	for weapon in weapons:
		weapon.reparent(_pivot, false)
