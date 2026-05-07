# version: C3_v1
# last_modified_cycle: C3

extends Node

var _city_manager: Node = null
var _city_info_panel: Control = null
var _map_view: Control = null
var _last_edit_mode := false


func _ready():
	var paths := ["res://data/cities_custom.json", "res://data/cities.json"]
	var file: FileAccess = null
	var used_path := ""
	for p in paths:
		file = FileAccess.open(p, FileAccess.READ)
		if file:
			used_path = p
			break
	if file:
		var text := file.get_as_text()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			var data: Dictionary = parsed
			if data.has("cities"):
				GameState.set_data("city.list", data["cities"])
				# Load drawn_lines from separate file
				var lines_path := "res://data/drawn_lines.json"
				var lines_file := FileAccess.open(lines_path, FileAccess.READ)
				if lines_file:
					var lines_text := lines_file.get_as_text()
					var lines_parsed = JSON.parse_string(lines_text)
					if lines_parsed is Dictionary and lines_parsed.has("drawn_lines"):
						GameState.set_data("map.drawn_lines", lines_parsed["drawn_lines"])
					lines_file.close()
				DebugSystem.print_dbg("[MAIN] loaded cities=%d from %s" % [data["cities"].size(), used_path])
			else:
				DebugSystem.print_dbg("[MAIN] ERROR: cities.json missing 'cities' key")
		else:
			DebugSystem.print_dbg("[MAIN] ERROR: invalid cities.json")
		file.close()
	else:
		DebugSystem.print_dbg("[MAIN] ERROR: cannot open cities.json")

	_map_view = preload("res://scenes/map/map_view.tscn").instantiate()
	add_child(_map_view)

	# C3: Create CityManager
	_city_manager = preload("res://scripts/city/city_manager.gd").new()
	add_child(_city_manager)
	DebugSystem.print_dbg("[CITY] city_manager created")

	# C3: Create CityInfoPanel
	_city_info_panel = preload("res://scenes/ui/city_info_panel.tscn").instantiate()
	add_child(_city_info_panel)
	_city_info_panel.position = Vector2(980, 0)

	# C3: Connect marker signals after one frame (wait for markers to be created)
	await get_tree().process_frame
	_connect_marker_signals()

	# C3: Connect CityManager signals
	_city_manager.city_selected.connect(_on_city_selected)
	_city_manager.city_deselected.connect(_on_city_deselected)

	# C3: Connect panel signals
	_city_info_panel.save_requested.connect(_on_panel_save)
	_city_info_panel.close_requested.connect(_on_panel_close)

	# C3: Register city tests
	preload("res://scripts/city/test_city.gd").register_tests()

	_last_edit_mode = _map_view.city_editor.edit_mode


# Deselect city when entering edit mode (E key)
func _process(_delta: float) -> void:
	if _map_view.city_editor.edit_mode != _last_edit_mode:
		_last_edit_mode = _map_view.city_editor.edit_mode
		if _map_view.city_editor.edit_mode and _city_manager.get_selected():
			_city_manager.deselect_city()


func _connect_marker_signals() -> void:
	var markers = _map_view.get_node("Markers")
	for ch in markers.get_children():
		if ch.has_signal("city_clicked") and not ch.city_clicked.is_connected(_on_marker_clicked):
			ch.city_clicked.connect(_on_marker_clicked)


func _on_marker_clicked(city_id: int) -> void:
	# In edit mode, let city_editor handle the click
	if _map_view.city_editor.edit_mode:
		return
	_city_manager.select_city(city_id)


# Blank space click -> deselect
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _map_view.city_editor.edit_mode and _city_manager.get_selected():
			_city_manager.deselect_city()


func _on_city_selected(city_data: Dictionary) -> void:
	_city_info_panel.show_city(city_data)
	_update_marker_highlights(int(city_data.get("id", -1)))
	_map_view.refresh_connections()


func _on_city_deselected() -> void:
	_city_info_panel.hide_panel()
	_update_marker_highlights(-1)
	_map_view.refresh_connections()


func _on_panel_save(_city_id: int) -> void:
	# Delegate save to city editor
	if _map_view.city_editor.has_method("_save_json"):
		_map_view.city_editor._save_json()


func _on_panel_close() -> void:
	if _city_manager.get_selected():
		_city_manager.deselect_city()


func _update_marker_highlights(selected_id: int) -> void:
	var markers = _map_view.get_node("Markers")
	for ch in markers.get_children():
		if ch.has_method("set_selected"):
			var cid := int(ch.get_city_data().id)
			ch.set_selected(cid == selected_id)
