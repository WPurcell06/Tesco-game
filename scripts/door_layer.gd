class_name DoorLayer
extends Node2D

# Frosted freezer doors. These draw OVER the items so the aisle behind them is
# harder to read - that is the whole point of the frozen level. They are purely
# visual: no collision, nothing to bump into.

var tiles: Array = []        # Array of Vector2i(col, shelf)
var tile_size := 60.0
var spacing := 180.0
var board_h := 16.0
var floor_y := 600.0

var _t := 0.0


func _ready() -> void:
	z_index = 8


func _process(delta: float) -> void:
	_t += delta
	if _t > 1000.0:
		_t = 0.0
	queue_redraw()


func _draw() -> void:
	# group tiles per shelf so a run of doors draws as one pane
	var by_shelf := {}
	for t in tiles:
		var s := int(t.y)
		if not by_shelf.has(s):
			by_shelf[s] = []
		by_shelf[s].append(int(t.x))

	for shelf in by_shelf:
		var cols: Array = by_shelf[shelf]
		cols.sort()
		var runs := []
		var start := -1
		var prev := -1
		for c in cols:
			if start < 0:
				start = c
			elif c != prev + 1:
				runs.append(Vector2i(start, prev))
				start = c
			prev = c
		if start >= 0:
			runs.append(Vector2i(start, prev))

		var by: float = floor_y - float(shelf) * spacing
		var top: float = by - spacing + board_h
		for run in runs:
			var x0 := float(run.x) * tile_size
			var x1 := float(run.y + 1) * tile_size
			_pane(Rect2(x0, top, x1 - x0, by - top))


func _pane(r: Rect2) -> void:
	# frosted glass
	draw_rect(r, Color(0.78, 0.90, 0.97, 0.42), true)

	# a slow drifting sheen so it reads as glass rather than fog
	var sheen := fmod(_t * 26.0, r.size.x + 160.0) - 80.0
	var a := Vector2(r.position.x + sheen, r.end.y)
	var b := Vector2(r.position.x + sheen + 46.0, r.position.y)
	draw_line(a, b, Color(1, 1, 1, 0.16), 22.0)

	# frame
	draw_rect(r, Color(0.62, 0.78, 0.88, 0.85), false, 3.0)
	# central mullion, so a wide run reads as separate doors
	var mid := r.position.x + r.size.x * 0.5
	draw_line(Vector2(mid, r.position.y), Vector2(mid, r.end.y),
		Color(0.62, 0.78, 0.88, 0.75), 3.0)
	# handle
	draw_line(Vector2(mid - 12.0, r.position.y + r.size.y * 0.45),
		Vector2(mid - 12.0, r.position.y + r.size.y * 0.62),
		Color(0.85, 0.93, 0.98, 0.9), 4.0)
