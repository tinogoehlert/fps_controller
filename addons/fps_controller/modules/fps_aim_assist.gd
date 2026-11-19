class_name FPSAimAssist
extends FPSModule
## Gamepad aim assist: slower turning over a target (friction) and following it across the view (rotation),
## only while the player steers. aim_direction() bends shots toward targets for both devices (magnetism).
##
## Targets are visible nodes in target_group, aimed at their aim_point() -> Vector3 if they have one.

@export var camera: Camera3D
@export var enabled := true
@export var target_group := &"aim_assist_target"
@export var max_distance := 40.0
## Meters, the unit of the zones.
@export var target_radius := 0.5
## Zones never get narrower than this.
@export_range(0.0, 10.0, 0.1, "suffix:°") var min_zone_angle := 1.5

@export_group("Friction")
@export var friction_enabled := true
## Slowdown at the target's center, fading toward the zone's edge.
@export_range(0.0, 1.0, 0.01) var friction_strength := 0.45
## Size of the zone in target radii.
@export_range(1.0, 6.0, 0.1) var friction_zone := 2.5

@export_group("Rotation")
@export var rotation_enabled := true
## Share of the target's movement across the view that is followed.
@export_range(0.0, 1.0, 0.01) var rotation_strength := 0.35
## Size of the zone in target radii.
@export_range(1.0, 6.0, 0.1) var rotation_zone := 3.0
## Move input above this counts as steering.
@export_range(0.0, 1.0, 0.01) var steering_threshold := 0.1

@export_group("Magnetism")
@export_range(0.0, 10.0, 0.05, "suffix:°") var magnetism_angle_gamepad := 3.0
@export_range(0.0, 10.0, 0.05, "suffix:°") var magnetism_angle_mouse := 0.75

## The target in reach this frame, or null.
var target: Node3D

var _last_target: Node3D
var _last_view_angles := Vector2.ZERO


## The stick's turn in degrees, x yaw, y pitch.
func filter_stick_look(degrees: Vector2, _delta: float) -> Vector2:
	if not enabled:
		target = null
		return degrees
	var found := _best_target(camera.global_position, -camera.global_basis.z, maxf(friction_zone, rotation_zone))
	target = found.get("node")
	if not target:
		_last_target = null
		return degrees
	var steering := not degrees.is_zero_approx() or controller.wish_strength > steering_threshold

	if friction_enabled:
		var edge: float = _zone_angle(found.distance, friction_zone)
		if found.angle < edge:
			degrees *= 1.0 - friction_strength * (1.0 - found.angle / edge)

	var view_angles := _view_angles(found.point - camera.global_position)
	if rotation_enabled and steering and target == _last_target and found.angle < _zone_angle(found.distance, rotation_zone):
		var drift := Vector2(angle_difference(_last_view_angles.x, view_angles.x),
				angle_difference(_last_view_angles.y, view_angles.y))
		# a target moving right lowers its yaw, positive degrees turn right
		degrees -= Vector2(rad_to_deg(drift.x), rad_to_deg(drift.y)) * rotation_strength
	_last_target = target
	_last_view_angles = view_angles
	return degrees


## Bullet magnetism: the direction to shoot in, toward a target the shot would just miss.
func aim_direction(origin: Vector3, direction: Vector3) -> Vector3:
	if not enabled:
		return direction.normalized()
	var limit := magnetism_angle_gamepad if controller.input.device == FPSInput.Device.GAMEPAD else magnetism_angle_mouse
	var found := _best_target(origin, direction.normalized(), 0.0, limit)
	return (found.point - origin).normalized() if found else direction.normalized()


## The visible target closest to forward, within the zone or max_angle degrees.
func _best_target(origin: Vector3, forward: Vector3, zone: float, max_angle := -1.0) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group(target_group):
		if not node is Node3D or not node.is_visible_in_tree():
			continue
		var point: Vector3 = node.aim_point() if node.has_method(&"aim_point") else node.global_position
		var to_point := point - origin
		var distance := to_point.length()
		if distance < 0.01 or distance > max_distance:
			continue
		var angle := rad_to_deg(forward.angle_to(to_point))
		var limit := max_angle if max_angle >= 0.0 else _zone_angle(distance, zone)
		if angle < limit:
			candidates.append({"node": node, "point": point, "distance": distance, "angle": angle})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.angle < b.angle)
	# raycasts only until the closest visible one
	for candidate in candidates:
		if _visible(origin, candidate.point, candidate.node):
			return candidate
	return {}


func _zone_angle(distance: float, radii: float) -> float:
	return maxf(rad_to_deg(atan2(target_radius * radii, distance)), min_zone_angle)


func _visible(origin: Vector3, point: Vector3, node: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, point, controller.collision_mask, [controller.get_rid()])
	var hit := controller.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.collider
	return collider == node or (collider is Node and (node.is_ancestor_of(collider) or collider.is_ancestor_of(node)))


## Radians: yaw around Y from -Z, pitch up.
static func _view_angles(direction: Vector3) -> Vector2:
	var flat := Vector2(direction.x, direction.z).length()
	return Vector2(atan2(-direction.x, -direction.z), atan2(direction.y, flat))
