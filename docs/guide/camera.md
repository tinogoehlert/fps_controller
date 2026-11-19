# Camera

## Field of view and zoom

The controller owns the camera's FOV: set `base_fov` (taken from the camera when 0), not `camera.fov`. Modules
and states with a method `fov_zoom() -> float` magnify the view, `controller.zoom` is their product and the FOV
follows from it. Magnifications multiply, so any number of them combine without fighting over `camera.fov`: an
effect that widens the view, like a speed kick, returns less than 1.

```gdscript
# a module that widens the view at speed
func fov_zoom() -> float:
	return 1.0 - clampf(controller.horizontal_speed() - 8.0, 0.0, 8.0) * 0.01
```

Zoomed in, mouse and stick turn slower by `zoom_sensitivity`: at 1 a turn moves the picture as far across the
screen as unzoomed, at 0 the degrees per pixel stay the same. `turn()` and recoil are not scaled.

## Aiming

`FPSAimState` aims down sights while `fps_aim` is held: on the floor it walks at `aim_speed`, and it zooms by
`zoom` (1.3 turns 73.74° into about 60°), reached at `zoom_smoothing`. It sets `controller.aiming`, which the
weapon sway follows. With `aim_in_air` the sights stay up in a jump, while the Air state moves the body.

## Head bob and footsteps

The controller keeps the gait: `distance_walked` on the floor and `step_length` (5 m) per step.
`controller.gait_phase()` gives its phase, so everything that moves with the steps keeps the same step.

`footstep(speed)` fires at each footfall, at the low point of the bob. Loudness from `speed`, sneaking from
`is_crouched`:

```gdscript
func _on_footstep(speed: float) -> void:
	step_sound.volume_db = linear_to_db(clampf(speed / 8.0, 0.2, 1.0) * (0.4 if player.is_crouched else 1.0))
	step_sound.play()
```

`FPSHeadBob` moves its `target`, the camera, down at each footfall by `amount` at `reference_speed`, less when
slower, smoothed by `smoothing`.

## Landing

FPSHeadBob also dips the view on hard landings, like knees giving way: `landing_amount` meters per m/s of
impact above `landing_min_speed` (4 m/s), so small hops and steps stay calm, at most `landing_limit`. The view
sinks at `landing_snap` and comes back up at `landing_recovery`. The controller's `landed(impact_speed)` gives
the speed for sounds or damage.

## View roll

`FPSViewRoll` leans its `target` into strafes like Quake's `cl_rollangle` (`strafe_angle`, 2°, full at
`strafe_speed`) and into slides (`slide_angle`). Looking along the slide it leans by `slide_forward_lean` of the
angle, looking across the full angle toward the side the slide goes. It only sets the roll, so FPSHeadBob can
move the same camera.

## Screen shake

`FPSScreenShake` shakes its `camera` by trauma, 0 to 1: the shake is trauma to the power of `exponent` (2), it
decays by `decay` per second, and the camera follows smooth noise at `frequency` up to `max_rotation` (degrees)
and `max_offset` (meters).

```gdscript
shake.add_trauma(0.4)                                      # something shook the player
shake.add_trauma_at(explosion.global_position, 1.0, 12.0)  # weaker with distance, none from 12 m on
shake.hit(attacker.global_position, 0.8)                   # pushes the view away from the hit
var id := shake.quake(0.5, 4.0)                            # holds for 4 s, fades in and out
shake.stop_quake(id)
```

A hit kicks the view by `hit_kick` degrees away from where it came from, reached at `hit_snap` and back at
`hit_return`, and adds `hit_trauma`. A quake without a duration holds until `stop_quake()`.

`intensity` scales all of it and 0 turns it off: an option for players who get sick from shaking. With `rumble`
the gamepad vibrates along at `rumble_strength` while it is played with.

The weapon goes along with `weapon_follow` of the shake: 1 holds it to the camera, 0.8 lets it move a fifth of
the shake on screen, smoothed by `weapon_lag`. The camera moves on a node of its own between it and its parent,
so FPSHeadBob and FPSViewRoll keep working.
