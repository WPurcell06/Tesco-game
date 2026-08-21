class_name Coupon
extends Area2D

# A cut-out voucher tied to ONE product on the shopping list.
#
# The order is the whole mechanic: cut the coupon BEFORE you grab its product
# and collecting that product credits you `seconds` off the clock. Grab the
# product first and the coupon is dead paper - it can still be picked up, but
# it pays nothing. That turns the route into a planning problem rather than a
# straight line: the detour only pays if you take it in the right order.
#
# Origin sits on the shelf board, same as ShelfItem.

const W := 52.0
const H := 34.0

var item_id := ""            # which product this is a voucher for
var item_label := ""
var tex: Texture2D = null    # that product's own sprite, drawn on the ticket
var seconds := 5.0
var taken := false
var expired := false         # product was already collected, so it pays nothing

var _t := 0.0


func _ready() -> void:
	collision_layer = 4   # layer 3 = pickups / hazards
	collision_mask = 2    # detects layer 2 = player
	monitoring = true
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W, H)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2(0.0, -H * 0.5 - 6.0)
	add_child(cs)
	z_index = 4


func _process(delta: float) -> void:
	if taken:
		return
	_t += delta
	queue_redraw()


func collect(was_expired: bool) -> void:
	taken = true
	expired = was_expired
	monitoring = false
	queue_redraw()


func _draw() -> void:
	if taken:
		return

	var bob := sin(_t * 3.2) * 3.0
	var c := Vector2(0.0, -H * 0.5 - 6.0 + bob)
	var body := Rect2(c.x - W * 0.5, c.y - H * 0.5, W, H)

	# a soft halo, so a coupon reads as a bonus rather than something to dodge
	draw_circle(c, W * 0.5, Color(0.99, 0.79, 0.16, 0.16))

	# the ticket itself: cream stock with a red voucher band across the top
	draw_rect(body, Color(0.99, 0.94, 0.78), true)
	draw_rect(Rect2(body.position.x, body.position.y, W, 9.0),
		Color(0.902, 0.114, 0.145), true)
	draw_rect(body, Color(0.30, 0.24, 0.12), false, 2.0)

	# dashed "cut here" edge down the left, which is what sells it as a coupon
	var y := body.position.y + 3.0
	while y < body.end.y - 2.0:
		draw_line(Vector2(body.position.x + 5.0, y),
			Vector2(body.position.x + 5.0, y + 3.0), Color(0.55, 0.45, 0.25), 1.0)
		y += 6.0

	# the product it is a voucher for, so you can tell at a glance
	if tex != null:
		draw_texture_rect(tex,
			Rect2(body.position.x + 9.0, body.position.y + 11.0, 19.0, 19.0), false)

	var f := ThemeDB.fallback_font
	if f:
		draw_string(f, Vector2(body.position.x + 30.0, body.end.y - 7.0),
			"-%ds" % int(seconds), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.20, 0.16, 0.08))
