# version: C2_v10
# last_modified_cycle: C2
# City editor: add/connect/delete/rename/route cities. Press E to toggle.

extends Control

enum Mode { SELECT, ADD, CONNECT, DELETE, RENAME, ROUTE, DRAW, DELETE_LINE }

var edit_mode := false
var _mode := Mode.SELECT
var _selected_id := -1
var _drag_id := -1
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO
var _connect_from := -1
var _route_city_id := -1
var _route_target_id := -1
var _route_waypoints: Array = []
var _route_drag_wp := -1
var _route_drawing := false
var _route_last_point := Vector2.ZERO
var _route_min_dist := 8.0

# Draw mode
var _drawing := false
var _current_line: Array = []
var _draw_min_dist := 4.0

var _map_view: Control = null
var _markers_node: Node = null
var _toolbar: Control = null
var _toggle_btn: Button = null
var _mode_btns: Dictionary = {}
var _rename_panel: Panel = null
var _rename_input: LineEdit = null
var _renaming_id := -1
var _feedback_label: Label = null
var _feedback_timer: float = 0.0

const CITY2_H := 60.0
const MARKER_W := 100.0
const MARKER_H := 80.0


# ── setup ────────────────────────────────────────────────────────

func setup(mv: Control, mnode: Node) -> void:
	_map_view = mv
	_markers_node = mnode
	_build_toolbar()
	_build_rename_panel()
	_connect_marker_signals()


func _connect_marker_signals() -> void:
	for ch in _markers_node.get_children():
		if ch.has_signal("city_clicked") and not ch.city_clicked.is_connected(_on_city_clicked):
			ch.city_clicked.connect(_on_city_clicked)


# ── toolbar ──────────────────────────────────────────────────────

func _build_toolbar() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

	_toolbar = Panel.new()
	_toolbar.position = Vector2(10, 10)
	_toolbar.size = Vector2(710, 56)
	_toolbar.mouse_filter = MOUSE_FILTER_STOP
	add_child(_toolbar)

	# Toggle edit
	_toggle_btn = Button.new()
	_toggle_btn.text = "[E] 编辑: 关"
	_toggle_btn.position = Vector2(4, 4)
	_toggle_btn.size = Vector2(90, 24)
	_toggle_btn.pressed.connect(_toggle_edit)
	_toolbar.add_child(_toggle_btn)

	# Mode buttons
	var mode_data := [
		["选择", Mode.SELECT],
		["添加", Mode.ADD],
		["连接", Mode.CONNECT],
		["删除", Mode.DELETE],
		["改名", Mode.RENAME],
		["删线", Mode.DELETE_LINE],
		["画线", Mode.DRAW],
	]
	var mx := 98
	for md in mode_data:
		var btn := Button.new()
		btn.text = md[0]
		btn.position = Vector2(mx, 4)
		btn.size = Vector2(55, 24)
		btn.toggle_mode = true
		btn.pressed.connect(_on_mode_pressed.bind(md[1]))
		_toolbar.add_child(btn)
		_mode_btns[md[1]] = btn
		mx += 59

	# Save
	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.position = Vector2(mx + 4, 4)
	save_btn.size = Vector2(55, 24)
	save_btn.pressed.connect(_save_json)
	_toolbar.add_child(save_btn)

	# Load
	var load_btn := Button.new()
	load_btn.text = "加载"
	load_btn.position = Vector2(mx + 63, 4)
	load_btn.size = Vector2(55, 24)
	load_btn.pressed.connect(_reload_json)
	_toolbar.add_child(load_btn)

	# Clear lines
	var clear_btn := Button.new()
	clear_btn.text = "清线"
	clear_btn.position = Vector2(mx + 122, 4)
	clear_btn.size = Vector2(55, 24)
	clear_btn.pressed.connect(_clear_drawn_lines)
	_toolbar.add_child(clear_btn)

	# Feedback label
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(4, 32)
	_feedback_label.size = Vector2(580, 20)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	_feedback_label.text = ""
	_toolbar.add_child(_feedback_label)


