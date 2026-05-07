# version: C3_v1
# last_modified_cycle: C3
# City system test functions.

static func register_tests() -> void:
	var tr = TestRunner
	tr.register_test("city_selection", test_city_selection)
	tr.register_test("city_get_city", test_get_city)
	DebugSystem.print_dbg("[TEST] city tests registered")


static func test_city_selection() -> bool:
	# Ensure city data exists
	var cities: Array = GameState.get_data("city.list", [])
	if cities.is_empty():
		DebugSystem.print_dbg("[TEST] FAIL: no city data loaded")
		return false

	# Create a temporary CityManager
	var cm = Node.new()
	cm.set_script(preload("res://scripts/city/city_manager.gd"))
	var result := true

	# Test: select city 1 (洛阳)
	cm.select_city(1)
	var selected = cm.get_selected()
	if selected.is_empty() or int(selected.get("id", 0)) != 1:
		DebugSystem.print_dbg("[TEST] FAIL: select_city(1) did not select 洛阳")
		result = false
	else:
		DebugSystem.print_dbg("[TEST] PASS: select_city(1) -> %s" % selected.get("name", ""))

	# Test: deselect
	cm.deselect_city()
	selected = cm.get_selected()
	if not selected.is_empty():
		DebugSystem.print_dbg("[TEST] FAIL: deselect_city() did not clear selection")
		result = false
	else:
		DebugSystem.print_dbg("[TEST] PASS: deselect_city() clears selection")

	# Test: select invalid id
	cm.select_city(9999)
	selected = cm.get_selected()
	if not selected.is_empty():
		DebugSystem.print_dbg("[TEST] FAIL: select_city(9999) should not select anything")
		result = false
	else:
		DebugSystem.print_dbg("[TEST] PASS: select_city(9999) handled gracefully")

	cm.queue_free()
	return result


static func test_get_city() -> bool:
	# Ensure city data exists
	var cities: Array = GameState.get_data("city.list", [])
	if cities.is_empty():
		DebugSystem.print_dbg("[TEST] FAIL: no city data loaded")
		return false

	var cm = Node.new()
	cm.set_script(preload("res://scripts/city/city_manager.gd"))
	var result := true

	var city = cm.get_city(1)
	if city.is_empty() or city.get("name") != "洛阳":
		DebugSystem.print_dbg("[TEST] FAIL: get_city(1) did not find 洛阳")
		result = false
	else:
		DebugSystem.print_dbg("[TEST] PASS: get_city(1) -> %s" % city.get("name", ""))

	var invalid = cm.get_city(9999)
	if not invalid.is_empty():
		DebugSystem.print_dbg("[TEST] FAIL: get_city(9999) should return empty")
		result = false
	else:
		DebugSystem.print_dbg("[TEST] PASS: get_city(9999) returns empty")

	cm.queue_free()
	return result
