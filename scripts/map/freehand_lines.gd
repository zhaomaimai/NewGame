# version: C2_v7
# last_modified_cycle: C2
# Renders freehand-drawn decorative lines on the map.

extends Control

var _last_hash := 0


func _process(_delta: float) -> void:
	var lines = GameState.get_data("map.drawn_lines", [])
	var h := _lines_hash(lines)
	if h != _last_hash:
		_last_hash = h
		queue_redraw()


func _draw() -> void:
	var lines = GameState.get_data("map.drawn_lines", [])
	if lines.is_empty():
		return

	var color := Color(0.76, 0.62, 0.34, 0.55)  # dirt yellow
	for line in lines:
		if line is Array and line.size() >= 2:
			var points := PackedVector2Array()
			for pt in line:
				points.append(Vector2(float(pt.x), float(pt.y)))
			var spline := _sample_catmull_rom(points, 8)
			draw_polyline(spline, color, 2.0, true)


func _lines_hash(lines: Array) -> int:
	var h := 0
	for line in lines:
		for pt in line:
			h = h * 31 + int(float(pt.x) * 1000.0)
			h = h * 31 + int(float(pt.y) * 1000.0)
	return h


# ── catmull-rom spline ──────────────────────────────────────────

func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _sample_catmull_rom(points: PackedVector2Array, segs: int = 8) -> PackedVector2Array:
	if points.size() < 2:
		return points
	if points.size() == 2:
		var result := PackedVector2Array()
		for i in range(segs + 1):
			result.append(points[0].lerp(points[1], float(i) / float(segs)))
		return result

	var result := PackedVector2Array()
	result.append(points[0])

	for i in range(1, points.size() - 1):
		var p0 := points[i - 1]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]

		for j in range(1, segs + 1):
			var t := float(j) / float(segs)
			result.append(_catmull_rom(p0, p1, p2, p3, t))

	return result