func _build_rename_panel() -> void:
	_rename_panel = Panel.new()
	_rename_panel.size = Vector2(220, 100)
	_rename_panel.position = Vector2(10, 70)
	_rename_panel.mouse_filter = MOUSE_FILTER_STOP
	_rename_panel.visible = false
	add_child(_rename_panel)

	var rl := Label.new()
	rl.text = "城市名称:"
	rl.position = Vector2(10, 8)
	rl.size = Vector2(200, 20)
	_rename_panel.add_child(rl)

	_rename_input = LineEdit.new()
	_rename_input.position = Vector2(10, 30)
	_rename_input.size = Vector2(200, 28)
	_rename_panel.add_child(_rename_input)

	var ok_btn := Button.new()
	ok_btn.text = "确定"
	ok_btn.position = Vector2(10, 66)
	ok_btn.size = Vector2(70, 26)
	ok_btn.pressed.connect(_on_rename_ok)
	_rename_panel.add_child(ok_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(90, 66)
	cancel_btn.size = Vector2(70, 26)
	cancel_btn.pressed.connect(_on_rename_cancel)
	_rename_panel.add_child(cancel_btn)


# ── editor toggle ───────────────────────────────────────────────

func _toggle_edit() -> void:
	edit_mode = !edit_mode
	_toggle_btn.text = "[E] 编辑: 开" if edit_mode else "[E] 编辑: 关"
	if not edit_mode:
		if _drawing:
			_cancel_draw()
		_set_mode(Mode.SELECT)
		_rename_panel.visible = false
	for ch in _markers_node.get_children():
		if ch.has_method("set_edit_mode"):
			ch.set_edit_mode(edit_mode)
		if ch.has_method("set_selected"):
			ch.set_selected(false)
	queue_redraw()


# ── mode switching ──────────────────────────────────────────────

func _on_mode_pressed(mode: Mode) -> void:
	if _mode == mode:
		_set_mode(Mode.SELECT)
	else:
		_set_mode(mode)


func _set_mode(mode: Mode) -> void:
	# Clean up ALL previous mode state before switching
	if _drawing:
		_cancel_draw()
	if _route_target_id >= 0 or _route_drawing:
		_exit_route_editing()
	_route_drawing = false
	_mode = mode
	if mode == Mode.DRAW:
		_show_feedback("点击放置路径点，右键完成")
	if mode == Mode.DELETE_LINE:
		_show_feedback("点击线条即可删除")
	_selected_id = -1
	_connect_from = -1
	_drag_id = -1
	_rename_panel.visible = false

	for m in _mode_btns:
		_mode_btns[m].button_pressed = (m == mode)

	for ch in _markers_node.get_children():
		if ch.has_method("set_selected"):
			ch.set_selected(false)

	queue_redraw()


# ── input ───────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# ── GLOBAL HOTKEYS (always respond) ──
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		_toggle_edit()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if _drawing:
			_cancel_draw()
			get_viewport().set_input_as_handled()
			return
		if _route_target_id >= 0:
			_exit_route_editing()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _mode == Mode.DRAW:
			# DRAW mode handles right-click in _input_draw (finish line, not cancel)
			pass
		elif _drawing:
			_cancel_draw()
			get_viewport().set_input_as_handled()
			return
		if _route_target_id >= 0:
			_exit_route_editing()
			get_viewport().set_input_as_handled()
			return

	if not edit_mode or not is_inside_tree():
		return

	# ── DRAW MODE: completely isolated early return ──
	if _mode == Mode.DRAW:
		_input_draw(event)
		return

	# ── ROUTE EDITING handlers ──
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _route_target_id >= 0:
		var hit_id := _get_marker_at(event.position)
		if hit_id < 0:
			_route_waypoints.clear()
			_route_drawing = true
			_route_last_point = event.position
			_route_waypoints.append({"x": roundi(event.position.x), "y": roundi(event.position.y)})
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and _route_drawing and _route_target_id >= 0:
		var dist = event.position.distance_to(_route_last_point)
		if dist >= _route_min_dist:
			_route_waypoints.append({"x": roundi(event.position.x), "y": roundi(event.position.y)})
			_route_last_point = event.position
			queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _drag_id >= 0:
			_end_drag()
			return
		if _route_drag_wp >= 0:
			_route_drag_wp = -1
			return
		if _route_drawing:
			_route_drawing = false
			if _route_waypoints.size() < 2:
				_route_waypoints.clear()
			else:
				_save_route_paths()
				_refresh_lines()
				_show_feedback("已绘制 %d 个路径点" % _route_waypoints.size())
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

	if event is InputEventMouseMotion:
		if _drag_id >= 0:
			_handle_drag(event.position)
		if _route_drag_wp >= 0:
			_handle_route_drag(event.position)


func _input_draw(event: InputEvent) -> void:
	# DRAW mode: click to place waypoints, right-click to finish.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _drawing:
			_finish_draw()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _drawing:
			_start_draw(event.position)
			_show_feedback("\u7ee7\u7eed\u70b9\u51fb\u6dfb\u52a0\u8def\u5f84\u70b9\uff0c\u53f3\u952e\u5b8c\u6210")
		else:
			_current_line.append({"x": roundi(event.position.x), "y": roundi(event.position.y)})
			_show_feedback("\u8def\u5f84\u70b9 %d\uff0c\u53f3\u952e\u5b8c\u6210" % _current_line.size())
			_refresh_lines()
		queue_redraw()
		get_viewport().set_input_as_handled()
	return
	
	
# ── catmull-rom spline ──────────────────────────────────────────

func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _sample_catmull_rom(points: PackedVector2Array, segs: int = 8) -> PackedVector2Array:
	if points.size() < 2:
		return points
	if points.size() == 2:
		var result := PackedVector2Array()
		for i in range(segs + 1):
			result.append(points[0].lerp(points[1], float(i) / float(segs)))
		return result

	var result := PackedVector2Array()
	result.append(points[0])

	for i in range(1, points.size() - 1):
		var p0 := points[i - 1]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]

		for j in range(1, segs + 1):
			var t := float(j) / float(segs)
			result.append(_catmull_rom(p0, p1, p2, p3, t))

	return result


