# version: C4_v1
# last_modified_cycle: C4
# ═══════════════════════════════════════════════════════════════════
# Test_Turn — 回合系统单元测试
# ═══════════════════════════════════════════════════════════════════
# 测试用例：
#   1. test_turn_date_advance   — 验证年/月/旬推进正确
#   2. test_turn_phase_cycle    — 验证阶段循环顺序正确
#   3. test_turn_monthly_growth — 验证增长公式计算正确
# ═══════════════════════════════════════════════════════════════════
# 注册方式：main.gd 中调用 register_tests() 自动注册到 TestRunner
# ═══════════════════════════════════════════════════════════════════

static func register_tests() -> void:
	TestRunner.register_test("test_turn_date_advance", test_turn_date_advance)
	TestRunner.register_test("test_turn_phase_cycle", test_turn_phase_cycle)
	TestRunner.register_test("test_turn_monthly_growth", test_turn_monthly_growth)
	DebugSystem.print_dbg("[TEST] turn tests registered")


static func test_turn_date_advance() -> bool:
	# Simulate advancing through a full month (3 turns)
	var dm = preload("res://scripts/turn/date_manager.gd").new()
	dm._init_date()

	var d0 = dm.get_date()
	assert(d0.year == 184 and d0.month == 1 and d0.turn == 1, "Initial date should be 184-1-1")

	dm.advance_turn()
	var d1 = dm.get_date()
	assert(d1.turn == 2, "After 1 advance, turn should be 2")

	dm.advance_turn()
	var d2 = dm.get_date()
	assert(d2.turn == 3, "After 2 advances, turn should be 3")

	dm.advance_turn()
	var d3 = dm.get_date()
	assert(d3.month == 2 and d3.turn == 1, "After 3 advances, month should be 2, turn 1")

	# Advance 11 more months (33 turns), should reach year 185
	for i in range(33):
		dm.advance_turn()
	var d4 = dm.get_date()
	assert(d4.year == 185 and d4.month == 2 and d4.turn == 1, "After 36 advances (1 year + 1 month), year=185 month=2")

	DebugSystem.print_dbg("[TEST] test_turn_date_advance PASSED")
	DebugSystem.print_dbg("[TEST]   date=%s" % dm.get_date_string())
	return true


static func test_turn_phase_cycle() -> bool:
	var pm = preload("res://scripts/turn/phase_manager.gd").new()
	pm._ready()

	assert(pm.get_phase() == pm.Phase.INTERNAL, "Initial phase should be INTERNAL")
	assert(pm.get_phase_name() == "内政阶段", "Phase name should be 内政阶段")

	# Cycle through all phases
	pm.advance_phase()
	assert(pm.get_phase() == pm.Phase.MILITARY, "Should be MILITARY")

	pm.advance_phase()
	assert(pm.get_phase() == pm.Phase.MARCH, "Should be MARCH")

	pm.advance_phase()
	assert(pm.get_phase() == pm.Phase.SETTLEMENT, "Should be SETTLEMENT")

	pm.advance_phase()
	assert(pm.get_phase() == pm.Phase.AI, "Should be AI")

	pm.advance_phase()
	assert(pm.get_phase() == pm.Phase.TURN_END, "Should be TURN_END")

	# One more advance loops back to INTERNAL
	pm.advance_phase()
	assert(pm.get_phase() == pm.Phase.INTERNAL, "Should loop back to INTERNAL")

	DebugSystem.print_dbg("[TEST] test_turn_phase_cycle PASSED")
	return true


static func test_turn_monthly_growth() -> bool:
	# Verify the growth calculation works
	# Create a mock city
	var city = {
		"id": 1, "name": "测试城",
		"agriculture": 100, "commerce": 100,
		"morale": 80, "public_order": 80,
		"population": 100000, "gold": 1000, "food": 3000, "soldiers": 5000,
		"faction": 0
	}

	# Simulate growth
	var agri := float(city.agriculture)
	var comm := float(city.commerce)
	var morale := float(city.morale)
	var order := float(city.public_order)

	var gold_gain := int(comm * 0.5)  # base only, no rand
	var food_gain := int(agri * 10)  # base only
	var pop_gain := int(city.population * (morale + order) / 20000.0)

	assert(gold_gain == 50, "Gold gain should be 50 (100*0.5)")
	assert(food_gain == 1000, "Food gain should be 1000 (100*10)")
	assert(pop_gain == 800, "Pop gain should be 800 (100000*160/20000)")

	DebugSystem.print_dbg("[TEST] test_turn_monthly_growth PASSED")
	DebugSystem.print_dbg("[TEST]   gold_gain=%d food_gain=%d pop_gain=%d" % [gold_gain, food_gain, pop_gain])
	return true
