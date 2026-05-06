# version: C0_v1
# last_modified_cycle: C0

extends Node

var tests: Array[Callable] = []
var _names: Array[String] = []

func register_test(name: String, fn: Callable) -> void:
	_names.append(name)
	tests.append(fn)

func run_all() -> Dictionary:
	var pass_count := 0
	var fail_count := 0
	var results := []

	for i in tests.size():
		var ok := _run_single_inner(i)
		if ok:
			pass_count += 1
			results.append({"name": _names[i], "passed": true})
		else:
			fail_count += 1
			results.append({"name": _names[i], "passed": false})

	return {
		"pass": pass_count,
		"fail": fail_count,
		"results": results
	}

func run_single(index: int) -> bool:
	if index < 0 or index >= tests.size():
		return false
	return _run_single_inner(index)

func _run_single_inner(index: int) -> bool:
	var fn = tests[index]
	var ok = fn.call()
	return ok

func get_test_names() -> Array[String]:
	return _names.duplicate()

func get_test_count() -> int:
	return tests.size()
