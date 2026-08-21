class_name Receipt
extends Control

# The end-of-run till receipt. Everything the old end panel said as three
# stacked labels - items, coins, savings, time, Clubcard points - is printed
# here instead, as an actual receipt.
#
# It PRINTS: the paper unrolls downward at PRINT_SPEED and each line appears as
# the paper reaches it, so the score arrives a beat at a time rather than all
# at once. Skippable, because a receipt you have already read is just a wait -
# call finish_printing() (the Game binds that to any key or button press).
#
# Rows are built with add_line / add_rule / add_gap / add_barcode, then build().
# Left text and right text are laid out as two columns off the panel's own
# width, so the alignment holds up under a proportional font - there is no
# monospace face in the project and a receipt has to line its prices up.

const W            := 340.0
const PAD          := 16.0
const LINE_H       := 18.0
const RULE_H       := 11.0
const PRINT_SPEED  := 700.0    # px of paper per second
const BARCODE_H    := 30.0
const TEAR         := 7.0      # zigzag tooth width along the torn edge

const PAPER := Color(0.97, 0.96, 0.92)
const INK   := Color(0.16, 0.16, 0.19)
const FAINT := Color(0.42, 0.42, 0.46)

var rows: Array = []           # see _row helpers below
var _full_h := 0.0
var _revealed := 0.0
var _font: FontFile = null
var _barcode_seed := 1


func _ready() -> void:
	_font = Session.ui_font()
	set_process(true)


# ---------------------------------------------------------------------------
# BUILDING
# ---------------------------------------------------------------------------

func add_line(left: String, right: String = "", size: int = 13,
		col: Color = INK) -> void:
	rows.append({"kind": "line", "l": left, "r": right, "size": size, "col": col})


func add_centred(text: String, size: int = 13, col: Color = INK) -> void:
	rows.append({"kind": "centre", "l": text, "size": size, "col": col})


func add_rule() -> void:
	rows.append({"kind": "rule"})


func add_gap(h: float = 8.0) -> void:
	rows.append({"kind": "gap", "h": h})


func add_barcode(seed_value: int) -> void:
	_barcode_seed = maxi(1, absi(seed_value))
	rows.append({"kind": "barcode"})


## Measures the finished receipt and starts the print. Call after the last row.
func build() -> void:
	_full_h = PAD
	for r in rows:
		_full_h += _row_height(r)
	_full_h += PAD + TEAR
	_revealed = 0.0
	custom_minimum_size = Vector2(W, _full_h)
	size = Vector2(W, _full_h)
	queue_redraw()


func _row_height(r: Dictionary) -> float:
	match str(r.get("kind", "line")):
		"rule":
			return RULE_H
		"gap":
			return float(r.get("h", 8.0))
		"barcode":
			return BARCODE_H + 6.0
		_:
			return LINE_H


func is_printing() -> bool:
	return _revealed < _full_h


## Slams the whole receipt out at once, for players who don't want the animation.
func finish_printing() -> void:
	_revealed = _full_h
	queue_redraw()


func _process(delta: float) -> void:
	if _revealed < _full_h:
		_revealed = minf(_revealed + PRINT_SPEED * delta, _full_h)
		queue_redraw()


# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------

func _draw() -> void:
	var h := _revealed
	if h <= 2.0:
		return

	var font: Font = _font if _font != null else ThemeDB.fallback_font

	# the paper, plus a hint of shading down each edge so it reads as a strip
	# of till roll rather than a flat white box
	draw_rect(Rect2(0.0, 0.0, W, h), PAPER, true)
	draw_rect(Rect2(0.0, 0.0, 3.0, h), Color(0, 0, 0, 0.05), true)
	draw_rect(Rect2(W - 3.0, 0.0, 3.0, h), Color(0, 0, 0, 0.05), true)

	var y := PAD
	for r in rows:
		var rh := _row_height(r)
		# a row only prints once the paper has actually reached it
		if y + rh > h:
			break
		match str(r.get("kind", "line")):
			"rule":
				_dashed_rule(y + RULE_H * 0.5)
			"gap":
				pass
			"barcode":
				_barcode(y + 3.0)
			"centre":
				var size_c := int(r.get("size", 13))
				var txt_c := str(r["l"])
				var wc := font.get_string_size(txt_c, HORIZONTAL_ALIGNMENT_LEFT,
					-1, size_c).x
				draw_string(font, Vector2((W - wc) * 0.5, y + LINE_H - 5.0), txt_c,
					HORIZONTAL_ALIGNMENT_LEFT, -1, size_c, r.get("col", INK))
			_:
				var size_l := int(r.get("size", 13))
				var base := y + LINE_H - 5.0
				draw_string(font, Vector2(PAD, base), str(r["l"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, size_l, r.get("col", INK))
				var right_txt := str(r.get("r", ""))
				if not right_txt.is_empty():
					var wr := font.get_string_size(right_txt,
						HORIZONTAL_ALIGNMENT_LEFT, -1, size_l).x
					draw_string(font, Vector2(W - PAD - wr, base), right_txt,
						HORIZONTAL_ALIGNMENT_LEFT, -1, size_l, r.get("col", INK))
		y += rh

	_tear_edge(h)


## The torn-off bottom of the roll. While printing this is the live edge, so it
## doubles as the thing that sells the paper as still coming out.
func _tear_edge(h: float) -> void:
	var x := 0.0
	var up := true
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, h))
	while x < W:
		x = minf(x + TEAR, W)
		pts.append(Vector2(x, h - (TEAR * 0.6 if up else 0.0)))
		up = not up
	pts.append(Vector2(W, h + TEAR))
	pts.append(Vector2(0.0, h + TEAR))
	# painted in the background colour, so it bites the zigzag out of the paper
	draw_colored_polygon(pts, Color(0, 0, 0, 0))
	# a soft shadow line along the tear keeps it visible on any backdrop
	for i in range(pts.size() - 3):
		draw_line(pts[i], pts[i + 1], Color(0.72, 0.71, 0.67), 1.5)


func _dashed_rule(y: float) -> void:
	var x := PAD
	while x < W - PAD:
		draw_line(Vector2(x, y), Vector2(minf(x + 4.0, W - PAD), y), FAINT, 1.0)
		x += 7.0


## Decorative, but deterministic: the bars come from the run's own score, so
## the same result always prints the same barcode.
func _barcode(y: float) -> void:
	var x := PAD + 26.0
	var n := _barcode_seed
	var i := 0
	while x < W - PAD - 26.0 and i < 96:
		n = (n * 1103515245 + 12345) & 0x7FFFFFFF
		var bw := 1.0 + float(n % 3)
		if i % 2 == 0:
			draw_rect(Rect2(x, y, bw, BARCODE_H), INK, true)
		x += bw + 1.0
		i += 1