func _erase_line_at(mpos: Vector2) -> bool:
	var lines: Array = GameState.get_data("map.drawn_lines", [])
	if lines.is_empty():
		return false
	var threshold := 10.0
	for li in range(lines.size() - 1, -1, -1):
		var line = lines[li]
		if line is Array:
			for pt in line:
				var d = Vector2(float(pt.x), float(pt.y)).distance_to(mpos)
				if d < threshold:
					lines.remove_at(li)
					GameState.set_data("map.drawn_lines", lines)
					_refresh_lines()
					DebugSystem.print_dbg("[EDIT] erased line at (%.0f, %.0f)" % [mpos.x, mpos.y])
					return true
	return false


# ── click handling ──────────────────────────────────────────────

func _handle_click(mpos: Vector2) -> void:
	if _rename_panel.visible:
		return

	var hit_id := _get_marker_at(mpos)

	match _mode:
		Mode.SELECT:
			if hit_id < 0:
				_selected_id = -1
				for ch in _markers_node.get_children():
					if ch.has_method("set_selected"):
						ch.set_selected(false)
				queue_redraw()

		Mode.ADD:
			if hit_id < 0:
				_create_city(mpos)

		Mode.CONNECT:
			if hit_id < 0:
				_connect_from = -1
				queue_redraw()

		Mode.DELETE_LINE:
			if _erase_line_at(mpos):
				_show_feedback("已删除线条")
			queue_redraw()

		# Route: freehand drawing is handled in _input


func _on_city_clicked(city_id: int) -> void:
	if not edit_mode:
		return

	match _mode:
		Mode.SELECT:
			if city_id == _selected_id:
				_start_drag(city_id)
			else:
				_selected_id = city_id
				for ch in _markers_node.get_children():
					if ch.has_method("set_selected"):
						ch.set_selected(int(ch.get_city_data().id) == city_id)
				queue_redraw()

		Mode.CONNECT:
			if _connect_from < 0:
				_connect_from = city_id
				_show_feedback("请点击第二个城市来切换连接")
			elif city_id == _connect_from:
				_connect_from = -1
				queue_redraw()
			else:
				_toggle_connection(_connect_from, city_id)
				_connect_from = -1

		Mode.DELETE:
			_delete_city(city_id)

		Mode.DELETE_LINE:
			# Ignore city clicks in delete-line mode
			pass

		Mode.RENAME:
			var cd := _get_city_data_by_id(city_id)
			if cd:
				_show_rename_popup(city_id, str(cd.name))

		Mode.ROUTE:
			_route_city_clicked(city_id)


