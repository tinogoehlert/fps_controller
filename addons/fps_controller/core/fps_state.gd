@abstract
class_name FPSState
extends Node

## Higher is asked first.
@export var priority := 0

var controller: FPSController
var machine: FPSStateMachine


func can_enter() -> bool:
	return false


func can_exit() -> bool:
	return true


func enter(_previous: FPSState) -> void:
	pass


func exit(_next: FPSState) -> void:
	pass


@abstract func physics_update(delta: float) -> void
