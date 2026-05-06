# version: C2_v4
# last_modified_cycle: C2
# Map view: shows map background + city markers. No coordinate transform needed.

extends Control

@onready var markers: Node = $Markers
@onready var city_editor: Node = $CityEditor


func _ready():
	_create_markers()
	city_editor.setup(self, markers)


func _create_markers():
	var cities = GameState.get_data("city.list", [])
	for city in cities:
		var marker := preload("res://scenes/map/city_marker.tscn").instantiate()
		markers.add_child(marker)
		marker.setup(city)
		var cx := float(city.x)
		var cy := float(city.y)
		# Position so icon bottom-center sits at (cx, cy)
		marker.position = Vector2(cx - marker.size.x * 0.5, cy - 60.0)
	DebugSystem.print_dbg("[MAP] loaded cities=%d" % cities.size())