# ── marker hit testing ──────────────────────────────────────────

func _get_marker_at(mpos: Vector2) -> int:
	for ch in _markers_node.get_children():
		if not ch is Control or not ch.has_method("get_city_data"):
			continue
		var rect := Rect2(ch.position.x, ch.position.y, ch.size.x, CITY2_H)
		if rect.has_point(mpos):
			return int(ch.get_city_data().id)
	return -1


func _get_city_data_by_id(city_id: int) -> Dictionary:
	var cities: Array = GameState.get_data("city.list", [])
	for c in cities:
		if int(c.id) == city_id:
			return c
	return {}


# ── drag ────────────────────────────────────────────────────────

func _start_drag(city_id: int) -> void:
	_drag_id = city_id
	_drag_start_mouse = _map_view.get_local_mouse_position()
	for ch in _markers_node.get_children():
		if ch.has_method("get_city_data") and int(ch.get_city_data().id) == city_id:
			_drag_start_pos = ch.position
			break


func _handle_drag(mpos: Vector2) -> void:
	var delta := mpos - _drag_start_mouse
	var new_pos := _drag_start_pos + delta
	new_pos.x = clampf(new_pos.x, 0, _map_view.size.x - MARKER_W)
	new_pos.y = clampf(new_pos.y, 0, _map_view.size.y - MARKER_H)

	for ch in _markers_node.get_children():
		if ch.has_method("get_city_data") and int(ch.get_city_data().id) == _drag_id:
			ch.position = new_pos
			var cd: Dictionary = ch.get_city_data()
			cd.x = roundi(new_pos.x + MARKER_W * 0.5)
			cd.y = roundi(new_pos.y + CITY2_H)
			break

	queue_redraw()


func _end_drag() -> void:
	_drag_id = -1
	_refresh_lines()


# ── connection toggle ───────────────────────────────────────────

func _toggle_connection(a_id: int, b_id: int) -> void:
	var cities: Array = GameState.get_data("city.list", [])
	var changed := false
	for c in cities:
		var cid := int(c.id)
		if cid == a_id:
			if c.connections.has(b_id):
				c.connections.erase(b_id)
			else:
				c.connections.append(b_id)
			changed = true
		if cid == b_id:
			if c.connections.has(a_id):
				c.connections.erase(a_id)
			else:
				c.connections.append(a_id)
			changed = true
	if changed:
		GameState.set_data("city.list", cities)
		for ch in _markers_node.get_children():
			if ch.has_method("get_city_data"):
				var cd: Dictionary = ch.get_city_data()
				for c in cities:
					if int(c.id) == int(cd.id):
						cd.connections = c.connections.duplicate()
						break
		_refresh_lines()
		_show_feedback("连接 %d ↔ %d %s" % [a_id, b_id, "已建立" if _has_connection(a_id, b_id, cities) else "已断开"])
		DebugSystem.print_dbg("[EDIT] toggled connection %d ↔ %d" % [a_id, b_id])
	queue_redraw()


func _has_connection(a_id: int, b_id: int, cities: Array) -> bool:
	for c in cities:
		if int(c.id) == a_id:
			return c.connections.has(b_id)
	return false


# ── create / delete city ────────────────────────────────────────

func _create_city(mpos: Vector2) -> void:
	var cities: Array = GameState.get_data("city.list", [])
	var max_id := 0
	for c in cities:
		var cid := int(c.id)
		if cid > max_id:
			max_id = cid
	var new_id := max_id + 1

	var new_city := {
		"id": new_id,
		"name": "新城",
		"x": roundi(mpos.x),
		"y": roundi(mpos.y),
		"connections": []
	}
	cities.append(new_city)
	GameState.set_data("city.list", cities)

	var marker := preload("res://scenes/map/city_marker.tscn").instantiate()
	_markers_node.add_child(marker)
	marker.setup(new_city)
	marker.position = Vector2(mpos.x - MARKER_W * 0.5, mpos.y - CITY2_H)

	if marker.has_signal("city_clicked"):
		marker.city_clicked.connect(_on_city_clicked)

	_selected_id = new_id
	_drag_id = new_id
	_drag_start_mouse = mpos
	_drag_start_pos = marker.position

	DebugSystem.print_dbg("[EDIT] created city id=%d at (%.0f, %.0f)" % [new_id, mpos.x, mpos.y])
	_show_feedback("已创建城市 #%d" % new_id)
	_refresh_lines()
	queue_redraw()


