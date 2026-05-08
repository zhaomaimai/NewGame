# version: C4_v1
# last_modified_cycle: C4
# ═══════════════════════════════════════════════════════════════════
# TurnManager - Turn System Controller
# ═══════════════════════════════════════════════════════════════════
# Responsibilities：
#   1. Create and manage DateManager + PhaseManager
#   2. Handle end-turn flow: advance phases with 0.3s delay
#   3. Settlement phase: monthly growth (gold/food/population)
#   4. AI phase: non-player city bonus growth
# ═══════════════════════════════════════════════════════════════════
# Phase cycle (0.3s delay)：
#   INTERNAL -> MILITARY -> MARCH -> SETTLEMENT -> AI -> TURN_END -> next turn
# ═══════════════════════════════════════════════════════════════════
# Deps: DateManager, PhaseManager, RandomManager, GameState, DebugSystem
# ═══════════════════════════════════════════════════════════════════

extends Node

## DateManager reference (created in _ready)
var date_manager
## PhaseManager reference (created in _ready)
var phase_manager
## TurnIndicator UI ref (injected by main.gd)
var turn_indicator: Control
## EndTurnButton ref (injected by main.gd)
var end_turn_button: Button

## Is phase advancement in progress (prevents double-click)
var _advancing := false
## Food harvest months: Mar, Jul, Sep
var _growth_months := {3: true, 7: true, 9: true}


func _ready() -> void:
	# Create DateManager
	date_manager = preload("res://scripts/turn/date_manager.gd").new()
	date_manager.name = "DateManager"
	add_child(date_manager)

	# Create PhaseManager
	phase_manager = preload("res://scripts/turn/phase_manager.gd").new()
	phase_manager.name = "PhaseManager"
	phase_manager.set_turn_manager(self)
	add_child(phase_manager)

	# Connect phase changes to indicator
	phase_manager.phase_changed.connect(_on_phase_changed)

	DebugSystem.print_dbg("[TURN] turn_manager initialized")


func _on_phase_changed(phase_name: String) -> void:
	if turn_indicator:
		turn_indicator.update_phase(phase_name)


func start_end_turn_flow() -> void:
	if _advancing:
		return
	_advancing = true
	DebugSystem.print_dbg("[TURN] end turn flow started")
	_advance_through_phases()


## Core loop: advance from current phase to TURN_END, 0.3s per phase
# 到达 TURN_END 后自动：
#   1. Advance date (DateManager.advance_turn)
#   2. Reset phase to INTERNAL
#   3. Reset internal command count
#   4. Re-enable end-turn button
func _advance_through_phases() -> void:
	while phase_manager.current_phase < 5:  # TURN_END = 5
		phase_manager.advance_phase()
		await _handle_phase_actions()
		await get_tree().create_timer(0.3).timeout

	# Now at TURN_END — advance date and restart
	phase_manager.advance_phase()  # TURN_END → INTERNAL (next turn)
	date_manager.advance_turn()

	# Update indicator
	if turn_indicator:
		turn_indicator.update_date(date_manager.get_date_string())

	# Reset internal command counts for new turn
	GameState.set_data("city.internal_count", {})

	_advancing = false
	if end_turn_button:
		end_turn_button.reenable()

	DebugSystem.print_dbg("[TURN] end turn flow completed, date=%s" % date_manager.get_date_string())


# Execute logic specific to each phase
## Execute phase-specific logic
# 阶段-动作映射：
#   SETTLEMENT (3) → 执行月度增长（金/粮/人口）
#   AI (4) → 非玩家城市 AI 增长
#   TURN_END (5) → 不处理，由 _advance_through_phases 统一管理
func _handle_phase_actions() -> void:
	match phase_manager.current_phase:
		3:  # SETTLEMENT
			_apply_monthly_growth()
		4:  # AI
			_apply_ai_growth()
		5:  # TURN_END
			# Date advancement happens after this phase
			pass


func _apply_monthly_growth() -> void:
	# Only apply if month just changed (first turn of a new month)
	if not date_manager.did_month_just_change():
		return

	var cities: Array = GameState.get_data("city.list", [])
	var month: int = date_manager.get_month()
	var is_food_month := _growth_months.has(month)
	var changed := false

	for city in cities:
		var agri := float(city.get("agriculture", 80))
		var comm := float(city.get("commerce", 80))
		var morale := float(city.get("morale", 70))
		var order := float(city.get("public_order", 65))

		# Gold: commerce × 0.5 + rand(10)
		var gold_gain := int(comm * 0.5 + RandomManager.randi_range(1, 10))
		city.gold = mini(int(city.get("gold", 0)) + gold_gain, 3000000)

		# Soldier food consumption: 0.2 food per soldier per month
		var soldiers := int(city.get("soldiers", 0))
		var food_cost := int(soldiers * 0.2)
		city.food = maxi(0, int(city.get("food", 0)) - food_cost)

		# Food: agriculture × 10 + rand(20) — only in 3月/7月/9月
		if is_food_month:
			var food_gain := int(agri * 10 + RandomManager.randi_range(1, 20))
			city.food = mini(int(city.get("food", 0)) + food_gain, 3000000)

		# Population: pop × (morale + public_order) / 20000 + rand(50)
		var pop_gain := int(city.get("population", 50000) * (morale + order) / 20000.0 + RandomManager.randi_range(1, 50))
		city.population = mini(int(city.get("population", 50000)) + pop_gain, 3000000)

		changed = true

	if changed:
		DebugSystem.print_dbg("[TURN] monthly growth applied for month=%d" % month)


func _apply_ai_growth() -> void:
	# In C4, AI cities get additional growth at half efficiency
	var cities: Array = GameState.get_data("city.list", [])
	var player_faction := 0
	var changed := false

	for city in cities:
		var fid := int(city.get("faction", -1))
		if fid == player_faction:
			continue  # skip player cities

		# AI bonus at 50% efficiency
		var agri := float(city.get("agriculture", 80))
		var comm := float(city.get("commerce", 80))

		var gold_bonus := int(comm * 0.25 + RandomManager.randi_range(1, 5))
		city.gold = mini(int(city.get("gold", 0)) + gold_bonus, 3000000)

		var month: int = date_manager.get_month()
		if _growth_months.has(month):
			var food_bonus := int(agri * 5 + RandomManager.randi_range(1, 10))
			city.food = mini(int(city.get("food", 0)) + food_bonus, 3000000)

		var soldier_bonus := RandomManager.randi_range(50, 200)
		city.soldiers = mini(int(city.get("soldiers", 5000)) + soldier_bonus, 999999)

		changed = true

	if changed:
		DebugSystem.print_dbg("[TURN] AI growth applied for non-player cities")
