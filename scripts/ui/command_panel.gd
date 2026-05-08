# version: C5_v1
# last_modified_cycle: C5
# CommandPanel — 整合命令面板（可折叠/可拖动）
# 整合：时间显示 + 内政命令 + 结束回合
# 折叠时显示"令"按钮，展开时显示完整面板

extends Panel

signal end_turn_pressed()
signal internal_done()

# 状态
var _expanded := false
var _current_tab := 0
var _city_data: Dictionary = {}
var _internal_mgr: Node = null
var _turn_manager: Node = null
var _trade_popup_open := false

# 拖动
var _dragging := false
var _was_drag := false
var _drag_offset := Vector2.ZERO

# 子控件
var _toggle_btn: Button
var _info_label: Label
var _phase_label: Label
var _tab_btns: Array = []
var _content: Panel
var _val_labels: Dictionary = {}
var _cmd_btns: Dictionary = {}
var _remain_label: Label
var _feedback_label: Label
var _feedback_timer: float = 0.0

const CMD_INFO := {
	"agriculture": {"label": "农业开发", "icon": "Agri"},
	"commerce":    {"label": "商业开发", "icon": "Comm"},
	"security":    {"label": "治安向上", "icon": "Secu"},
	"recruit":     {"label": "士兵募征", "icon": "Recr"},
	"train":       {"label": "士兵训练", "icon": "Train"},
	"trade":       {"label": "粮食买卖", "icon": "Trade"},
}


func _ready() -> void:
	size = Vector2(36, 36)
	position = Vector2(10, 10)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()


func set_internal_manager(mgr: Node) -> void:
	_internal_mgr = mgr


func set_turn_manager(mgr: Node) -> void:
	_turn_manager = mgr


func _build_ui() -> void:
	_toggle_btn = Button.new()
	_toggle_btn.text = "令"
	_toggle_btn.size = Vector2(36, 36)
	_toggle_btn.tooltip_text = "点击展开命令面板"
	_toggle_btn.gui_input.connect(_on_toggle_gui_input)
	add_child(_toggle_btn)

	_content = Panel.new()
	_content.name = "ContentPanel"
	_content.size = Vector2(320, 480)
	_content.position = Vector2(0, 40)
	_content.visible = false
	add_child(_content)
	_build_expanded_ui()


func _build_expanded_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.18, 0.22, 0.95)
	bg.size = Vector2(320, 480)
	_content.add_child(bg)

	var handle := ColorRect.new()
	handle.color = Color(0.1, 0.12, 0.16, 0.95)
	handle.size = Vector2(320, 28)
	handle.gui_input.connect(_on_handle_gui_input)
	_content.add_child(handle)

	var title := Label.new()
	title.text = "命令面板"
	title.position = Vector2(8, 4)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.7, 0.85, 1))
	handle.add_child(title)

	var collapse_btn := Button.new()
	collapse_btn.text = "X"
	collapse_btn.size = Vector2(24, 24)
	collapse_btn.position = Vector2(290, 2)
	collapse_btn.pressed.connect(_toggle)
	handle.add_child(collapse_btn)

	_info_label = Label.new()
	_info_label.position = Vector2(8, 32)
	_info_label.size = Vector2(304, 20)
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	_content.add_child(_info_label)

	_phase_label = Label.new()
	_phase_label.position = Vector2(8, 50)
	_phase_label.size = Vector2(304, 16)
	_phase_label.add_theme_font_size_override("font_size", 11)
	_phase_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1))
	_content.add_child(_phase_label)

	var tab_names := ["内政", "军事", "行军"]
	for i in 3:
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.size = Vector2(100, 26)
		btn.position = Vector2(8 + i * 104, 74)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		_content.add_child(btn)
		_tab_btns.append(btn)

	_build_internal_tab()

	var end_btn := Button.new()
	end_btn.text = "结束回合"
	end_btn.size = Vector2(140, 36)
	end_btn.position = Vector2(90, 436)
	end_btn.add_theme_font_size_override("font_size", 16)
	end_btn.pressed.connect(_on_end_turn)
	_content.add_child(end_btn)


