# version: C5_v1
# last_modified_cycle: C5
# ═══════════════════════════════════════════════════════════════════
# Test_Internal — 内政系统单元测试
# ═══════════════════════════════════════════════════════════════════
# 测试用例：
#   1. test_internal_agriculture — 执行农业开发指令
#   2. test_internal_round_limit — 验证每城每回合3次上限
# ═══════════════════════════════════════════════════════════════════

static func register_tests() -> void:
	TestRunner.register_test("test_internal_agriculture", test_internal_agriculture)
	TestRunner.register_test("test_internal_round_limit", test_internal_round_limit)
	DebugSystem.print_dbg("[TEST] internal tests registered")


static func test_internal_agriculture() -> bool:
	var mgr = preload("res://scripts/internal/internal_manager.gd").new()

	# 创建测试城市
	var city = {
		"id": 999, "name": "测试城",
		"agriculture": 80, "commerce": 80,
		"public_order": 65, "training": 50,
		"gold": 1000, "food": 3000,
		"population": 50000, "soldiers": 5000,
		"faction": 0
	}
	var cities := [city]
	GameState.set_data("city.list", cities)
	GameState.set_data("city.internal_count", {})

	var result := mgr.execute_command(999, "agriculture")
	assert(result.success, "Agriculture command should succeed")
	assert(result.changes.has("agriculture"), "Should have agriculture change")
	assert(result.changes.get("gold", 0) == -30, "Should cost 30 gold")

	# Verify data was written
	var updated = GameState.get_data("city.list", [])
	assert(updated[0].agriculture > 80, "Agriculture should have increased")

	DebugSystem.print_dbg("[TEST] test_internal_agriculture PASSED")
	return true


static func test_internal_round_limit() -> bool:
	var mgr = preload("res://scripts/internal/internal_manager.gd").new()

	var cities := [{
		"id": 998, "name": "测试城2",
		"agriculture": 80, "commerce": 80,
		"public_order": 65, "training": 50,
		"gold": 9999, "food": 9999,
		"population": 50000, "soldiers": 5000,
		"faction": 0
	}]
	GameState.set_data("city.list", cities)
	GameState.set_data("city.internal_count", {})

	# Execute 3 commands (should all succeed)
	for i in range(3):
		var r := mgr.execute_command(998, "agriculture")
		assert(r.success, "Command %d should succeed" % i)

	# 4th should fail
	var r4 := mgr.execute_command(998, "agriculture")
	assert(not r4.success, "4th command should fail due to limit")

	DebugSystem.print_dbg("[TEST] test_internal_round_limit PASSED")
	return true
