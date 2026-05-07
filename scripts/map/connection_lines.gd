# version: C3_v1
# last_modified_cycle: C3
# Connection lines between cities.
# Supports hand-drawn-style Catmull-Rom splines through waypoints.
# Falls back to wobbly straight line when no waypoints exist.

extends Control

var _last_hash := 0


func _process(_delta: float) -> void:
	var cities = GameState.get_data("city.list", [])
	var sel: int = GameState.get_data("city.selected", -1)
	var h: int = _array_hash(cities) * 31 + sel
	if h != _last_hash:
		_last_hash = h
		queue_redraw()


func _draw() -> void:
	var cities: Array = GameState.get_data("city.list", [])
	if cities.is_empty():
		return

	var cmap: Dictionary = {}
	for c in cities:
		cmap[int(c.id)] = c

	var drawn := {}

	for c in cities:
		var cid := int(c.id)
		if not c.has("connections"):
			continue
		var p1 := Vector2(float(c.x), float(c.y) - 30.0)

		for conn_id in c.connections:
			var cid2 := int(conn_id)
			if not cmap.has(cid2):
				continue
			var pk := mini(cid, cid2) * 10000 + maxi(cid, cid2)
			if drawn.has(pk):
				continue
			drawn[pk] = true

			var tc = cmap[cid2]
			var p2 := Vector2(float(tc.x), float(tc.y) - 30.0)
			var color := Color(0.95, 0.9, 0.4, 0.4)

			# Collect waypoints from either city's route_paths
			var waypoints := _get_waypoints(c, cid, cid2)
			if waypoints and waypoints.size() > 0:
				_draw_curved_line(p1, p2, waypoints, color, pk)

	# Highlight selected city connections
	var selected_id = GameState.get_data("city.selected", -1)
	if selected_id >= 0 and cmap.has(selected_id):
		var sel = cmap[selected_id]
		if sel.has("connections"):
			var p1 := Vector2(float(sel.x), float(sel.y) - 30.0)
			for conn_id in sel.connections:
				var cid2 := int(conn_id)
				if not cmap.has(cid2):
					continue
				var tc = cmap[cid2]
				var p2 := Vector2(float(tc.x), float(tc.y) - 30.0)
				var waypoints := _get_waypoints(sel, selected_id, cid2)
				var hl_color := Color(1, 0.6, 0, 0.9)
				if waypoints and waypoints.size() > 0:
					_draw_curved_line(p1, p2, waypoints, hl_color, selected_id * 100 + cid2)
				else:
					draw_line(p1, p2, hl_color, 3.0, true)


# ── waypoint lookup ───────────────────────────────────────────────

func _get_waypoints(city: Dictionary, cid: int, target_id: int) -> Array:
	if city.has("route_paths"):
		var rp = city["route_paths"]
		if rp is Dictionary and rp.has(str(target_id)):
			var pts = rp[str(target_id)]
			if pts is Array and pts.size() > 0:
				return pts
	return []


# ── Catmull-Rom curved line with waypoints ────────────────────────

func _draw_curved_line(from: Vector2, to: Vector2, waypoints: Array, color: Color, seed: int) -> void:
	# Build full point list: from → waypoints → to
	var raw_pts := [from]
	for wp in waypoints:
		raw_pts.append(Vector2(float(wp.x), float(wp.y)))
	raw_pts.append(to)

	# Generate smooth Catmull-Rom curve through all points
	var smooth := PackedVector2Array()
	var n := raw_pts.size()
	for i in range(n - 1):
		var p0: Vector2 = raw_pts[max(0, i - 1)]
		var p1: Vector2 = raw_pts[i]
		var p2: Vector2 = raw_pts[i + 1]
		var p3: Vector2 = raw_pts[min(n - 1, i + 2)]
		var steps := 12
		for s in range(steps):
			var t := s / float(steps)
			smooth.append(_catmull_rom(p0, p1, p2, p3, t))
	smooth.append(raw_pts[n - 1])

	# Add hand-drawn wobble on top of the smooth curve
	var wobbly := PackedVector2Array()
	var seg_count := smooth.size()
	wobbly.resize(seg_count)
	for i in range(seg_count):
		var t := i / float(seg_count - 1) if seg_count > 1 else 0.0
		var p := smooth[i]
		# Compute perpendicular direction from neighboring points
		var prev := smooth[max(0, i - 1)]
		var next_n := smooth[min(seg_count - 1, i + 1)]
		var dir := (next_n - prev).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var ease := sin(t * PI) * 1.2
		var offset := _noise_1d(seed + i, t * 1000.0) * ease * 1.5
		p += perp * offset
		wobbly[i] = p

	# Shadow layer
	draw_polyline(wobbly, Color(color.r, color.g, color.b, color.a * 0.4), 4.0, true)
	# Main line
	draw_polyline(wobbly, color, 1.8, true)


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


# ── deterministic noise ───────────────────────────────────────────

func _noise_1d(seed: int, x: float) -> float:
	var h := seed * 374761393 + int(x) * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = (h ^ (h >> 16))
	return (h & 0x7FFFFFFF) / float(0x7FFFFFFF) * 2.0 - 1.0


# ── hash ──────────────────────────────────────────────────────────

func _array_hash(arr: Array) -> int:
	var h := 0
	for item in arr:
		if item is Dictionary:
			h = h * 31 + int(item.get("id", 0))
			h = h * 31 + int(item.get("x", 0) * 1000)
			h = h * 31 + int(item.get("y", 0) * 1000)
	return h
