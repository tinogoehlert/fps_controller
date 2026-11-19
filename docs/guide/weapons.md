# Weapons

The controller has no weapon logic of its own, shooting is up to the game. These modules make a weapon in hand
look and feel right.

## Viewmodel

`FPSViewmodel` draws everything below `model_root` (`WeaponMount` in the prefab) with a second camera on top of
the world, at its own `fov` (60°). The weapon gets its own depth buffer and never clips into walls.
`model_scene` is instantiated there at start, so the prefab needs no editable children.

The weapon moves to `render_layer` (20 by default), which the world camera stops drawing; keep that layer free
for the weapon. A light that should light the weapon needs that layer too.

The weapon's camera copies the world camera last in the frame, after shake, recoil and look moved it; a frame
behind, the weapon would jump on screen. Modules with a method `viewmodel_offset() -> Transform3D` move the
weapon on screen through that camera, in the world camera's space; FPSScreenShake uses it to let the weapon lag
behind the shake.

## Weapon sway

`FPSWeaponSway` moves its `target`, `WeaponMount`:

| Group | |
|---|---|
| Look | lags behind turning by `look_amount` per degree/second, at most `look_limit` |
| Bob | sideways and down with the steps, `bob_amount` at `bob_reference_speed`; one side per step, down at each footfall |
| Pitch | `look_up_offset` and `look_down_offset`, blended in by how far the player looks up or down |
| Tilt | rolls into strafes by `tilt_amount` |
| Landing | dips by `landing_amount` per m/s of impact, at most `landing_limit` |
| Aim | while `controller.aiming`: moves by `aim_offset` and keeps `aim_sway` of the sway |

Set `aim_offset` so the sights are in the center of the view.

## Recoil

A weapon calls `recoil.fire(profile)` for each shot, `fire()` alone uses the module's `profile`. It returns the
kick in degrees. An `FPSRecoilProfile` describes a weapon:

- **Pattern:** the curves `vertical` and `horizontal` give the degrees per shot over a burst of
  `pattern_shots` (x 0 the first shot, 1 the last, later shots keep the end), times their scale, plus random
  `spread`. After `reset_time` without a shot a burst starts over. `recoil_profiles/rifle.tres` climbs and
  drifts right, `pistol.tres` kicks the same every shot.
- **Kick:** `snap` is how fast the view reaches a shot's kick. After `recovery_delay` the view falls back by
  `recovery` of the climb at `recovery_speed`. What the player pulled down on their own is not brought down
  again. Keep `recovery_delay` longer than the time between two shots, else the view sinks during a burst.
- **Weapon:** the model kicks back and up by `weapon_kick` (meters, degrees) and returns at `weapon_return`.
- **Shake:** each shot adds `shake_trauma` to the module's `screen_shake`.

The view turns through `controller.turn()`, a real change of aim, reported by `looked`. The weapon kicks on a
node of its own between `weapon_mount` and the weapon; weapons added later, when switching, go to
`recoil.weapon_root()`.

## Aim assist

`FPSAimAssist` helps the gamepad, like Halo and Call of Duty, and only while the player steers or walks; the
mouse is never touched.

- **Friction:** over a target the stick turns slower, by `friction_strength`, fading out toward the edge of
  `friction_zone`.
- **Rotation:** a target moving across the view, also because the player strafes past it, is followed by
  `rotation_strength` within `rotation_zone`.
- **Bullet magnetism:** `aim_assist.aim_direction(origin, direction)` gives the direction a weapon should shoot
  in. A shot that misses a target by less than `magnetism_angle_gamepad` (3°) or, with the mouse,
  `magnetism_angle_mouse` (0.75°) goes to it.

Targets are nodes in `target_group` (`aim_assist_target`) that the `camera` can see, up to `max_distance`. A
target with a method `aim_point() -> Vector3` is aimed there, the chest of an enemy say, else at its origin.
Zones are measured in `target_radius`, so they get smaller with distance, down to `min_zone_angle`.
`aim_assist.target` is the target in reach right now. `enabled` off leaves stick and shots alone.

Other modules can change the stick's turn the same way: a method
`filter_stick_look(degrees: Vector2, delta: float) -> Vector2` is called for the gamepad only.

```gdscript
func _shoot() -> void:
	var direction := aim_assist.aim_direction(camera.global_position, -camera.global_basis.z)
	_fire_ray(camera.global_position, direction)
	recoil.fire(rifle_profile)
```
