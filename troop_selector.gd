extends CanvasLayer

@export var placer_path: NodePath = ^"../Placer"
@export var troop_scenes: Array[PackedScene] = [
	preload("res://troop_knight.tscn"),
	preload("res://troop_ranger.tscn"),
]
@export var troop_names: Array[String] = ["Knight", "Ranger"]

var buttons: Array[Button] = []
var button_group := ButtonGroup.new()
var placer: Node = null


func _ready() -> void:
	placer = get_node_or_null(placer_path)
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -290.0
	panel.offset_right = 290.0
	panel.offset_top = -108.0
	panel.offset_bottom = -20.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.04, 0.76)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.17, 0.42, 0.22, 1.0)
	selected_style.corner_radius_top_left = 4
	selected_style.corner_radius_top_right = 4
	selected_style.corner_radius_bottom_left = 4
	selected_style.corner_radius_bottom_right = 4

	for i in troop_scenes.size():
		var button := Button.new()
		var label: String = troop_names[i] if i < troop_names.size() else troop_scenes[i].resource_path.get_file().get_basename()
		button.text = "%d  %s" % [i + 1, label]
		button.toggle_mode = true
		button.button_group = button_group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(160, 40)
		button.add_theme_stylebox_override("pressed", selected_style)
		button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.62, 1.0))
		button.pressed.connect(_select.bind(i))
		row.add_child(button)
		buttons.append(button)

	var hint := Label.new()
	hint.text = "Left-click place  ·  Right-click cancel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	var index: int = key.keycode - KEY_1
	if index >= 0 and index < troop_scenes.size():
		_select(index)
		get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	if index < 0 or index >= troop_scenes.size():
		return

	for i in buttons.size():
		buttons[i].button_pressed = i == index

	if placer and placer.has_method("select_troop"):
		placer.select_troop(troop_scenes[index])
