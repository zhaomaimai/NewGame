# version: C4_v1
# last_modified_cycle: C4
# ═══════════════════════════════════════════════════════════════════
# TurnIndicator — 时间指示器（可折叠、可拖动）
# ═══════════════════════════════════════════════════════════════════
# 功能：
#   - 右上角显示一个小"时"按钮
#   - 点击展开完整日期+阶段信息，再点缩回
#   - 按住"时"按钮可拖动到任意位置
# ═══════════════════════════════════════════════════════════════════

extends Control

## 是否处于展开状态（显示完整日期面板）
var _expanded := false
## 折叠/展开切换按钮
var _toggle_btn: Button
## 日期文字标签
var _date_label: Label
## 阶段名称标签
var _phase_label: Label
## 展开后的信息面板容器
var _panel: Panel

## ── 拖动相关 ──
var _dragging := false     # 是否正在拖动中
var _was_drag := false     # 本次鼠标按下是否有过拖动（用于区分点击和拖动）
var _drag_offset := Vector2.ZERO  # 鼠标点与控件位置的偏移量


func _ready() -> void:
	size = Vector2(36, 36)
	position = Vector2(1234, 10)  # top-right
	mouse_filter = MOUSE_FILTER_STOP

	_build_ui()


func _build_ui() -> void:
	# ══ Collapsed: small toggle button ══
	_toggle_btn = Button.new()
	_toggle_btn.name = "ToggleBtn"
	_toggle_btn.text = "时"
	_toggle_btn.size = Vector2(36, 36)
	_toggle_btn.position = Vector2(0, 0)
	_toggle_btn.tooltip_text = "点击查看日期，拖动移动位置"
	_toggle_btn.gui_input.connect(_on_btn_gui_input)
	add_child(_toggle_btn)

	# ══ Expanded: panel with labels (hidden by default) ══
	_panel = Panel.new()
	_panel.name = "InfoPanel"
	_panel.size = Vector2(260, 56)
	_panel.position = Vector2(-224, 40)  # extends left from button
	_panel.visible = false
	add_child(_panel)

	_date_label = Label.new()
	_date_label.name = "DateLabel"
	_date_label.position = Vector2(8, 4)
	_date_label.size = Vector2(244, 26)
	_date_label.add_theme_font_size_override("font_size", 18)
	_date_label.add_theme_color_override("font_color", Color(1, 1, 0.8, 0.95))
	_panel.add_child(_date_label)

	_phase_label = Label.new()
	_phase_label.name = "PhaseLabel"
	_phase_label.position = Vector2(8, 30)
	_phase_label.size = Vector2(244, 22)
	_phase_label.add_theme_font_size_override("font_size", 14)
	_phase_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1, 0.8))
	_panel.add_child(_phase_label)


func _toggle() -> void:
	_expanded = !_expanded
	_panel.visible = _expanded
	if _expanded:
		size = Vector2(260, 96)
	else:
		size = Vector2(36, 36)


func _on_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_was_drag = false
			_drag_offset = get_global_mouse_position() - position
		elif _dragging:
			# If we didn't actually drag, treat as click → toggle
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


func update_date(date_string: String) -> void:
	_date_label.text = date_string
	_toggle_btn.text = date_string.left(4) if date_string.length() >= 4 else "时"


func update_phase(phase_name: String) -> void:
	_phase_label.text = phase_name
