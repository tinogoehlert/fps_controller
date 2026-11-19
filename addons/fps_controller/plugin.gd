@tool
extends EditorPlugin


func _enable_plugin() -> void:
	FPSInput.save_defaults_to_project()
