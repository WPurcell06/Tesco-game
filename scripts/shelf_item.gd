class_name ShelfItem
extends Area2D

var tex: Texture2D = null   # set by Game when the level assigns a sprite

# A product sitting on a shelf board. Origin is at the board surface.

const W := 30.6
const H := 37.8

var id := ""
var label := ""
var coins := 1
var is_target := false
var collected := false

var _t := 0.0


func _ready() -> void:
	collision_layer = 4   # layer 3 = pickups / hazards
	collision_mask = 2    # detects layer 2 = player
	monitoring = true
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W, H)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2(0.0, -H * 0.5)
	add_child(cs)
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	if is_target:
		queue_redraw()


func set_target(v: bool) -> void:
	if is_target != v:
		is_target = v
		queue_redraw()


func _draw() -> void:
	if collected:
		return

	var bob := 0.0
	if is_target:
		bob = sin(_t * 4.0) * 4.0

	var top := -H + bob
	var box := Rect2(-W * 0.5, top, W, H)

	if tex != null:
		var mod := Color.WHITE if is_target else Color(0.55, 0.55, 0.58, 0.75)
		draw_texture_rect(tex, box, false, mod)
		return

	# colour by coin value: cheap = pale, expensive = rich
	var tint := [
		Color(0.72, 0.80, 0.86),
		Color(0.55, 0.76, 0.62),
		Color(0.92, 0.72, 0.36),
		Color(0.83, 0.52, 0.78),
	]
	var body: Color = tint[clampi(coins - 1, 0, tint.size() - 1)]
	var outline := Color(0.16, 0.14, 0.13)

	if not is_target:
		body = body.lerp(Color(0.45, 0.45, 0.47), 0.6)
		outline.a = 0.45

	draw_rect(box, body, true)
	draw_rect(Rect2(box.position + Vector2(0, H * 0.28), Vector2(W, 5)), outline, true)
	draw_rect(box, outline, false, 2.0)

	var font := ThemeDB.fallback_font
	if font:
		var col := Color(1, 1, 1, 1) if is_target else Color(1, 1, 1, 0.45)
		draw_string(font, Vector2(-W * 0.5 - 8.0, top - 8.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, W + 16.0, 13, col)

	if is_target:
		# arrow above the next item on the list
		var ax := 0.0
		var ay := top - 30.0 + sin(_t * 4.0) * 3.0
		var pts := PackedVector2Array([
			Vector2(ax - 8.0, ay), Vector2(ax + 8.0, ay), Vector2(ax, ay + 11.0)
		])
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.2))