func _delete_city(city_id: int) -> void:
	var cities: Array = GameState.get_data("city.list", [])
	var to_remove = null
	for c in cities:
		if int(c.id) == city_id:
			to_remove = c
			break
	if to_remove:
		for c in cities:
			if c.has("connections") and c.connections.has(city_id):
				c.connections.erase(city_id)
		cities.erase(to_remove)
		GameState.set_data("city.list", cities)

	for ch in _markers_node.get_children():
		if ch.has_method("get_city_data") and int(ch.get_city_data().id) == city_id:
			ch.queue_free()
			break

	_selected_id = -1
	_show_feedback("已删除城市 #%d" % city_id)
	DebugSystem.print_dbg("[EDIT] deleted city id=%d" % city_id)
	_refresh_lines()
	queue_redraw()


# ── rename ──────────────────────────────────────────────────────

func _show_rename_popup(city_id: int, current_name: String) -> void:
	_renaming_id = city_id
	_rename_input.text = current_name
	_rename_input.placeholder_text = current_name
	_rename_panel.visible = true
	_rename_input.grab_focus()


func _on_rename_ok() -> void:
	var new_name := _rename_input.text.strip_edges()
	if new_name.is_empty():
		_rename_panel.visible = false
		return

	for ch in _markers_node.get_children():
		if ch.has_method("get_city_data") and int(ch.get_city_data().id) == _renaming_id:
			if ch.has_method("set_city_name"):
				ch.set_city_name(new_name)
			break

	_rename_panel.visible = false
	_show_feedback("已重命名为: %s" % new_name)
	DebugSystem.print_dbg("[EDIT] renamed city %d -> '%s'" % [_renaming_id, new_name])
	_renaming_id = -1
	queue_redraw()


func _on_rename_cancel() -> void:
	_rename_panel.visible = false
	_renaming_id = -1



# ── route (draw path) ──────────────────────────────────────────

func _route_city_clicked(city_id: int) -> void:
	if _route_city_id < 0:
		# First click: select city
		_route_city_id = city_id
		_selected_id = city_id
		for ch in _markers_node.get_children():
			if ch.has_method("set_selected"):
				ch.set_selected(int(ch.get_city_data().id) == city_id)
		_show_feedback("已选择 %s，点击连接的城市来画路径" % _get_city_data_by_id(city_id).get("name", ""))
		queue_redraw()
		return

	# Second click: pick a connected city or switch selection
	var src = _get_city_data_by_id(_route_city_id)
	if not src:
		_route_city_id = -1
		return

	if src.connections.has(city_id):
		# Start editing path between these two cities
		_route_target_id = city_id
		_route_waypoints = _load_waypoints(_route_city_id, city_id)
		_show_feedback("编辑路径中：点击地图添加路径点，点击路径点删除，右键/Esc退出")
		queue_redraw()
	elif city_id == _route_city_id:
		_exit_route_editing()
	else:
		# Switch to different city
		_route_city_id = city_id
		_selected_id = city_id
		for ch in _markers_node.get_children():
			if ch.has_method("set_selected"):
				ch.set_selected(int(ch.get_city_data().id) == city_id)
		_show_feedback("%s 与 %s 没有直接连接" % [src.get("name",""), _get_city_data_by_id(city_id).get("name","")])
		queue_redraw()


