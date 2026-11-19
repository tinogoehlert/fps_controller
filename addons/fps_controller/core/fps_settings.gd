class_name FPSSettings
extends Resource
## Player options: look, comfort and key bindings.
##
## [codeblock]
## var settings := FPSSettings.load_from(FPSSettings.PATH, FPSSettings.from_controller(player))
## settings.apply(player)
## # in the menu:
## settings.mouse_sensitivity = slider.value
## settings.apply(player)
## settings.save_to()
## [/codeblock]

const PATH := "user://fps_settings.cfg"
const BINDINGS := "bindings"

@export_group("Look")
@export_range(0.01, 1.0, 0.01, "suffix:°/px") var mouse_sensitivity := 0.12
@export var invert_mouse_y := false
## Multiplies stick_look_speed.
@export_range(0.1, 3.0, 0.05) var stick_sensitivity := 1.0
@export var invert_stick_y := false
## Vertical, the controller's base_fov. 73.74° is Quake's fov 90.
@export_range(40.0, 120.0, 0.1, "suffix:°") var field_of_view := 73.74
@export_range(0.0, 1.0, 0.05) var zoom_sensitivity := 1.0

@export_group("Comfort")
## FPSScreenShake.intensity, 0 is off.
@export_range(0.0, 2.0, 0.05) var screen_shake := 1.0
@export var rumble := true
@export var aim_assist := true

## Rebound actions with all their events, the others keep the project's.
var bindings: Dictionary[StringName, Array] = {}


## The current values of the controller and its modules, as defaults.
static func from_controller(controller: FPSController) -> FPSSettings:
	var settings := FPSSettings.new()
	settings.mouse_sensitivity = controller.mouse_sensitivity
	settings.invert_mouse_y = controller.invert_mouse_y
	settings.stick_sensitivity = controller.stick_sensitivity
	settings.invert_stick_y = controller.invert_stick_y
	settings.field_of_view = controller.base_fov if controller.base_fov > 0.0 else controller.camera.fov
	settings.zoom_sensitivity = controller.zoom_sensitivity
	for module in controller.get_modules():
		if module is FPSScreenShake:
			settings.screen_shake = module.intensity
			settings.rumble = module.rumble
		elif module is FPSAimAssist:
			settings.aim_assist = module.enabled
	return settings


## Saved values on top of defaults.
static func load_from(path := PATH, defaults: FPSSettings = null) -> FPSSettings:
	var settings: FPSSettings = defaults.duplicate() if defaults else FPSSettings.new()
	settings.bindings = defaults.bindings.duplicate() if defaults else settings.bindings
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return settings
	for property in _properties():
		var value: Variant = file.get_value("settings", property, settings.get(property))
		if typeof(value) == typeof(settings.get(property)):
			settings.set(property, value)
	for action in file.get_section_keys(BINDINGS) if file.has_section(BINDINGS) else PackedStringArray():
		var events: Array[InputEvent] = []
		for saved: Variant in file.get_value(BINDINGS, action, []):
			var event := _event_from(saved)
			if event:
				events.append(event)
		settings.bindings[StringName(action)] = events
	return settings


func save_to(path := PATH) -> Error:
	var file := ConfigFile.new()
	for property in _properties():
		file.set_value("settings", property, get(property))
	for action in bindings:
		file.set_value(BINDINGS, action, bindings[action].map(_event_to))
	return file.save(path)


## Sets the controller, its modules and the InputMap.
func apply(controller: FPSController) -> void:
	controller.mouse_sensitivity = mouse_sensitivity
	controller.invert_mouse_y = invert_mouse_y
	controller.stick_sensitivity = stick_sensitivity
	controller.invert_stick_y = invert_stick_y
	controller.base_fov = field_of_view
	controller.zoom_sensitivity = zoom_sensitivity
	for module in controller.get_modules():
		if module is FPSScreenShake:
			module.intensity = screen_shake
			module.rumble = rumble
		elif module is FPSAimAssist:
			module.enabled = aim_assist
	for action in bindings:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			for event: InputEvent in bindings[action]:
				InputMap.action_add_event(action, event)


## Replaces the action's bindings on the event's device, keyboard and mouse or gamepad. Returns the fps action
## that lost this input, or &"". Call apply() afterwards.
func bind(action: StringName, pressed: InputEvent) -> StringName:
	# strips keycode and device number, which would never match the defaults
	var event := _event_from(_event_to(pressed))
	if not event:
		return &""
	var taken_from := &""
	for other in FPSInput.actions():
		var other_events := _events_of(other)
		var kept := other_events.filter(func(existing: InputEvent) -> bool: return not FPSInput.same_input(existing, event))
		if kept.size() != other_events.size() and other != action:
			bindings[other] = kept
			taken_from = other
	var gamepad := _is_gamepad(event)
	var events := _events_of(action).filter(func(existing: InputEvent) -> bool: return _is_gamepad(existing) != gamepad)
	events.append(event)
	bindings[action] = events
	return taken_from


## Back to the project's bindings. Call apply() afterwards.
func reset_bindings() -> void:
	bindings.clear()
	InputMap.load_from_project_settings()
	FPSInput.register_defaults()


func _events_of(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	events.assign(bindings[action] if bindings.has(action) else InputMap.action_get_events(action))
	return events


static func _is_gamepad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func _properties() -> PackedStringArray:
	var names := PackedStringArray()
	for property in (FPSSettings as Script).get_script_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name != BINDINGS:
			names.append(property.name)
	return names


## Plain values: loading objects from an editable file is unsafe.
static func _event_to(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"key": OS.get_keycode_string(event.physical_keycode)}
	if event is InputEventMouseButton:
		return {"mouse": event.button_index}
	if event is InputEventJoypadButton:
		return {"joy_button": event.button_index}
	if event is InputEventJoypadMotion:
		return {"joy_axis": event.axis, "direction": signf(event.axis_value)}
	return {}


static func _event_from(saved: Variant) -> InputEvent:
	if not saved is Dictionary:
		return null
	var event: InputEvent
	if saved.has("key"):
		event = InputEventKey.new()
		event.physical_keycode = OS.find_keycode_from_string(str(saved.key))
	elif saved.has("mouse"):
		event = InputEventMouseButton.new()
		event.button_index = int(saved.mouse)
	elif saved.has("joy_button"):
		event = InputEventJoypadButton.new()
		event.button_index = int(saved.joy_button)
	elif saved.has("joy_axis"):
		event = InputEventJoypadMotion.new()
		event.axis = int(saved.joy_axis)
		event.axis_value = signf(float(saved.get("direction", 1.0)))
	else:
		return null
	event.device = -1
	return event
