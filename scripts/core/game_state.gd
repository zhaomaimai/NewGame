# version: C0_v1
# last_modified_cycle: C0

extends Node

class_name GameState

var _data: Dictionary = {}
var _config: Dictionary = {}

func register(key: String, value) -> void:
	_data[key] = value

func get_data(key: String, default = null):
	if _data.has(key):
		return _data[key]
	return default

func set_data(key: String, value) -> void:
	_data[key] = value

func clear() -> void:
	_data.clear()
	_config.clear()

func save_game(slot: int) -> void:
	var path := "user://save_%02d.tres" % slot
	var save_dict := _data.duplicate(true)
	var err := ResourceSaver.save(save_dict, path)
	if err != OK:
		DebugSystem.print_dbg("[GS] save_game slot=%d FAILED err=%d" % [slot, err])
	else:
		DebugSystem.print_dbg("[GS] save_game slot=%d OK" % slot)

func load_game(slot: int) -> bool:
	var path := "user://save_%02d.tres" % slot
	if not ResourceLoader.exists(path):
		DebugSystem.print_dbg("[GS] load_game slot=%d NOT_FOUND" % slot)
		return false
	var loaded = ResourceLoader.load(path)
	if loaded == null:
		DebugSystem.print_dbg("[GS] load_game slot=%d FAILED" % slot)
		return false
	_data = loaded.duplicate(true)
	DebugSystem.print_dbg("[GS] load_game slot=%d OK" % slot)
	return true
