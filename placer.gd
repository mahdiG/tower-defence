extends Node3D

# Drag your Troop scene into this variable in the Inspector
@export var troop_scene: PackedScene
# Layers that block placement (other troops, buildings). Do NOT include the ground.
@export_flags_3d_physics var blocked_layers: int = 2
# Radius of the footprint used to check the spawn point
@export var footprint_radius: float = 0.8

const RAY_LENGTH := 1000.0
const PREVIEW_ALPHA := 0.5
const VALID_COLOR := Color(0.2, 1.0, 0.2, PREVIEW_ALPHA)
const INVALID_COLOR := Color(1.0, 0.2, 0.2, PREVIEW_ALPHA)

var troop_preview: Node3D = null
var preview_material: StandardMaterial3D = null
var placement_is_valid := false


func select_troop() -> void:
	cancel_preview()
	_create_preview()


func cancel_preview() -> void:
	if is_instance_valid(troop_preview):
		troop_preview.queue_free()
	troop_preview = null
	preview_material = null
	placement_is_valid = false


func _process(_delta: float) -> void:
	if troop_preview:
		_move_preview_to_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if not troop_preview:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_move_preview_to_mouse()
			if placement_is_valid:
				_place_troop()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_preview()

	elif event.is_action_pressed("ui_cancel"):
		cancel_preview()


func _create_preview() -> void:
	troop_preview = troop_scene.instantiate()

	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.albedo_color = INVALID_COLOR

	_prepare_preview_node(troop_preview)
	add_child(troop_preview)
	placement_is_valid = false


func _prepare_preview_node(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is MeshInstance3D:
		node.material_override = preview_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is Node3D:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_prepare_preview_node(child)


func _move_preview_to_mouse() -> void:
	var mouse_position := get_viewport().get_mouse_position()
	var hit_result := _raycast_from_mouse(mouse_position)

	if hit_result.is_empty():
		troop_preview.visible = false
		placement_is_valid = false
		return

	troop_preview.visible = true
	troop_preview.global_position = hit_result.position
	placement_is_valid = _is_placement_free(hit_result.position)
	preview_material.albedo_color = VALID_COLOR if placement_is_valid else INVALID_COLOR


func _raycast_from_mouse(mouse_position: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ray_end := ray_origin + ray_direction * RAY_LENGTH

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _is_placement_free(placement_position: Vector3) -> bool:
	var footprint_shape := SphereShape3D.new()
	footprint_shape.radius = footprint_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = footprint_shape
	query.transform = Transform3D(Basis(), placement_position + Vector3.UP * footprint_radius)
	query.collision_mask = blocked_layers

	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _place_troop() -> void:
	var new_troop := troop_scene.instantiate()
	new_troop.global_position = troop_preview.global_position
	add_child(new_troop)
	cancel_preview()
