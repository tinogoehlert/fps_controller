# Nodes and resources

Defaults in parentheses. Distances in meters, speeds in m/s, angles in degrees, times in seconds; smoothing
values are rates, higher is faster.

## FPSController (`CharacterBody3D`)

| | |
|---|---|
| Nodes | `head`, `camera`, `collision`, `state_machine` |
| Look | `mouse_sensitivity` (0.12 °/px), `invert_mouse_y`, `max_pitch` (89), `capture_mouse` (on), `base_fov` (0: the camera's), `zoom_sensitivity` (1) |
| Gamepad look | `stick_look_speed` (220, 150 °/s), `stick_sensitivity` (1), `stick_deadzone` (0.12), `stick_curve` (2), `stick_edge_boost` (1.6), `stick_edge_ramp` (0.4), `invert_stick_y` |
| Body | `stand_height` (1.75), `crouch_height` (1.1), `eye_offset` (0.25, below the top), `crouch_smoothing` (12), `step_length` (5) |
| Jump | `gravity` (25), `jump_velocity` (8.4), `jump_buffer_time` (0.1), `coyote_time` (0.1), `auto_jump` |
| Stairs | `step_height` (0.5), `step_smoothing` (14) |

| State | |
|---|---|
| `input` | the `FPSInput` of this tick |
| `wish_dir`, `wish_strength` | where the input points on the floor, how far the stick is tilted (0 to 1) |
| `wish_velocity` | the velocity the last `accelerate()` asked for |
| `is_crouched`, `just_landed`, `time_since_floor`, `distance_walked` | |
| `aiming`, `zoom` | set by FPSAimState, the product of all `fov_zoom()` |

| Method | |
|---|---|
| `accelerate(direction, wish_speed, acceleration, delta, speed_cap = INF)` | Quake's acceleration |
| `apply_friction(friction, stop_speed, delta)`, `apply_gravity(delta)` | |
| `horizontal_speed()` | |
| `consume_jump() -> bool` | true once per buffered jump press |
| `can_coyote_jump() -> bool`, `jump(speed = jump_velocity)` | |
| `set_crouched(value)` | standing up waits for room |
| `turn(degrees: Vector2)` | turns the view like the mouse, right and down |
| `teleport(transform)` | |
| `gait_phase() -> float` | radians, a step every PI |
| `get_modules() -> Array[FPSModule]` | |

| Signal | |
|---|---|
| `jumped` | |
| `landed(impact_speed)` | |
| `stepped(height)` | walked up or down a step |
| `looked(degrees: Vector2)` | every turn: mouse, stick, `turn()` |
| `footstep(speed)` | at each footfall on the floor |

Duck-typed hooks on modules and states: `fov_zoom() -> float`, `filter_stick_look(degrees, delta) -> Vector2`
(gamepad only), `viewmodel_offset() -> Transform3D`.

## States

| Class | |
|---|---|
| `FPSState` (`Node`) | base: `priority`, `controller`, `machine`; `can_enter()`, `can_exit()`, `enter(previous)`, `exit(next)`, `physics_update(delta)` |
| `FPSStateMachine` (`Node`) | `current`, signal `state_changed(previous, current)` |
| `FPSGroundState` | `walk_speed` (8), `sprint_speed` (11), `crouch_speed` (4), `acceleration` (10), `friction` (6), `stop_speed` (3) |
| `FPSAirState` | `air_speed` (8), `air_acceleration` (10), `air_speed_cap` (1) |
| `FPSAimState` (`FPSGroundState`), priority 5 | `zoom` (1.3), `aim_speed` (4), `zoom_smoothing` (14), `aim_in_air` (on) |
| `FPSSlideState`, priority 10 | `min_entry_speed` (6), `exit_speed` (3), `boost` (3), `max_speed` (16), `friction` (0.8), `max_duration` (1), `cooldown` (0.4) |
| `FPSLadderState`, priority 15 | `ladder_group` (`ladder`), `climb_speed` (4), `strafe_speed` (2.5), `look_down_angle` (30), `acceleration` (30), `jump_off_speed` (5), `regrab_delay` (0.4) |
| `FPSSwimState`, priority 20 | `liquid_group` (`liquid`), `submerge_depth` (0.5), `swim_speed` (5), `acceleration` (8), `friction` (3), `sink_speed` (1), `exit_jump_velocity` (7) |

## Modules

All extend `FPSModule` (`Node`): `controller`, `setup(controller)`, `physics_update(delta)`.

| Class | |
|---|---|
| `FPSDoubleJump` | `air_jumps` (1), `velocity_scale` (1), `redirect_momentum` (on) |
| `FPSHeadBob` | `target`, `amount` (0.03), `reference_speed` (8), `smoothing` (8); landing: `landing_amount` (0.012), `landing_min_speed` (4), `landing_limit` (0.2), `landing_snap` (25), `landing_recovery` (6) |
| `FPSViewRoll` | `target`, `strafe_angle` (2), `strafe_speed` (6.25), `slide_angle` (8), `slide_forward_lean` (0.5), `slide_smoothing` (8) |
| `FPSWeaponSway` | `target`; `look_amount`, `look_limit`, `look_smoothing`; `bob_amount`, `bob_reference_speed`, `bob_smoothing`; `look_up_offset`, `look_down_offset`; `tilt_amount`, `tilt_smoothing`; `landing_amount`, `landing_limit`, `landing_recovery`; `aim_offset`, `aim_sway` (0.2), `aim_smoothing` |
| `FPSViewmodel` | `world_camera`, `model_root`, `model_scene`, `fov` (60), `render_layer` (20) |
| `FPSRecoil` | `profile`, `weapon_mount`, `screen_shake`, `shot`; `fire(profile = null) -> Vector2`, `weapon_root()` |
| `FPSScreenShake` | `camera`, `intensity` (1); `max_rotation`, `max_offset`, `frequency` (16), `decay` (1.5), `exponent` (2); `hit_kick` (6), `hit_snap`, `hit_return`, `hit_trauma` (0.3); `weapon_follow` (0.8), `weapon_lag` (14); `rumble` (on), `rumble_strength` (0.8); `trauma`; `add_trauma(amount)`, `add_trauma_at(origin, amount, radius)`, `hit(from, strength = 1)`, `quake(strength, duration = -1, fade_in = 0.5, fade_out = 1) -> int`, `stop_quake(id)`, `shake() -> float` |
| `FPSAimAssist` | `camera`, `enabled` (on), `target_group` (`aim_assist_target`), `max_distance` (40), `target_radius` (0.5), `min_zone_angle` (1.5); `friction_enabled`, `friction_strength` (0.45), `friction_zone` (2.5); `rotation_enabled`, `rotation_strength` (0.35), `rotation_zone` (3), `steering_threshold` (0.1); `magnetism_angle_gamepad` (3), `magnetism_angle_mouse` (0.75); `target`; `aim_direction(origin, direction) -> Vector3` |
| `FPSPushBodies` | `player_mass` (80 kg), `strength` (1), `acceleration` (30), `push_height` (0.3) |

## Resources and helpers

| Class | |
|---|---|
| `FPSRecoilProfile` (`Resource`) | pattern: `pattern_shots` (20), `vertical`, `vertical_scale`, `horizontal`, `horizontal_scale`, `spread`, `reset_time` (0.3); kick: `snap` (30), `recovery` (0.75), `recovery_speed` (14), `recovery_delay` (0.15); `weapon_kick`, `weapon_return` (16); `shake_trauma` (0.15) |
| `FPSSettings` (`Resource`) | see [Options](../guide/options.md): `from_controller(controller)`, `load_from(path, defaults)`, `save_to(path)`, `apply(controller)`, `bind(action, event) -> StringName`, `reset_bindings()` |
| `FPSInput` (`RefCounted`) | the action names (`MOVE_FORWARD` … `FIRE`), `device`, signal `device_changed(device)`; `register_defaults()`, `actions()`, `same_input(a, b)` |
| `FPSMath` | `damp(rate, delta)`: the frame-rate independent weight for `lerp` toward a target |
