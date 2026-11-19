class_name FPSViewmodel
extends FPSModule
## Draws the weapon with its own camera and fov on top of the world, so it never clips into walls.

## Follows the world camera after everything else moved it, else the weapon lags a frame.
const LAST := 1000

@export var world_camera: Camera3D
@export var model_root: Node3D
## Instantiated below model_root.
@export var model_scene: PackedScene
@export_range(20.0, 120.0, 0.1, "suffix:°") var fov := 60.0
@export_flags_3d_render var render_layer := 1 << 19

var _camera: Camera3D


func setup(owner_controller: FPSController) -> void:
	super(owner_controller)
	process_priority = LAST
	if model_scene:
		model_root.add_child(model_scene.instantiate())
	_move_to_render_layer(model_root)
	world_camera.cull_mask &= ~render_layer
	add_child(_create_overlay())


## Modules with viewmodel_offset() -> Transform3D move the weapon's camera, in the world camera's space.
func _process(_delta: float) -> void:
	if not _camera:
		return
	var offset := Transform3D.IDENTITY
	for module in controller.get_modules():
		if module.has_method(&"viewmodel_offset"):
			offset *= module.viewmodel_offset()
	_camera.global_transform = world_camera.global_transform * offset


func _create_overlay() -> CanvasLayer:
	_camera = Camera3D.new()
	_camera.fov = fov
	_camera.near = 0.01
	_camera.cull_mask = render_layer
	_camera.environment = _overlay_environment()

	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.add_child(_camera)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(viewport)

	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.add_child(container)
	return layer


## Without background and fog, only the weapon is drawn.
func _overlay_environment() -> Environment:
	var world_environment := world_camera.get_world_3d().environment
	var environment := world_environment.duplicate() if world_environment else Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.fog_enabled = false
	return environment


func _move_to_render_layer(node: Node) -> void:
	if node is VisualInstance3D:
		node.layers = render_layer
	for child in node.get_children():
		_move_to_render_layer(child)