func _load_waypoints(a_id: int, b_id: int) -> Array:
	var c = _get_city_data_by_id(a_id)
	if c and c.has("route_paths"):
		var rp = c["route_paths"]
		if rp is Dictionary and rp.has(str(b_id)):
			return rp[str(b_id)].duplicate()
	# Try the other city
	c = _get_city_data_by_id(b_id)
	if c and c.has("route_paths"):
		var rp = c["route_paths"]
		if rp is Dictionary and rp.has(str(a_id)):
			return rp[str(a_id)].duplicate()
	return []


func _add_waypoint(mpos: Vector2) -> void:
	if _route_target_id < 0:
		return
	_route_waypoints.append({"x": roundi(mpos.x), "y": roundi(mpos.y)})
	_save_route_paths()
	_show_feedback("添加路径点 (%d, %d)" % [roundi(mpos.x), roundi(mpos.y)])
	_refresh_lines()
	queue_redraw()


func _try_delete_waypoint(mpos: Vector2) -> bool:
	if _route_target_id < 0:
		return false
	var wp_positions = _get_waypoint_positions()
	for i in range(wp_positions.size()):
		if wp_positions[i].distance_to(mpos) < 12.0:
			_route_waypoints.remove_at(i)
			_save_route_paths()
			_show_feedback("删除路径点")
			_refresh_lines()
			queue_redraw()
			return true
	return false


func _get_waypoint_positions() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for wp in _route_waypoints:
		pts.append(Vector2(float(wp.x), float(wp.y)))
	return pts


func _save_route_paths() -> void:
	if _route_city_id < 0 or _route_target_id < 0:
		return
	var c = _get_city_data_by_id(_route_city_id)
	if not c:
		return
	if not c.has("route_paths") or not (c["route_paths"] is Dictionary):
		c["route_paths"] = {}
	if _route_waypoints.size() > 0:
		c["route_paths"][str(_route_target_id)] = _route_waypoints.duplicate()
	else:
		c["route_paths"].erase(str(_route_target_id))
		if c["route_paths"].size() == 0:
			c.erase("route_paths")	


func _exit_route_editing() -> void:
	_route_city_id = -1
	_route_target_id = -1
	_route_waypoints.clear()
	_route_drag_wp = -1
	_route_drawing = false
	_route_last_point = Vector2.ZERO
	_selected_id = -1
	for ch in _markers_node.get_children():
		if ch.has_method("set_selected"):
			ch.set_selected(false)
	queue_redraw()


# ── draw mode ─────────────────────────────────────────────────

func _start_draw(mpos: Vector2) -> void:
	_drawing = true
	_current_line = [{"x": roundi(mpos.x), "y": roundi(mpos.y)}]
	queue_redraw()
	DebugSystem.print_dbg("[DRAW] started at (%.0f, %.0f)" % [mpos.x, mpos.y])


func _continue_draw(mpos: Vector2) -> void:
	if not _drawing:
		return
	var last = _current_line[-1]
	var dist = Vector2(float(last.x), float(last.y)).distance_to(mpos)
	if dist < _draw_min_dist:
		return
	_current_line.append({"x": roundi(mpos.x), "y": roundi(mpos.y)})
	queue_redraw()


func _finish_draw() -> void:
	_drawing = false
	if _current_line.size() < 2:
		_current_line.clear()
		queue_redraw()
		return
	var lines: Array = GameState.get_data("map.drawn_lines", [])
	lines.append(_current_line.duplicate())
	GameState.set_data("map.drawn_lines", lines)
	_show_feedback("已绘制线条 (%d 个点)" % _current_line.size())
	DebugSystem.print_dbg("[DRAW] finished line with %d points" % _current_line.size())
	_current_line.clear()
	_refresh_lines()
	queue_redraw()


func _cancel_draw() -> void:
	_drawing = false
	_current_line.clear()
	queue_redraw()
	DebugSystem.print_dbg("[DRAW] cancelled")


func _clear_drawn_lines() -> void:
	GameState.set_data("map.drawn_lines", [])
	_show_feedback("已清除所有画线")
	DebugSystem.print_dbg("[DRAW] cleared all lines")
	_refresh_lines()
	queue_redraw()


func _handle_route_drag(mpos: Vector2) -> void:
	if _route_drag_wp < 0 or _route_drag_wp >= _route_waypoints.size():
		return
	_route_waypoints[_route_drag_wp] = {"x": roundi(mpos.x), "y": roundi(mpos.y)}
	_save_route_paths()
	_refresh_lines()
	queue_redraw()


