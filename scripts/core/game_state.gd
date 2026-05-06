# version: C0_v1
# last_modified_cycle: C0

extends Node

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
	var path := "user://save_%02d.json" % slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data, "\t"))
		file.close()
		DebugSystem.print_dbg("[GS] save_game slot=%d OK" % slot)
	else:
		DebugSystem.print_dbg("[GS] save_game slot=%d FAILED" % slot)

func load_game(slot: int) -> bool:
	var path := "user://save_%02d.json" % slot
	if not FileAccess.file_exists(path):
		DebugSystem.print_dbg("[GS] load_game slot=%d NOT_FOUND" % slot)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json_str := file.get_as_text()
		var loaded := JSON.parse_string(json_str) as Dictionary
		file.close()
		if loaded:
			_data = loaded
			DebugSystem.print_dbg("[GS] load_game slot=%d OK" % slot)
			return true
	DebugSystem.print_dbg("[GS] load_game slot=%d FAILED" % slot)
	return false
