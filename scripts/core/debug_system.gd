# version: C0_v1
# last_modified_cycle: C0

extends Node

class_name DebugSystem

static var debug_mode: bool = false

static func print_dbg(msg: String) -> void:
	if debug_mode:
		print(msg)
