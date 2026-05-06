# version: C2_v6
# last_modified_cycle: C2
# City editor: add/connect/delete/rename cities. Press E to toggle.

extends Control

enum Mode { SELECT, ADD, CONNECT, DELETE, RENAME }

var edit_mode := false
var _mode := Mode.SELECT
var _selected_id := -1
var _drag_id := -1
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO
var _connect_from := -1

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
	_toolbar.size = Vector2(530, 56)
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

	# Feedback label
	_feedback_label = Label.new()
	_feedback_label.position = Vector2(4, 32)
	_feedback_label.size = Vector2(520, 20)
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
	_mode = mode
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
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		_toggle_edit()
		get_viewport().set_input_as_handled()
		return

	if not edit_mode or not is_inside_tree():
		return

	if event is InputEventMouseButton \
		and not event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and _drag_id >= 0:
		_end_drag()
		return

	if event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

	if event is InputEventMouseMotion and _drag_id >= 0:
		_handle_drag(event.position)


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

		Mode.RENAME:
			var cd := _get_city_data_by_id(city_id)
			if cd:
				_show_rename_popup(city_id, str(cd.name))


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


# ── drawing ─────────────────────────────────────────────────────

func _draw() -> void:
	if not edit_mode or not is_inside_tree():
		return
	_draw_connections()
	_draw_connect_preview()


func _draw_connections() -> void:
	var cities: Array = GameState.get_data("city.list", [])
	if cities.is_empty():
		return

	var cmap: Dictionary = {}
	for c in cities:
		cmap[int(c.id)] = c

	for c in cities:
		var cid := int(c.id)
		if not c.has("connections"):
			continue
		var p1 := Vector2(float(c.x), float(c.y) - CITY2_H * 0.5)
		var is_sel := cid == _selected_id

		for conn_id in c.connections:
			var conn := int(conn_id)
			if not cmap.has(conn):
				continue
			var tc: Dictionary = cmap[conn]
			var p2 := Vector2(float(tc.x), float(tc.y) - CITY2_H * 0.5)
			var col := Color(1, 1, 1, 0.35) if not is_sel else Color(1, 0.9, 0, 0.7)
			var w := 1.5 if not is_sel else 3.0
			draw_line(p1, p2, col, w, true)


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


# ── save / load ─────────────────────────────────────────────────

func _save_json() -> void:
	var cities: Array = GameState.get_data("city.list", [])
	var data: Dictionary = {"cities": cities}
	var path: String = "res://data/cities_custom.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json: String = JSON.stringify(data, "\t")
		file.store_string(json)
		file.close()
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