func _build_internal_tab() -> void:
	var vy := 106
	var names := {
		"agriculture": "农业", "commerce": "商业",
		"public_order": "治安", "training": "训练",
		"population": "人口", "soldiers": "士兵",
		"gold": "金", "food": "粮"
	}
	var left := ["agriculture", "public_order", "population", "gold"]
	var right := ["commerce", "training", "soldiers", "food"]
	for i in 4:
		for col in [0, 1]:
			var f: String = left[i] if col == 0 else right[i]
			var lbl := Label.new()
			lbl.text = "%s: --" % names[f]
			lbl.position = Vector2(8 + col * 152, vy + i * 18)
			lbl.size = Vector2(145, 16)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			_content.add_child(lbl)
			_val_labels[f] = lbl
	vy += 78

	var sep := HSeparator.new()
	sep.position = Vector2(8, vy)
	sep.size = Vector2(304, 4)
	_content.add_child(sep)
	vy += 8

	for cmd in CMD_INFO:
		var info = CMD_INFO[cmd]
		var btn := Button.new()
		btn.text = info.label
		btn.size = Vector2(145, 26)
		btn.position = Vector2(8 if _cmd_btns.size() % 2 == 0 else 167, vy)
		btn.pressed.connect(_on_cmd.bind(cmd))
		_content.add_child(btn)
		_cmd_btns[cmd] = btn
		if _cmd_btns.size() % 2 == 0:
			vy += 28
	vy += 4

	_remain_label = Label.new()
	_remain_label.position = Vector2(8, vy)
	_remain_label.size = Vector2(200, 18)
	_remain_label.add_theme_font_size_override("font_size", 12)
	_remain_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	_content.add_child(_remain_label)

	_feedback_label = Label.new()
	_feedback_label.position = Vector2(8, vy + 20)
	_feedback_label.size = Vector2(304, 18)
	_feedback_label.add_theme_font_size_override("font_size", 11)
	_feedback_label.add_theme_color_override("font_color", Color(0, 1, 0))
	_content.add_child(_feedback_label)


# 折叠/展开
func _toggle() -> void:
	_expanded = !_expanded
	_content.visible = _expanded
	if _expanded:
		size = Vector2(320, 520)
	else:
		size = Vector2(36, 36)
		if _feedback_label:
			_feedback_label.text = ""


func _on_toggle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_was_drag = false
			_drag_offset = get_global_mouse_position() - position
		elif _dragging:
			if not _was_drag:
				_toggle()
			_dragging = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _dragging:
		var new_pos := get_global_mouse_position() - _drag_offset
		var dist := (get_global_mouse_position() - (_drag_offset + position)).length()
		if dist > 5.0:
			_was_drag = true
		new_pos.x = maxi(0, new_pos.x)
		new_pos.y = maxi(0, new_pos.y)
		position = new_pos


func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - position
		else:
			_dragging = false
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _dragging:
		var new_pos := get_global_mouse_position() - _drag_offset
		new_pos.x = maxi(0, new_pos.x)
		new_pos.y = maxi(0, new_pos.y)
		position = new_pos


# Tab切换
func _on_tab_pressed(tab: int) -> void:
	_current_tab = tab
	for i in 3:
		_tab_btns[i].button_pressed = (i == tab)
	_refresh_tab_visibility()


func _refresh_tab_visibility() -> void:
	var vis := (_current_tab == 0)
	for lbl in _val_labels.values():
		lbl.visible = vis
	for btn in _cmd_btns.values():
		btn.visible = vis
	if _remain_label: _remain_label.visible = vis
	if _feedback_label: _feedback_label.visible = vis


# 更新数据
func update_date(date_string: String) -> void:
	if _info_label:
		_info_label.text = date_string
	_toggle_btn.text = date_string.left(4) if date_string.length() >= 4 else "令"


func update_phase(phase_name: String) -> void:
	if _phase_label:
		_phase_label.text = phase_name


func show_city(city_data: Dictionary) -> void:
	_city_data = city_data
	_update_values()
	_update_buttons()
	_current_tab = 0
	_on_tab_pressed(0)


