# version: C2_v6
# last_modified_cycle: C4
# ═══════════════════════════════════════════════════════════════════
# CityMarker — 城市标记（地图上的城市图标）
# ═══════════════════════════════════════════════════════════════════
# 显示内容：
#   - City2.png 城市图标（75×60）
#   - 城市名称标签
#   - 势力旗帜（矩形旗 + 君主姓氏）
# 交互：
#   - 鼠标悬停：高亮边框
#   - 鼠标点击：发射 city_clicked 信号
#   - 选中状态：黄色高亮边框
# ═══════════════════════════════════════════════════════════════════
# 信号：city_clicked(city_id) — 点击城市时发射
# ═══════════════════════════════════════════════════════════════════

extends Control

## 城市被点击信号
# 发射给 CityEditor 或 main.gd 处理选中逻辑
signal city_clicked(city_id: int)

## 当前城市的完整数据（从 cities_custom.json 加载）
var _city_data: Dictionary = {}
## 是否处于选中状态（显示黄色高亮）
var _selected := false
## 鼠标是否悬停在图标上（显示浅色高亮）
var _hovered := false

## 城市图标（City2.png）
@onready var _icon: TextureRect = $CityIcon
## 城市名称标签
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


var FACTION_COLORS := {
	0: Color(1, 0.84, 0),      # 汉室 — 金色
	1: Color(0.76, 0.6, 0.2),  # 黄巾 — 土黄
	2: Color(0.13, 0.55, 0.13), # 刘焉 — 深绿
	3: Color(0.86, 0.08, 0.24), # 孙坚 — 赤红
	4: Color(0.25, 0.41, 0.88), # 刘表 — 靛蓝
	5: Color(1, 0.55, 0),       # 马腾 — 橙色
}

func _draw():
	if _selected:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 0.9, 0, 0.35), false, 2.0)
	if _hovered:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 1, 1, 0.15), true)

	# Draw faction flag above city
	# ── 调旗子位置改下面几个数字 ──
	var FLAG_TOP_Y := -5   # 负=向上, 0=紧贴城市顶
	var FLAG_LEFT := 3      # 正=向右移, 负=向左移
	var FLAG_W := 22
	var FLAG_H := 16

	var fid: int = int(_city_data.get("faction", -1))
	var fcolor: Color = FACTION_COLORS.get(fid, Color(0.5, 0.5, 0.5))
	var cx := size.x / 2.0 + FLAG_LEFT
	var pole_top := Vector2(cx, FLAG_TOP_Y)
	var pole_bot := Vector2(cx, 4)
	draw_line(pole_top, pole_bot, Color(0.4, 0.3, 0.2, 0.8), 2.0)
	var flag_pos := Vector2(cx - FLAG_W / 2.0, FLAG_TOP_Y)
	var flag_rect := Rect2(flag_pos, Vector2(FLAG_W, FLAG_H))
	draw_rect(flag_rect, fcolor, true)
	draw_rect(flag_rect, fcolor.darkened(0.3), false, 1.0)
	var ruler := str(_city_data.get("ruler", ""))
	var ch := ruler.left(1) if ruler.length() > 0 else "?"
	var font := ThemeDB.fallback_font
	var text_y := FLAG_TOP_Y + FLAG_H / 2.0 + 4
	draw_string(font, Vector2(cx - 7, text_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95))


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
