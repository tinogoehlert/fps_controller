# Getting started

## The prefab

1. Enable the plugin. It registers the `fps_*` input actions in the project settings.
2. Instance `addons/fps_controller/fps_controller.tscn`. It walks and jumps with its own Ground and Air states.
3. Add modules as children of the instance.
4. For more states, add an `FPSStateMachine` with all wanted states as its children, Ground and Air included,
   and assign it to the controller's `state_machine`.
5. Put the weapon in `FPSViewmodel.model_scene`, it is instantiated below `WeaponMount`.

None of this needs *Editable Children* on the instance.

The controller's origin is at the feet. The camera's FOV is vertical, as everywhere in Godot: 73.74° is Quake's
`fov 90`, horizontal at 4:3; on 16:9 it shows about 106° across, like the modern Quake ports.

The default sizes are Quake's at 32 units per meter: 1.75 m tall, eyes 0.25 m below the top, 8 m/s walking,
steps up to 0.5 m.

## Input actions

Enabling the plugin adds these actions to the project and the bindings below to them, also to actions that
exist already, without touching what is bound there. The controller registers them at runtime as well, so it
also works with the plugin off.

| Action | Keyboard and mouse | Gamepad (Xbox names) |
|---|---|---|
| `fps_move_forward`, `fps_move_back`, `fps_move_left`, `fps_move_right` | W A S D, arrow keys | left stick |
| `fps_look_left`, `fps_look_right`, `fps_look_up`, `fps_look_down` | mouse | right stick |
| `fps_jump` | Space | A |
| `fps_crouch` | Ctrl, C | B |
| `fps_sprint` | Shift | L3 |
| `fps_aim` | right mouse button | left trigger |
| `fps_fire` | left mouse button | right trigger |

The names are constants of `FPSInput`, e.g. `FPSInput.JUMP`. What they read this tick is in
`controller.input`: `move`, `look`, `jump_pressed`, `jump_held`, `crouch_pressed`, `crouch_held`,
`sprint_held`, `aim_held`, `fire_pressed`, `fire_held`.

## Mouse

With `capture_mouse` the controller captures the mouse when the game starts, `ui_cancel` (Escape) frees it and a
click captures it again. Turn it off when a menu handles the mouse. `mouse_sensitivity` is degrees per pixel,
`invert_mouse_y` flips it, `max_pitch` limits looking up and down.

## Gamepad

`FPSInput.device` follows the device used last, keyboard and mouse or gamepad, and `device_changed` reports a
switch, e.g. to change button prompts. A stick has to move past 0.3 to count, so a drifting stick does not take
over, and the mouse has to move more than 2 pixels.

The right stick turns with `stick_look_speed` (degrees per second, yaw and pitch) after a round
`stick_deadzone`, through a response curve (`stick_curve`; 2 is fine near the center and still fast at the
edge) and with a boost while it stays at the edge (`stick_edge_boost` after `stick_edge_ramp` seconds).
`stick_sensitivity` multiplies the speed for the player's setting, `invert_stick_y` flips it.

The left stick walks at the speed its tilt asks for: `controller.wish_strength` is 0 to 1, keys always give 1.
