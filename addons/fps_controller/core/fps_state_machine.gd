class_name FPSStateMachine
extends Node

signal state_changed(previous: FPSState, current: FPSState)

var current: FPSState

var _states: Array[FPSState] = []


func setup(controller: FPSController) -> void:
	for child in get_children():
		if child is FPSState:
			child.controller = controller
			child.machine = self
			_states.append(child)
	assert(not _states.is_empty(), "FPSStateMachine needs at least one FPSState child.")
	_states.sort_custom(func(a: FPSState, b: FPSState) -> bool: return a.priority > b.priority)
	var initial := _find_enterable_state(null)
	_change_to(initial if initial else _states[0])


func physics_update(delta: float) -> void:
	if current.can_exit():
		var next := _find_enterable_state(current)
		if next:
			_change_to(next)
	current.physics_update(delta)


func _find_enterable_state(exclude: FPSState) -> FPSState:
	for state in _states:
		if state != exclude and state.can_enter():
			return state
	return null


func _change_to(next: FPSState) -> void:
	var previous := current
	if previous:
		previous.exit(next)
	current = next
	current.enter(previous)
	state_changed.emit(previous, current)