func hide_panel() -> void:
	_city_data = {}
	if _feedback_label:
		_feedback_label.text = ""
	# Close trade popup if open
	if _trade_popup_open:
		_close_trade_popup()


func refresh() -> void:
	if not _city_data.is_empty():
		_update_values()
		_update_buttons()


func _update_values() -> void:
	if _city_data.is_empty():
		return
	var names := {
		"agriculture": "农业", "commerce": "商业",
		"public_order": "治安", "training": "训练",
		"population": "人口", "soldiers": "士兵",
		"gold": "金", "food": "粮"
	}
	for f in names:
		var lbl = _val_labels.get(f)
		if lbl:
			var val: int = int(_city_data.get(f, 0))
			lbl.text = "%s:%d" % [names[f], val]


func _update_buttons() -> void:
	if _city_data.is_empty():
		return
	var remaining := 3
	if _internal_mgr and _internal_mgr.has_method("get_remaining_commands"):
		var cid: int = int(_city_data.get("id", -1))
		remaining = _internal_mgr.get_remaining_commands(cid)
	if _remain_label:
		_remain_label.text = "剩余: %d/3" % remaining
	for cmd in _cmd_btns:
		_cmd_btns[cmd].disabled = (remaining <= 0)


# 指令点击
func _on_cmd(cmd_type: String) -> void:
	if cmd_type == "trade":
		if _trade_popup_open:
			_close_trade_popup()
		else:
			_show_trade_popup()
		return
	if _city_data.is_empty() or not _internal_mgr:
		return
	if not _internal_mgr.has_method("execute_command"):
		return

	var cid: int = int(_city_data.get("id", -1))
	var result: Dictionary = _internal_mgr.execute_command(cid, cmd_type)

	if result.get("success"):
		var changes: Dictionary = result.get("changes", {})
		for field in changes:
			var delta := int(changes[field])
			if field == "gold":
				_city_data[field] = maxi(0, int(_city_data.get(field, 0)) - abs(delta))
			else:
				_city_data[field] = maxi(0, int(_city_data.get(field, 0)) + delta)
		_update_values()
		_update_buttons()

	if _feedback_label:
		_feedback_label.text = result.get("message", "")
		_feedback_timer = 3.0


# 交易弹窗
func _show_trade_popup() -> void:
	_trade_popup_open = true
	var popup := Panel.new()
	popup.name = "TradePopup"
	popup.size = Vector2(240, 120)
	popup.position = Vector2(40, 60)
	_content.add_child(popup)

	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.18, 0.24, 0.95)
	bg.size = Vector2(240, 120)
	popup.add_child(bg)

	var label := Label.new()
	label.text = "选择交易方式"
	label.position = Vector2(8, 6)
	label.size = Vector2(224, 20)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 1))
	popup.add_child(label)

	var buy_btn := Button.new()
	buy_btn.text = "买粮 (100金 300粮)"
	buy_btn.size = Vector2(220, 30)
	buy_btn.position = Vector2(10, 32)
	buy_btn.pressed.connect(_on_trade_choice.bind("trade_buy", popup))
	popup.add_child(buy_btn)

	var sell_btn := Button.new()
	sell_btn.text = "卖粮 (500粮 166金)"
	sell_btn.size = Vector2(220, 30)
	sell_btn.position = Vector2(10, 68)
	sell_btn.pressed.connect(_on_trade_choice.bind("trade_sell", popup))
	popup.add_child(sell_btn)


func _close_trade_popup() -> void:
	var p = _content.get_node_or_null("TradePopup")
	if p:
		p.queue_free()
	_trade_popup_open = false


func _on_trade_choice(cmd_type: String, popup: Panel) -> void:
	# Execute trade but keep popup open for repeated trades
	_on_cmd(cmd_type)


func _on_end_turn() -> void:
	end_turn_pressed.emit()


func _process(delta: float) -> void:
	if _feedback_timer > 0:
		_feedback_timer -= delta
		if _feedback_timer <= 0 and _feedback_label:
			_feedback_label.text = ""
