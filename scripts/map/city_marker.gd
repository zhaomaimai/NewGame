# version: C2_v6
# last_modified_cycle: C2
# City marker: displays City2.png icon + name label.

extends Control

signal city_clicked(city_id: int)

var _city_data: Dictionary = {}
var _selected := false
var _hovered := false

@onready var _icon: TextureRect = $CityIcon
@onready var _label: Label = $NameLabel


func setup(city: Dictionary) -> void:
	_city_data = city
	_label.text = str(city.get("name", ""))
	queue_redraw()


func get_city_data() -> Dictionary:
	return _city_data


func set_selected(on: bool) -> void:
	_selected = on
	queue_redraw()


func set_edit_mode(_on: bool) -> void:
	# Keep STOP so marker emits city_clicked signals for the editor
	mouse_filter = MOUSE_FILTER_STOP


func set_city_name(name: String) -> void:
	_city_data.name = name
	_label.text = name


func _draw():
	if _selected:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 0.9, 0, 0.35), false, 2.0)
	if _hovered:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 1, 1, 0.15), true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		city_clicked.emit(int(_city_data.id))
		accept_event()


func _mouse_enter():
	_hovered = true
	queue_redraw()


func _mouse_exit():
	_hovered = false
	queue_redraw()
