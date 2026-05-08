# version: C5_v1
# last_modified_cycle: C5
# ═══════════════════════════════════════════════════════════════════
# Main — 游戏主入口
# ═══════════════════════════════════════════════════════════════════
# 启动时完成：
#   1. 加载城市数据（cities_custom.json）
#   2. 创建 MapView（地图 + 城市标记 + 编辑器）
#   3. 创建 CityManager（城市选中逻辑）
#   4. 创建 CityInfoPanel（城市信息面板）
#   5. 创建 TurnManager（回合系统）
#   6. 创建 InternalManager（内政逻辑）
#   7. 创建 CommandPanel（整合命令面板）
#   8. 注册测试到 TestRunner
# ═══════════════════════════════════════════════════════════════════

extends Node

var _city_manager: Node = null
var _city_info_panel: Control = null
var _map_view: Control = null
var _last_edit_mode := false

var _turn_manager: Node = null
var _internal_mgr: Node = null
var _command_panel = null


func _ready():
	var paths := ["res://data/cities_custom.json"]
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
				DebugSystem.print_dbg("[MAIN] ERROR: cities_custom.json missing 'cities' key")
		else:
			DebugSystem.print_dbg("[MAIN] ERROR: invalid cities.json")
		file.close()
	else:
		DebugSystem.print_dbg("[MAIN] ERROR: cannot open cities.json")

	_map_view = preload("res://scenes/map/map_view.tscn").instantiate()
	add_child(_map_view)

	_city_manager = preload("res://scripts/city/city_manager.gd").new()
	add_child(_city_manager)
	DebugSystem.print_dbg("[CITY] city_manager created")

	_city_info_panel = preload("res://scenes/ui/city_info_panel.tscn").instantiate()
	add_child(_city_info_panel)
	_city_info_panel.position = Vector2(980, 0)

	await get_tree().process_frame
	_connect_marker_signals()

	_city_manager.city_selected.connect(_on_city_selected)
	_city_manager.city_deselected.connect(_on_city_deselected)

	_city_info_panel.save_requested.connect(_on_panel_save)
	_city_info_panel.close_requested.connect(_on_panel_close)

	preload("res://scripts/city/test_city.gd").register_tests()

	# Turn system
	_turn_manager = preload("res://scripts/turn/turn_manager.gd").new()
	_turn_manager.name = "TurnManager"
	add_child(_turn_manager)

	preload("res://scripts/turn/test_turn.gd").register_tests()

	# Internal manager
	_internal_mgr = preload("res://scripts/internal/internal_manager.gd").new()
	_internal_mgr.name = "InternalManager"
	add_child(_internal_mgr)
	DebugSystem.print_dbg("[INTERNAL] internal_manager created")

	# Command panel (unified: time + internal commands + end turn)
	_command_panel = preload("res://scenes/ui/command_panel.tscn").instantiate()
	add_child(_command_panel)
	_command_panel.set_internal_manager(_internal_mgr)
	_command_panel.set_turn_manager(_turn_manager)
	_command_panel.update_date(_turn_manager.date_manager.get_date_string())
	_command_panel.update_phase(_turn_manager.phase_manager.get_phase_name())

	_turn_manager.turn_indicator = _command_panel
	_turn_manager.end_turn_button = null
	_command_panel.end_turn_pressed.connect(_on_end_turn_pressed)
	_command_panel.internal_done.connect(_on_internal_done)

	_turn_manager.phase_manager.phase_changed.connect(_on_phase_changed)

	preload("res://scripts/internal/test_internal.gd").register_tests()

	_last_edit_mode = _map_view.city_editor.edit_mode


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
	if _map_view.city_editor.edit_mode:
		return
	_city_manager.select_city(city_id)


func _input(event: InputEvent) -> void:
	# C key: toggle city info panel
	if event is InputEventKey and event.keycode == KEY_C and event.pressed and not event.echo:
		_city_info_panel.visible = not _city_info_panel.visible
		DebugSystem.print_dbg("[MAIN] city info panel toggled: %s" % ["shown" if _city_info_panel.visible else "hidden"])
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _map_view.city_editor.edit_mode and _city_manager.get_selected():
			_city_manager.deselect_city()


func _on_city_selected(city_data: Dictionary) -> void:
	_city_info_panel.show_city(city_data)
	if _turn_manager and _turn_manager.phase_manager.current_phase == 0:
		_command_panel.show_city(city_data)
	_update_marker_highlights(int(city_data.get("id", -1)))
	_map_view.refresh_connections()


func _on_city_deselected() -> void:
	_city_info_panel.hide_panel()
	_command_panel.hide_panel()
	_update_marker_highlights(-1)
	_map_view.refresh_connections()


func _on_panel_save(_city_id: int) -> void:
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


func _on_end_turn_pressed() -> void:
	_turn_manager.start_end_turn_flow()


func _on_phase_changed(phase_name: String) -> void:
	if _command_panel:
		_command_panel.update_phase(phase_name)


func _on_internal_done() -> void:
	_turn_manager.start_end_turn_flow()
	DebugSystem.print_dbg("[MAIN] internal done, starting end-turn flow")
