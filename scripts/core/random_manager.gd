# version: C0_v1
# last_modified_cycle: C0

extends Node

class_name RandomManager

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	seed(42)

func randf() -> float:
	return _rng.randf()

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func seed(value: int) -> void:
	_rng.seed = value
	if DebugSystem.debug_mode:
		_rng.seed = 42