# Draw route editing visuals: waypoints, connection highlight.
func _draw_route_editing() -> void:
	if _mode != Mode.ROUTE:
		return

	# When editing a specific path, show waypoints as large circles
	if _route_target_id >= 0:
		for wp in _route_waypoints:
			var pos := Vector2(float(wp.x), float(wp.y))
			draw_circle(pos, 6.0, Color(1, 0.6, 0, 0.8))
			draw_circle(pos, 4.0, Color(1, 0.8, 0, 0.9))

	# When a city is selected (but not editing), show all waypoints for its connections
	elif _route_city_id >= 0:
		var c = _get_city_data_by_id(_route_city_id)
		if c and c.has("route_paths"):
			var rp = c["route_paths"]
			if rp is Dictionary:
				for target_str in rp:
					var pts = rp[target_str]
					if pts is Array:
						for wp in pts:
							var pos := Vector2(float(wp.x), float(wp.y))
							draw_circle(pos, 3.0, Color(1, 0.6, 0, 0.6))

# ── drawing ──

func _draw() -> void:
	if not edit_mode or not is_inside_tree():
		return
	# In route editing mode, don't draw all connections — just the one being edited
	if _mode == Mode.ROUTE and _route_target_id >= 0:
		_draw_route_connection_line()
	else:
		_draw_selected_highlight()
	_draw_connect_preview()
	_draw_draw_preview()


# Draw ONLY the connection being edited in route mode.
func _draw_route_connection_line() -> void:
	if _route_city_id < 0 or _route_target_id < 0:
		return
	var cmap: Dictionary = {}
	for c in GameState.get_data("city.list", []):
		cmap[int(c.id)] = c
	var a = cmap.get(_route_city_id)
	var b = cmap.get(_route_target_id)
	if not a or not b:
		return
	var p1 := Vector2(float(a.x), float(a.y) - CITY2_H * 0.5)
	var p2 := Vector2(float(b.x), float(b.y) - CITY2_H * 0.5)
	draw_line(p1, p2, Color(1, 0.6, 0, 0.8), 3.0, true)
	# Mark both cities with a highlight ring
	draw_circle(p1 + Vector2(0, 30), 10.0, Color(1, 0.8, 0, 0.3))
	draw_circle(p1 + Vector2(0, 30), 8.0, Color(1, 0.8, 0, 0.3), false, 2.0)
	draw_circle(p2 + Vector2(0, 30), 10.0, Color(1, 0.8, 0, 0.3))
	draw_circle(p2 + Vector2(0, 30), 8.0, Color(1, 0.8, 0, 0.3), false, 2.0)


# Highlight connections from the selected city.
func _draw_selected_highlight() -> void:
	if _selected_id < 0:
		return
	var cities: Array = GameState.get_data("city.list", [])
	var cmap: Dictionary = {}
	for c in cities:
		cmap[int(c.id)] = c

	var sel = cmap.get(_selected_id)
	if not sel or not sel.has("connections"):
		return
	var p1 := Vector2(float(sel.x), float(sel.y) - CITY2_H * 0.5)
	for conn_id in sel.connections:
		var tc = cmap.get(int(conn_id))
		if not tc:
			continue
		var p2 := Vector2(float(tc.x), float(tc.y) - CITY2_H * 0.5)
		draw_line(p1, p2, Color(1, 0.9, 0, 0.6), 3.0, true)


func _draw_connect_preview() -> void:
	if _mode != Mode.CONNECT or _connect_from < 0:
		return
	var cities: Array = GameState.get_data("city.list", [])
	var from_data = null
	for c in cities:
		if int(c.id) == _connect_from:
			from_data = c
			break
	if not from_data:
		return
	var p1 := Vector2(float(from_data.x), float(from_data.y) - CITY2_H * 0.5)
	var mouse := get_local_mouse_position()
	draw_line(p1, mouse, Color(0, 1, 0, 0.5), 1.5, true)


