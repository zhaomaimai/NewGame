# version: C4_v1
# last_modified_cycle: C4
# ═══════════════════════════════════════════════════════════════════
# DateManager — 日期管理器
# ═══════════════════════════════════════════════════════════════════
# 功能：管理游戏内年/月/旬（上/中/下旬）的时间推进
# 数据存储：GameState.get_data/set_data("turn.date", {year, month, turn})
# 起始日期：184年1月上旬
# 时间单位：1个月=3旬, 1年=12个月
# 游戏循环：每旬走完所有阶段后由 TurnManager 调用 advance_turn()
# ═══════════════════════════════════════════════════════════════════
# 依赖：GameState, DebugSystem
# 信号：date_changed(year, month, turn) — 每次推进时发射
# ═══════════════════════════════════════════════════════════════════

extends Node

## 日期推进信号
# 每次 advance_turn() 被调用时发射，通知 UI 更新日期显示
# @param year:  推进后的年份
# @param month: 推进后的月份 (1-12)
# @param turn:  推进后的旬 (1=上旬, 2=中旬, 3=下旬)
signal date_changed(year: int, month: int, turn: int)

## 每月包含的旬数（上/中/下旬）
const TURNS_PER_MONTH := 3
## 每年包含的月份数
const MONTHS_PER_YEAR := 12


func _ready() -> void:
	_init_date()


func _init_date() -> void:
	var date = GameState.get_data("turn.date", null)
	if date == null:
		date = {"year": 184, "month": 1, "turn": 1}
		GameState.set_data("turn.date", date)
	DebugSystem.print_dbg("[DATE] initialized to %s" % get_date_string())


func get_date() -> Dictionary:
	return GameState.get_data("turn.date", {"year": 184, "month": 1, "turn": 1})


func advance_turn() -> void:
	var date = get_date()
	date.turn += 1
	if date.turn > TURNS_PER_MONTH:
		date.turn = 1
		date.month += 1
		if date.month > MONTHS_PER_YEAR:
			date.month = 1
			date.year += 1
	GameState.set_data("turn.date", date)
	date_changed.emit(date.year, date.month, date.turn)
	DebugSystem.print_dbg("[DATE] advanced to %s" % get_date_string())


func get_date_string() -> String:
	var date = get_date()
	var turn_names = ["", "上旬", "中旬", "下旬"]
	return "%d年%d月%s" % [date.year, date.month, turn_names[date.turn]]


func get_year() -> int:
	return get_date().year


func get_month() -> int:
	return get_date().month


func get_turn() -> int:
	return get_date().turn


# Returns true if the previous advance_turn() crossed a month boundary
func did_month_just_change() -> bool:
	var date = get_date()
	return date.turn == 1
