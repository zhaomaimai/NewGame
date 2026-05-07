# version: C3_v1
# last_modified_cycle: C3
# City selection manager.
# Handles selecting/deselecting cities and emits signals.

extends Node

signal city_selected(city_data: Dictionary)
signal city_deselected()


func select_city(id: int) -> void:
	var cities: Array = GameState.get_data("city.list", [])
	for c in cities:
		if int(c.id) == id:
			GameState.set_data("city.selected", id)
			city_selected.emit(c)
			DebugSystem.print_dbg("[CITY] selected id=%d (%s)" % [id, c.get("name", "")])
			return
	# City not found in data — deselect
	deselect_city()


func deselect_city() -> void:
	GameState.set_data("city.selected", -1)
	city_deselected.emit()
	DebugSystem.print_dbg("[CITY] deselected")


func get_selected() -> Dictionary:
	var id = GameState.get_data("city.selected", -1)
	if id < 0:
		return {}
	return get_city(id)


func get_city(id: int) -> Dictionary:
	var cities: Array = GameState.get_data("city.list", [])
	for c in cities:
		if int(c.id) == id:
			return c
	return {}


func get_all_cities() -> Array:
	return GameState.get_data("city.list", [])
