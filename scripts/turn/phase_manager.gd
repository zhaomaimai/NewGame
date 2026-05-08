# version: C4_v1
# last_modified_cycle: C4
# ═════════════════════════════════════════════════════════════════
# PhaseManager — 阶段管理器
# ═════════════════════════════════════════════════════════════════
# 功能：控制每季的阶段循环，管理阶段转换逻辑
# 阶段顺序：内政 → 军事 → 行军 → 结算 → AI → TURN_END → 下一季(重复)
# 数据存储：GameState.set_data("turn.phase", 阶段编号)
# 每次转换发射 phase_changed(阶段名) 信号
# ═════════════════════════════════════════════════════════════════
# 依赖：GameState, DebugSystem
# 信号：phase_changed(phase_name) — 每次阶段转换时发射
# ═════════════════════════════════════════════════════════════════

extends Node
class_name PhaseManager

## 阶段变更信号
# 每次 advance_phase() 被调用时发射，通知 UI 更新阶段显示
# @param phase_name: 当前阶段的中文名称
signal phase_changed(phase_name: String)

enum Phase {
	INTERNAL,    # 内政阶段 — player can issue internal commands
	MILITARY,    # 军事阶段 — player can manage armies
	MARCH,       # 行军阶段 — marching armies move
	SETTLEMENT,  # 结算阶段 — monthly growth calculation
	AI,          # AI阶段 — non-player cities grow, AI decisions
	TURN_END     # 回合结束 — advance to next turn
}

const PHASE_NAMES := {
	Phase.INTERNAL: "内政阶段",
	Phase.MILITARY: "军事阶段",
	Phase.MARCH: "行军阶段",
	Phase.SETTLEMENT: "结算阶段",
	Phase.AI: "AI阶段",
	Phase.TURN_END: "回合结束",
}

var current_phase: int = Phase.INTERNAL
var _turn_ref: Node = null  # reference to TurnManager (parent)


func _ready() -> void:
	GameState.set_data("turn.phase", current_phase)
	DebugSystem.print_dbg("[PHASE] initialized to %s" % PHASE_NAMES[current_phase])


func set_turn_manager(turn_node: Node) -> void:
	_turn_ref = turn_node


func get_phase() -> int:
	return current_phase


func get_phase_name() -> String:
	return PHASE_NAMES.get(current_phase, "未知")


func advance_phase() -> void:
	current_phase += 1
	# Skip MILITARY(1) and MARCH(2) — not yet implemented
	if current_phase == Phase.MILITARY or current_phase == Phase.MARCH:
		current_phase = Phase.SETTLEMENT
	if current_phase > Phase.TURN_END:
		current_phase = Phase.INTERNAL

	GameState.set_data("turn.phase", current_phase)
	phase_changed.emit(PHASE_NAMES[current_phase])
	DebugSystem.print_dbg("[PHASE] changed to %s" % PHASE_NAMES[current_phase])


func set_phase(phase: int) -> void:
	current_phase = clamp(phase, Phase.INTERNAL, Phase.TURN_END)
	GameState.set_data("turn.phase", current_phase)
	phase_changed.emit(PHASE_NAMES[current_phase])


func is_player_turn() -> bool:
	return current_phase == Phase.INTERNAL or current_phase == Phase.MILITARY
