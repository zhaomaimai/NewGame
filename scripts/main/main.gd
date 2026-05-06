# version: C2_v7
# last_modified_cycle: C2

extends Node

func _ready():
	var paths := ["res://data/cities_custom.json", "res://data/cities.json"]
	var file: FileAccess = null
	var used_path := ""
	for p in paths:
		file = FileAccess.open(p, FileAccess.READ)
		if file:
			used_path = p
			break
	if file:
		var text := file.get_as_text()
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			var data: Dictionary = parsed
			if data.has("cities"):
				GameState.set_data("city.list", data["cities"])
				# Load drawn_lines from separate file
				var lines_path := "res://data/drawn_lines.json"
				var lines_file := FileAccess.open(lines_path, FileAccess.READ)
				if lines_file:
					var lines_text := lines_file.get_as_text()
					var lines_parsed = JSON.parse_string(lines_text)
					if lines_parsed is Dictionary and lines_parsed.has("drawn_lines"):
						GameState.set_data("map.drawn_lines", lines_parsed["drawn_lines"])
					lines_file.close()
				DebugSystem.print_dbg("[MAIN] loaded cities=%d from %s" % [data["cities"].size(), used_path])
			else:
				DebugSystem.print_dbg("[MAIN] ERROR: cities.json missing 'cities' key")
		else:
			DebugSystem.print_dbg("[MAIN] ERROR: invalid cities.json")
		file.close()
	else:
		DebugSystem.print_dbg("[MAIN] ERROR: cannot open cities.json")

	var map_view := preload("res://scenes/map/map_view.tscn").instantiate()
	add_child(map_view)
