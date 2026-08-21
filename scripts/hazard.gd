class_name Hazard
extends Area2D

var tex: Texture2D = null   # set by Game when the level assigns a sprite

# An obstacle on a shelf board. The TYPE decides what it does to you, so the
# aisle theme and the mechanic stay tied together.
#
#   peel    banana skin      1.0s stun - you skid, controls gone
#   spill   fizzy drink      slowdown  - bogged down but still steering
#   ice     frozen patch     3.0s slip - FASTER but barely steerable
#   soap    spilled soap     1.8s trapped in a bubble, pinned in place
#   crate / trolley / pallet  generic solid obstacle, slowdown
#
# The Game positions this node at the CENTRE of its box.

var kind := "spill"
var box := Vector2(41.4, 39.6)

const EFFECTS := {
	"peel": "stun", "soap": "bubble", "ice": "slip",
	"spill": "slow", "crate": "slow", "trolley": "slow", "pallet": "slow", "box": "slow",
}

# Flat hazards sit low and are read as floor surfaces; tall ones are solid
# objects you clearly have to hop.
const BOXES := {
	"peel":    Vector2(37.8, 16.2),
	"spill":   Vector2(52.2, 12.6),
	"ice":     Vector2(54.0, 14.4),
	"soap":    Vector2(39.6, 27.0),
	"crate":   Vector2(41.4, 39.6),
	"trolley": Vector2(45.0, 41.4),
	"pallet":  Vector2(46.8, 23.4),
	"box":     Vector2(41.4, 39.6),
}

const TINTS := {
	"peel":    Color(0.93, 0.82, 0.24),
	"spill":   Color(0.72, 0.28, 0.42),
	"ice":     Color(0.62, 0.86, 0.95),
	"soap":    Color(0.86, 0.74, 0.93),
	"crate":   Color(0.72, 0.45, 0.20),
	"trolley": Color(0.55, 0.57, 0.62),
	"pallet":  Color(0.62, 0.50, 0.32),
	"box":     Color(0.78, 0.56, 0.30),
}

var _t := 0.0


func effect() -> String:
	return str(EFFECTS.get(kind, "slow"))


static func box_for(k: String) -> Vector2:
	return BOXES.get(k, Vector2(41.4, 39.6))


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	var rect := RectangleShape2D.new()
	rect.size = box
	var cs := CollisionShape2D.new()
	cs.shape = rect
	add_child(cs)
	z_index = 4


func _process(delta: float) -> void:
	if kind == "ice" or kind == "soap":
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-box.x * 0.5, -box.y * 0.5, box.x, box.y)

	if tex != null:
		draw_texture_rect(tex, r, false)
		return

	var fill: Color = TINTS.get(kind, Color(0.85, 0.24, 0.22))
	var line := Color(0.15, 0.12, 0.11)

	match kind:
		"peel":
			# a squashed crescent rather than a block
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.35,
				r.size.x, r.size.y * 0.65), fill, true)
			draw_circle(Vector2(r.position.x + 8.0, r.position.y + 6.0), 7.0, fill)
			draw_circle(Vector2(r.end.x - 8.0, r.position.y + 4.0), 6.0, fill)
			draw_rect(r, line, false, 1.5)
		"spill":
			draw_rect(r, fill, true)
			draw_circle(Vector2(r.position.x + 12.0, r.position.y + 2.0), 6.0, fill)
			draw_circle(Vector2(r.end.x - 14.0, r.position.y + 3.0), 5.0, fill)
			draw_rect(r, line, false, 1.5)
		"ice":
			draw_rect(r, Color(fill.r, fill.g, fill.b, 0.75), true)
			# a couple of moving glints so it reads as slippery, not solid
			var g := fmod(_t * 40.0, box.x)
			draw_line(Vector2(r.position.x + g, r.end.y),
				Vector2(r.position.x + g - 8.0, r.position.y), Color(1, 1, 1, 0.55), 2.0)
			draw_rect(r, Color(0.75, 0.92, 1.0, 0.9), false, 1.5)
		"soap":
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.5,
				r.size.x, r.size.y * 0.5), fill, true)
			for i in range(3):
				var bob := sin(_t * 2.5 + float(i)) * 3.0
				draw_circle(Vector2(r.position.x + 10.0 + float(i) * 12.0,
					r.position.y + 8.0 + bob), 5.0 - float(i), Color(1, 1, 1, 0.55))
			draw_rect(r, line, false, 1.5)
		_:
			draw_rect(r, fill, true)
			var step := 14.0
			var x := r.position.x - r.size.y
			while x < r.position.x + r.size.x:
				var a := Vector2(maxf(x, r.position.x), r.position.y)
				var b := Vector2(minf(x + r.size.y, r.end.x),
					r.position.y + minf(r.size.y, r.end.x - x))
				draw_line(a, b, Color(1, 1, 1, 0.30), 5.0)
				x += step
			draw_rect(r, line, false, 2.0)
