# version: C4_v1
# last_modified_cycle: C4
# ═══════════════════════════════════════════════════════════════════
# EndTurnButton — 结束回合按钮（可拖动）
# ═══════════════════════════════════════════════════════════════════
# 功能：
#   - 屏幕右下角显示"结束回合"按钮
#   - 点击后触发 TurnManager 的阶段推进流程
#   - 按住按钮可拖动到任意位置
#   - 阶段推进过程中按钮自动禁用，完成后重新启用
# ═══════════════════════════════════════════════════════════════════
# 信号：end_turn_pressed — 点击时发射，由 main.gd 连接至 TurnManager
# ═══════════════════════════════════════════════════════════════════

extends Button

## 结束回合信号
# 按钮被点击（非拖动）时发射
# 由 main.gd 连接至 TurnManager.start_end_turn_flow
signal end_turn_pressed()

## ── 拖动控制 ──
var _dragging := false       # 是否正在拖动按钮
var _was_drag := false       # 本次操作是否有拖动动作
var _drag_offset := Vector2.ZERO  # 鼠标与按钮位置的偏移量


func _ready() -> void:
	text = "结束回合"
	position = Vector2(1120, 880)
	size = Vector2(140, 50)
	add_theme_font_size_override("font_size", 18)

	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_was_drag = false
			_drag_offset = get_global_mouse_position() - position
		elif _dragging:
			if not _was_drag:
				# Genuine click → trigger end turn
				disabled = true
				end_turn_pressed.emit()
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


func reenable() -> void:
	disabled = false
