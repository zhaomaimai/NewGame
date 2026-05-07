# version: C3_v2
# last_modified_cycle: C3
# City info panel — draggable, editable city data.

extends Panel

signal save_requested(city_id: int)
signal close_requested()

var _city_data: Dictionary = {}
var _dragging := false
var _drag_offset := Vector2.ZERO

var _name_label: Label
var _coord_label: Label
var _spins: Dictionary = {}


func _ready():
	size = Vector2(280, 340)
	_build_ui()
	visible = false


func _build_ui():
	# Drag handle at top
	var handle := ColorRect.new()
	handle.name = "DragHandle"
	handle.color = Color(0.12, 0.12, 0.2, 0.95)
	handle.size = Vector2(280, 28)
	handle.position = Vector2(0, 0)
	handle.mouse_filter = MOUSE_FILTER_STOP
	add_child(handle)

	var handle_label := Label.new()
	handle_label.text = "城市信息"
	handle_label.position = Vector2(10, 4)
	handle_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	handle.add_child(handle_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(252, 3)
	close_btn.size = Vector2(24, 22)
	close_btn.pressed.connect(_on_close)
	handle.add_child(close_btn)

	handle.gui_input.connect(_on_handle_gui_input)

	# Content area
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.3, 0.88)
	bg.size = Vector2(280, 312)
	bg.position = Vector2(0, 28)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(12, 36)
	vbox.size = Vector2(256, 296)
	add_child(vbox)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	vbox.add_child(_name_label)

	vbox.add_child(HSeparator.new())

	_coord_label = Label.new()
	vbox.add_child(_coord_label)

	_add_spin(vbox, "人口:", "population", 0, 999999, 100)
	_add_spin(vbox, "金:", "gold", 0, 999999, 100)
	_add_spin(vbox, "粮:", "food", 0, 999999, 100)
	_add_spin(vbox, "士兵:", "soldiers", 0, 999999, 100)
	_add_spin(vbox, "防御:", "defense", 0, 9999, 50)

	vbox.add_child(HSeparator.new())

	var save_btn := Button.new()
	save_btn.text = "保存到文件"
	save_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	save_btn.pressed.connect(_on_save)
	vbox.add_child(save_btn)


func _add_spin(parent: VBoxContainer, label_text: String, field: String, min_val: float, max_val: float, step: float = 1.0) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_FILL
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 50
	hbox.add_child(label)

	var spin := SpinBox.new()
	spin.custom_minimum_size.x = 160
	spin.size_flags_horizontal = Control.SIZE_EXPAND
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value_changed.connect(_on_field_changed.bind(field))
	hbox.add_child(spin)

	parent.add_child(hbox)
	_spins[field] = spin


func _on_field_changed(value: float, field: String) -> void:
	if _city_data.is_empty():
		return
	var int_val := int(value)
	_city_data[field] = int_val
	var cities: Array = GameState.get_data("city.list", [])
	for c in cities:
		if int(c.id) == int(_city_data.get("id", -1)):
			c[field] = int_val
			DebugSystem.print_dbg("[CITY] updated %s=%d for city %d" % [field, int_val, int(_city_data.get("id", -1))])
			break


func show_city(data: Dictionary) -> void:
	_city_data = data
	_name_label.text = str(data.get("name", ""))
	_coord_label.text = "坐标: (%d, %d)" % [int(data.get("x", 0)), int(data.get("y", 0))]
	_set_spin("population", data.get("population", 50000))
	_set_spin("gold", data.get("gold", 1000))
	_set_spin("food", data.get("food", 3000))
	_set_spin("soldiers", data.get("soldiers", 5000))
	_set_spin("defense", data.get("defense", 500))
	visible = true


func _set_spin(field: String, value: float) -> void:
	var spin = _spins.get(field)
	if spin:
		spin.value = value


func hide_panel() -> void:
	visible = false
	_city_data = {}


func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_offset = get_global_mouse_position() - position
				move_to_front()
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var new_pos := get_global_mouse_position() - _drag_offset
		new_pos.x = maxi(0, new_pos.x)
		new_pos.y = maxi(0, new_pos.y)
		position = new_pos


func _on_close() -> void:
	close_requested.emit()


func _on_save() -> void:
	save_requested.emit(int(_city_data.get("id", -1)))
