class_name PowerUp
extends Area2D

var tex: Texture2D = null   # set by Game when the level assigns a sprite

# A bonus pickup that is NOT on the shopping list. Optional by design: taking
# one costs you a detour, so it should only be worth it if the effect pays for
# the time. Effects live in Game._on_powerup_taken.

var kind := "boost"       # "boost" | "clean" | "coins" | "clubcard"
var label := "Power-up"
var taken := false

var _t := 0.0

const COLOURS := {
	"boost": Color(0.42, 0.86, 0.95),
	"clean": Color(0.62, 0.90, 0.55),
	"coins": Color(0.99, 0.79, 0.16),
	"clubcard": Color(0.0, 0.42, 0.80),
}


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	var rect := RectangleShape2D.new()
	rect.size = Vector2(38.0, 38.0)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2(0.0, -19.0)
	add_child(cs)
	z_index = 4


func _process(delta: float) -> void:
	if taken:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if taken:
		return
	var col: Color = COLOURS.get(kind, Color.WHITE)
	var bob := sin(_t * 3.0) * 4.0
	var c := Vector2(0.0, -22.0 + bob)

	if tex != null:
		draw_texture_rect(tex, Rect2(c.x - 22.0, c.y - 22.0, 44.0, 44.0), false)
		return

	# soft halo so it reads as a bonus rather than a hazard
	draw_circle(c, 22.0, Color(col.r, col.g, col.b, 0.18))

	# a Clubcard is drawn as an actual card rather than the generic diamond -
	# it is the one pickup that pays out in seconds, so it earns its own look
	if kind == "clubcard":
		var cw := 42.0
		var ch := 27.0
		var card := Rect2(c.x - cw * 0.5, c.y - ch * 0.5, cw, ch)
		draw_rect(card, Color(0.0, 0.22, 0.48), true)                      # Tesco blue
		draw_rect(Rect2(card.position.x, card.position.y + ch * 0.34,
			cw, ch * 0.24), Color(0.902, 0.114, 0.145), true)              # red stripe
		draw_rect(Rect2(card.position.x + 4.0, card.position.y + 4.0,
			cw * 0.30, 5.0), Color(1, 1, 1, 0.88), true)                   # chip
		draw_rect(card, Color(0.06, 0.08, 0.12), false, 2.0)
		return

	# diamond body
	var pts := PackedVector2Array([
		c + Vector2(0.0, -16.0), c + Vector2(14.0, 0.0),
		c + Vector2(0.0, 16.0), c + Vector2(-14.0, 0.0),
	])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		Color(0.12, 0.12, 0.14), 2.0)

	var f := ThemeDB.fallback_font
	var glyph := "!"
	match kind:
		"boost": glyph = ">"
		"clean": glyph = "~"
		"coins": glyph = "$"
	draw_string(f, c + Vector2(-4.0, 5.0), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.12, 0.12, 0.14))


func collect() -> void:
	taken = true
	monitoring = false
	queue_redraw()