func _draw_draw_preview() -> void:
	if _mode != Mode.DRAW:
		return
	if _current_line.size() == 0:
		return

	# Draw waypoint dots
	for pt in _current_line:
		var pos := Vector2(float(pt.x), float(pt.y))
		draw_circle(pos, 5.0, Color(0.76, 0.62, 0.34, 0.5))
		draw_circle(pos, 3.0, Color(1, 0.9, 0.6, 0.8))

	# Draw smooth spline through waypoints
	if _current_line.size() >= 2:
		var points := PackedVector2Array()
		for pt in _current_line:
			points.append(Vector2(float(pt.x), float(pt.y)))
		var spline := _sample_catmull_rom(points, 8)
		draw_polyline(spline, Color(0.76, 0.62, 0.34, 0.9), 3.0, true)


# ── save / load ─────────────────────────────────────────────────

func _save_json() -> void:
	var cities: Array = GameState.get_data("city.list", [])
	var path: String = "res://data/cities_custom.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json: String = JSON.stringify({"cities": cities}, "\t")
		file.store_string(json)
		file.close()

		# Save drawn_lines separately
		var lines: Array = GameState.get_data("map.drawn_lines", [])
		var lines_path: String = "res://data/drawn_lines.json"
		var lines_file: FileAccess = FileAccess.open(lines_path, FileAccess.WRITE)
		if lines_file:
			var lines_json: String = JSON.stringify({"drawn_lines": lines}, "\t")
			lines_file.store_string(lines_json)
			lines_file.close()

		DebugSystem.print_dbg("[EDIT] saved %d cities to %s" % [cities.size(), path])
		_show_feedback("已保存 %d 个城市!" % cities.size())
	else:
		_show_feedback("保存失败!")
		DebugSystem.print_dbg("[EDIT] ERROR: could not write %s" % path)


func _reload_json() -> void:
	var paths := ["res://data/cities_custom.json", "res://data/cities.json"]
	var file: FileAccess = null
	var used := ""
	for p in paths:
		file = FileAccess.open(p, FileAccess.READ)
		if file:
			used = p
			break
	if not file:
		_show_feedback("加载失败!")
		return
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	file.close()
	if parsed is Dictionary and parsed.has("cities"):
		for ch in _markers_node.get_children():
			ch.queue_free()

		GameState.set_data("city.list", parsed["cities"])

		# Load drawn_lines from separate file
		var lines_path := "res://data/drawn_lines.json"
		var lines_file := FileAccess.open(lines_path, FileAccess.READ)
		if lines_file:
			var lines_text := lines_file.get_as_text()
			var lines_parsed = JSON.parse_string(lines_text)
			lines_file.close()
			if lines_parsed is Dictionary and lines_parsed.has("drawn_lines"):
				GameState.set_data("map.drawn_lines", lines_parsed["drawn_lines"])
			else:
				GameState.set_data("map.drawn_lines", [])
		else:
			GameState.set_data("map.drawn_lines", [])

		for c in parsed["cities"]:
			var marker := preload("res://scenes/map/city_marker.tscn").instantiate()
			_markers_node.add_child(marker)
			marker.setup(c)
			marker.position = Vector2(float(c.x) - MARKER_W * 0.5, float(c.y) - CITY2_H)
			if marker.has_signal("city_clicked"):
				marker.city_clicked.connect(_on_city_clicked)

		_selected_id = -1
		_connect_from = -1
		_drag_id = -1
		_show_feedback("已加载 %d 个城市" % parsed["cities"].size())
		DebugSystem.print_dbg("[EDIT] reloaded %d cities from %s" % [parsed["cities"].size(), used])
	else:
		_show_feedback("数据格式错误!")
	queue_redraw()


# ── connection lines refresh ───────────────────────────────────

func _refresh_lines() -> void:
	var mv := _map_view
	if mv and mv.has_method("refresh_connections"):
		mv.refresh_connections()


# ── feedback ────────────────────────────────────────────────────

func _show_feedback(msg: String) -> void:
	if _feedback_label:
		_feedback_label.text = msg
		_feedback_timer = 2.0


func _process(delta: float) -> void:
	if _feedback_timer > 0:
		_feedback_timer -= delta
		if _feedback_timer <= 0 and _feedback_label:
			_feedback_label.text = ""
