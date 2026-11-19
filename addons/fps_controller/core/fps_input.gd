class_name FPSInput
extends RefCounted

signal device_changed(device: Device)

## The device used last.
enum Device { KEYBOARD_MOUSE, GAMEPAD }

const MOVE_FORWARD := &"fps_move_forward"
const MOVE_BACK := &"fps_move_back"
const MOVE_LEFT := &"fps_move_left"
const MOVE_RIGHT := &"fps_move_right"
const LOOK_LEFT := &"fps_look_left"
const LOOK_RIGHT := &"fps_look_right"
const LOOK_UP := &"fps_look_up"
const LOOK_DOWN := &"fps_look_down"
const JUMP := &"fps_jump"
const CROUCH := &"fps_crouch"
const SPRINT := &"fps_sprint"
const AIM := &"fps_aim"
const FIRE := &"fps_fire"

## Stick travel needed to switch to the gamepad, against drift.
const GAMEPAD_SWITCH_THRESHOLD := 0.3
## Mouse pixels needed to switch back.
const MOUSE_SWITCH_THRESHOLD := 2.0

const DEFAULT_KEYS := {
	MOVE_FORWARD: [KEY_W, KEY_UP],
	MOVE_BACK: [KEY_S, KEY_DOWN],
	MOVE_LEFT: [KEY_A, KEY_LEFT],
	MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	JUMP: [KEY_SPACE],
	CROUCH: [KEY_CTRL, KEY_C],
	SPRINT: [KEY_SHIFT],
}

const DEFAULT_MOUSE_BUTTONS := {
	AIM: [MOUSE_BUTTON_RIGHT],
	FIRE: [MOUSE_BUTTON_LEFT],
}

## Xbox names.
const DEFAULT_JOY_BUTTONS := {
	JUMP: [JOY_BUTTON_A],
	CROUCH: [JOY_BUTTON_B],
	SPRINT: [JOY_BUTTON_LEFT_STICK],
}

## Axis and direction.
const DEFAULT_JOY_AXES := {
	MOVE_FORWARD: [[JOY_AXIS_LEFT_Y, -1.0]],
	MOVE_BACK: [[JOY_AXIS_LEFT_Y, 1.0]],
	MOVE_LEFT: [[JOY_AXIS_LEFT_X, -1.0]],
	MOVE_RIGHT: [[JOY_AXIS_LEFT_X, 1.0]],
	LOOK_LEFT: [[JOY_AXIS_RIGHT_X, -1.0]],
	LOOK_RIGHT: [[JOY_AXIS_RIGHT_X, 1.0]],
	LOOK_UP: [[JOY_AXIS_RIGHT_Y, -1.0]],
	LOOK_DOWN: [[JOY_AXIS_RIGHT_Y, 1.0]],
	AIM: [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	FIRE: [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
}

## Small, the controller applies its own round deadzone.
const LOOK_ACTION_DEADZONE := 0.05

var move := Vector2.ZERO
## Right stick, before the controller's deadzone.
var look := Vector2.ZERO
var jump_pressed := false
var jump_held := false
var crouch_pressed := false
var crouch_held := false
var sprint_held := false
var aim_held := false
var fire_pressed := false
var fire_held := false
var device := Device.KEYBOARD_MOUSE


func poll() -> void:
	move = Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_FORWARD, MOVE_BACK)
	look = Input.get_vector(LOOK_LEFT, LOOK_RIGHT, LOOK_UP, LOOK_DOWN, 0.0)
	jump_pressed = Input.is_action_just_pressed(JUMP)
	jump_held = Input.is_action_pressed(JUMP)
	crouch_pressed = Input.is_action_just_pressed(CROUCH)
	crouch_held = Input.is_action_pressed(CROUCH)
	sprint_held = Input.is_action_pressed(SPRINT)
	aim_held = Input.is_action_pressed(AIM)
	fire_pressed = Input.is_action_just_pressed(FIRE)
	fire_held = Input.is_action_pressed(FIRE)


func track_device(event: InputEvent) -> void:
	var used := device
	if event is InputEventJoypadButton and event.pressed:
		used = Device.GAMEPAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > GAMEPAD_SWITCH_THRESHOLD:
		used = Device.GAMEPAD
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		used = Device.KEYBOARD_MOUSE
	elif event is InputEventMouseMotion and event.relative.length() > MOUSE_SWITCH_THRESHOLD:
		used = Device.KEYBOARD_MOUSE
	if used != device:
		device = used
		device_changed.emit(device)


static func register_defaults() -> void:
	for action in actions():
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, _default_deadzone(action))
		for event in _default_events(action):
			InputMap.action_add_event(action, event)


## Adds missing actions and default events to the project settings, keeps existing bindings.
static func save_defaults_to_project() -> void:
	for action in actions():
		var setting := "input/%s" % action
		var value: Dictionary = ProjectSettings.get_setting(setting, {"deadzone": _default_deadzone(action), "events": []})
		var events: Array = value.events
		for event in _default_events(action):
			if not events.any(func(existing: InputEvent) -> bool: return same_input(existing, event)):
				events.append(event)
		value.events = events
		ProjectSettings.set_setting(setting, value)
	ProjectSettings.save()


static func _default_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for keycode: Key in DEFAULT_KEYS.get(action, []):
		var event := InputEventKey.new()
		event.device = -1
		event.physical_keycode = keycode
		events.append(event)
	for button: MouseButton in DEFAULT_MOUSE_BUTTONS.get(action, []):
		var event := InputEventMouseButton.new()
		event.device = -1
		event.button_index = button
		events.append(event)
	for button: JoyButton in DEFAULT_JOY_BUTTONS.get(action, []):
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = button
		events.append(event)
	for axis: Array in DEFAULT_JOY_AXES.get(action, []):
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = axis[0]
		event.axis_value = axis[1]
		events.append(event)
	return events


static func _default_deadzone(action: StringName) -> float:
	return LOOK_ACTION_DEADZONE if action in [LOOK_LEFT, LOOK_RIGHT, LOOK_UP, LOOK_DOWN] else 0.2


## Same key, button or stick direction, ignoring device and modifiers.
static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a.get_class() != b.get_class():
		return false
	if a is InputEventKey:
		return a.physical_keycode == b.physical_keycode and a.keycode == b.keycode
	if a is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return a.button_index == b.button_index


static func actions() -> Array[StringName]:
	var names: Array[StringName] = []
	for table: Dictionary in [DEFAULT_KEYS, DEFAULT_MOUSE_BUTTONS, DEFAULT_JOY_BUTTONS, DEFAULT_JOY_AXES]:
		for action: StringName in table:
			if not names.has(action):
				names.append(action)
	return names
