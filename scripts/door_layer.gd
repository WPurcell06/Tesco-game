class_name DoorLayer
extends Node2D

# Frosted freezer doors. These draw OVER the items so the aisle behind them is
# harder to read - that is the whole point of the frozen level. They are purely
# visual: no collision, no Area2D, nothing to bump into.
#
# The wall is CONTINUOUS: a repeating grid of doors covering the entire aisle,
# full width and from the ceiling board down to the aisle floor. The layer is
# handed the aisle extents (level_width / shelves) rather than a list of tiles,
# because "which tiles" no longer matters - every bay is glazed.

# --- extents, set by Game after construction
var level_width := 0.0       # cols * TILE, the full aisle width in pixels
var shelves := 1             # number of shelf bays; board index `shelves` is the ceiling
var tile_size := 54.0
var spacing := 162.0         # vertical distance between boards (3 tiles)
var board_h := 16.0          # board thickness, left unglazed so the shelf still reads
var floor_y := 600.0

# One door unit is 2 tiles wide. Narrower and the frames turn into a picket
# fence; wider and a single pane covers most of a bay and stops reading as a
# row of freezer doors.
const DOOR_W := 108.0

# Sheen: a slow diagonal band drifting up-right across each pane, so the glass
# reads as glass rather than as fog.
const SHEEN_W := 46.0        # band thickness, measured horizontally
const SHEEN_SLANT := 46.0    # how far the top of the band leads the bottom
const SHEEN_SPEED := 26.0    # px per second
const SHEEN_GAP := 120.0     # dead travel after the band exits, so it pulses
const SHEEN_STAGGER := 37.0  # per-column phase offset; without it every door flashes in lockstep

const GLASS_COL := Color(0.78, 0.90, 0.97, 0.38)
const FRAME_COL := Color(0.62, 0.78, 0.88, 0.85)
const SHEEN_COL := Color(1, 1, 1, 0.16)
const HANDLE_COL := Color(0.85, 0.93, 0.98, 0.9)

var _t := 0.0


func _ready() -> void:
	z_index = 8


func _process(delta: float) -> void:
	_t += delta
	if _t > 1000.0:
		_t = 0.0
	queue_redraw()


func _draw() -> void:
	if level_width <= 0.0 or shelves <= 0:
		return

	# Door columns tile edge to edge from x=0. The last column is clipped to
	# level_width so a level whose width is not a whole number of doors gets a
	# narrow end door instead of glass hanging past the final tile.
	var count := int(ceil(level_width / DOOR_W))

	# An aisle can be 161 tiles (8694 px) wide, which is ~81 door columns per
	# bay. Drawing all of them every frame is wasted work when the camera only
	# ever shows a screenful, so clip the column range to what is on screen.
	var range_cols := _visible_columns(count)
	var first := int(range_cols.x)
	var last := int(range_cols.y)
	if first >= last:
		return

	# Bay b is the gap ABOVE board b: board 0 is the floor and board `shelves`
	# is the ceiling, so bays 0..shelves-1 glaze the aisle top to bottom.
	for bay in shelves:
		var base_y: float = floor_y - float(bay) * spacing
		var top_y: float = base_y - spacing + board_h
		var h: float = base_y - top_y
		for col in range(first, last):
			var x0: float = float(col) * DOOR_W
			var x1: float = minf(x0 + DOOR_W, level_width)
			if x1 - x0 < 1.0:
				continue
			_door(Rect2(x0, top_y, x1 - x0, h), col)


func _visible_columns(count: int) -> Vector2i:
	# Map the viewport rectangle back into this node's own space, then turn that
	# x span into a half-open column range [first, last).
	if not is_inside_tree():
		return Vector2i(0, count)
	var vp := get_viewport()
	if vp == null:
		return Vector2i(0, count)
	var xform := (vp.get_canvas_transform() * get_global_transform()).affine_inverse()
	var vis: Rect2 = xform * get_viewport_rect()
	if vis.size.x <= 0.0:
		return Vector2i(0, count)
	# One extra column of margin each side hides any rounding at the screen edge.
	var first := int(floor(vis.position.x / DOOR_W)) - 1
	var last := int(ceil(vis.end.x / DOOR_W)) + 1
	return Vector2i(clampi(first, 0, count), clampi(last, 0, count))


func _door(r: Rect2, col: int) -> void:
	# Frosted glass: translucent enough that shelves and items stay visible but
	# awkward to read at a glance.
	draw_rect(r, GLASS_COL, true)

	_sheen(r, col)

	# Per-door frame. Adjacent doors share an edge, so the 3px outlines butt up
	# against each other and read as the mullions between panes - no gap, and no
	# separate mullion pass needed.
	draw_rect(r, FRAME_COL, false, 3.0)

	# Handle on the opening edge, at roughly chest height within the pane.
	var hx: float = r.end.x - 13.0
	draw_line(Vector2(hx, r.position.y + r.size.y * 0.42),
		Vector2(hx, r.position.y + r.size.y * 0.62),
		HANDLE_COL, 4.0)


func _sheen(r: Rect2, col: int) -> void:
	# Travel spans the pane plus the band's own footprint, so the band fully
	# enters at one edge and fully leaves at the other before wrapping.
	var span: float = r.size.x + SHEEN_W + SHEEN_SLANT + SHEEN_GAP
	var s: float = fmod(_t * SHEEN_SPEED + float(col) * SHEEN_STAGGER, span) - (SHEEN_W + SHEEN_SLANT)
	if s >= r.size.x or s + SHEEN_SLANT + SHEEN_W <= 0.0:
		return

	var l: float = r.position.x
	var rr: float = r.end.x
	var bl: float = l + s
	# Corners are clamped to the pane so the band never bleeds onto the door
	# next door; the band leans right as it rises, hence the slant on the top pair.
	var pts := PackedVector2Array([
		Vector2(clampf(bl, l, rr), r.end.y),
		Vector2(clampf(bl + SHEEN_W, l, rr), r.end.y),
		Vector2(clampf(bl + SHEEN_SLANT + SHEEN_W, l, rr), r.position.y),
		Vector2(clampf(bl + SHEEN_SLANT, l, rr), r.position.y),
	])
	draw_colored_polygon(pts, SHEEN_COL)
