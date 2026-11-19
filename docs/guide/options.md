# Options

`FPSSettings` holds what players change in an options menu, and saves it as plain values to
`user://fps_settings.cfg` (`FPSSettings.PATH`):

| Group | |
|---|---|
| Look | `mouse_sensitivity`, `invert_mouse_y`, `stick_sensitivity`, `invert_stick_y`, `field_of_view`, `zoom_sensitivity` |
| Comfort | `screen_shake` (0 turns it off), `rumble`, `aim_assist` |
| Bindings | `bindings`: the actions the player bound anew, with all their events |

```gdscript
var settings := FPSSettings.load_from(FPSSettings.PATH, FPSSettings.from_controller(player))
settings.apply(player)

# when the player changes something
settings.mouse_sensitivity = slider.value
settings.apply(player)
settings.save_to()
```

**The defaults come from the scene.** `from_controller()` reads how the controller and its modules are set up,
and the file only overrides what is in it. A designer's sensitivity in the inspector stays the default.

`apply()` sets the controller (`field_of_view` is its `base_fov`, `stick_sensitivity` multiplies
`stick_look_speed`), FPSScreenShake's `intensity` and `rumble`, FPSAimAssist's `enabled`, and the bound actions
in the `InputMap`.

The file holds no objects: keys are saved by name, buttons and axes as numbers, and built again when loading. A
value of the wrong type or an unknown binding in a file someone edited is skipped.

## Key bindings

```gdscript
func _input(event: InputEvent) -> void:
	if waiting_for_action and (event is InputEventKey or event is InputEventJoypadButton) and event.pressed:
		var lost := settings.bind(waiting_for_action, event)
		if lost:
			show_hint("%s is not bound anymore" % lost)
		settings.apply(player)
		settings.save_to()
```

`bind(action, event)` binds what the player pressed in place of the action's bindings **on that device**: a new
key replaces keyboard and mouse, a new button the gamepad, the other device's stay. An `fps_*` action that had
this input loses it, and `bind()` returns that action. Mouse buttons and stick directions bind the same way.
The event is reduced to what makes the input and works on any gamepad.

`reset_bindings()` goes back to the project's bindings; call `apply()` afterwards.
