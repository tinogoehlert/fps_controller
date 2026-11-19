class_name FPSModule
extends Node

var controller: FPSController


func setup(owner_controller: FPSController) -> void:
	controller = owner_controller


func physics_update(_delta: float) -> void:
	pass
