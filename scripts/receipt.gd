class_name Receipt
extends Control

# The end-of-run till receipt. Everything the old end panel said as three
# stacked labels - items, coins, savings, time, Clubcard points - is printed
# here instead, as an actual receipt.
#
# It PRINTS, out of a printer: a pixel-art till printer is drawn at the top of
# the control and the paper feeds downward out of its slot at PRINT_SPEED, each
# line appearing as the paper reaches it, so the score arrives a beat at a time
# rather than all at once. Skippable, because a receipt you have already read is
# just a wait - call finish_printing() (the Game binds that to any key or button
# press), which slams the paper out whole and stops the machine dead.
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

# --- the machine the paper comes out of ---------------------------------
# All of this is drawn in the same _draw() as the receipt, *after* the paper,
# so the roll reads as feeding out from underneath the casing.
const PRINTER_H    := 44.0     # lid (14) + fascia and lights (to 30) + slot (34..44), stacked exactly
const LID_H        := 14.0     # raised top cover, so the casing below it reads as a chunkier base
const LID_INSET    := 6.0      # lid is this much narrower than the body each side - a free pixel-art bevel
const VENT_X       := 14.0     # left edge of the vent slits, clear of the lid's own inset
const SLOT_H       := 10.0     # recess the paper feeds through, sat at the very bottom of the casing
const GUIDE_W      := 5.0      # posts either side of the mouth that the paper runs between
const GUIDE_H      := 5.0      # they only need to poke out far enough to overlap the paper's top corners
const LED_SIZE     := 7.0      # status lights, big enough to read at 1x without looking like buttons
const PAPER_TUCK   := 5.0      # paper starts this far *behind* the casing so its top edge is never seen. Small on purpose: the first row's baseline is only PAD + LINE_H - 5 = 29px down the paper, and the 21px title's ascenders reach ~17px above that, so any deeper tuck prints the heading behind the machine
const PAPER_TOP    := PRINTER_H - PAPER_TUCK   # y of the paper's first pixel; the top PAPER_TUCK of it is covered by the casing

# --- motion --------------------------------------------------------------
const FEED_STEP    := LINE_H   # paper leaves in whole line-feeds, like a stepper motor. Must exceed one frame of PRINT_SPEED (~12px at 60fps) or the ratchet is invisible
const SHAKE_PX     := 1.0      # printer judder while feeding. One pixel: at two it reads as an earthquake, not a motor
const SHAKE_HZ     := 13.0     # judder cycles per second - fast enough to buzz, slow enough to see
const BLINK_S      := 0.09     # activity light stays on, then off, for this long each

const PAPER := Color(0.97, 0.96, 0.92)
const INK   := Color(0.16, 0.16, 0.19)
const FAINT := Color(0.42, 0.42, 0.46)

const CASE     := Color(0.13, 0.15, 0.21)   # casing: a blue-grey lifted just off the game's #0B1220 so it separates from the panel
const CASE_LID := Color(0.19, 0.22, 0.30)
const CASE_LIT := Color(0.30, 0.34, 0.44)   # catch light along any top edge
const RECESS   := Color(0.09, 0.10, 0.14)
const SHADE    := Color(0.04, 0.05, 0.07)   # vents and slot mouth - the darkest thing on screen, so they read as holes
const BLUE     := Color(0.0, 0.22, 0.48)    # Tesco blue #00387A
const RED      := Color(0.90, 0.11, 0.15)   # Tesco red #E61D25
const LED_PWR  := Color(0.42, 0.93, 0.52)   # power: on the whole time
const LED_BUSY := Color(1.0, 0.74, 0.22)    # activity: blinks only while feeding
const LED_OFF  := Color(0.16, 0.17, 0.21)   # ...and is a dead grey lens the rest of the time

var rows: Array = []           # see _row helpers below
var _full_h := 0.0
var _revealed := 0.0
var _font: FontFile = null
var _barcode_seed := 1
var _t := 0.0                  # seconds of feeding so far - drives shake and blink, and only ticks while printing


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
	_t = 0.0
	# _full_h measures the paper alone. The control also has to carry the
	# printer above it, minus the strip of paper that hides behind the casing -
	# without that the printer would be clipped and the ScrollContainer would
	# come up PAPER_TOP px short at the bottom.
	var total_h := PAPER_TOP + _full_h
	custom_minimum_size = Vector2(W, total_h)
	size = Vector2(W, total_h)
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
		# _t only advances while the motor is running, so a finished receipt
		# never asks for another frame - the last redraw is a still one.
		_t += delta
		_revealed = minf(_revealed + PRINT_SPEED * delta, _full_h)
		queue_redraw()


# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------

func _draw() -> void:
	# Nothing has been measured yet: no paper, and no printer either, or the
	# end panel would show a machine hovering over empty space.
	if _full_h <= 0.0:
		return

	var printing := _revealed < _full_h
	# A real till printer advances a line at a time, so the paper is only ever
	# drawn at a whole multiple of FEED_STEP while the motor runs. The instant
	# it stops it snaps to the exact height, so the tear edge lands where
	# build() said it would.
	var h := _revealed
	if printing:
		h = floorf(_revealed / FEED_STEP) * FEED_STEP

	if h > 2.0:
		_draw_paper(h)
	# printer last: it has to cover the paper's top edge for the paper to look
	# like it is coming out from under it
	_draw_printer(printing, h > 0.0)


## The receipt itself. Drawn in paper space - y == 0 is the paper's own top
## edge, which sits up behind the printer casing - so every row measurement
## below is unchanged from when the paper started at the top of the control.
func _draw_paper(h: float) -> void:
	var font: Font = _font if _font != null else ThemeDB.fallback_font

	draw_set_transform(Vector2(0.0, PAPER_TOP))

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
	draw_set_transform(Vector2.ZERO)


## The printer. Chunky, dark, bolted to the top of the control, with the slot
## mouth on its bottom edge so the paper leaves the casing exactly where the
## hole is. Judders by a pixel while feeding and is dead still otherwise, which
## is what makes finish_printing() look like the machine simply stopped.
func _draw_printer(printing: bool, has_paper: bool) -> void:
	var shake := 0.0
	if printing:
		# roundf(sin) only ever gives -1, 0 or 1, so the casing snaps between
		# whole pixels instead of smearing across them - pixel art, not blur
		shake = roundf(sin(_t * TAU * SHAKE_HZ)) * SHAKE_PX
	draw_set_transform(Vector2(0.0, shake))

	# casing, then the raised lid inset on top of it
	draw_rect(Rect2(0.0, 0.0, W, PRINTER_H), CASE, true)
	draw_rect(Rect2(LID_INSET, 0.0, W - LID_INSET * 2.0, LID_H), CASE_LID, true)
	draw_rect(Rect2(LID_INSET, 0.0, W - LID_INSET * 2.0, 2.0), CASE_LIT, true)

	# vent slits punched in the lid
	for i in range(5):
		draw_rect(Rect2(VENT_X + float(i) * 6.0, 5.0, 2.0, 6.0), SHADE, true)

	# fascia: a Tesco-blue stripe under the lid and a red chip beside the vents
	draw_rect(Rect2(0.0, LID_H + 2.0, W, 3.0), BLUE, true)
	draw_rect(Rect2(VENT_X, LID_H + 10.0, 11.0, 4.0), RED, true)

	# status lights, over on the right where they don't fight the red chip
	var busy := printing and fmod(_t, BLINK_S * 2.0) < BLINK_S
	_led(W - 36.0, LID_H + 8.0, LED_PWR)
	_led(W - 22.0, LID_H + 8.0, LED_BUSY if busy else LED_OFF)

	# the slot: a recess with a lit top lip and a near-black mouth flush with
	# the bottom of the casing, which is where the paper appears from
	draw_rect(Rect2(0.0, PRINTER_H - SLOT_H, W, SLOT_H), RECESS, true)
	draw_rect(Rect2(0.0, PRINTER_H - SLOT_H, W, 1.0), CASE_LIT, true)
	draw_rect(Rect2(0.0, PRINTER_H - 4.0, W, 4.0), SHADE, true)

	# the casing's shadow falling on the paper, and the guide posts over it
	if has_paper:
		draw_rect(Rect2(0.0, PRINTER_H, W, 2.0), Color(0, 0, 0, 0.22), true)
		draw_rect(Rect2(0.0, PRINTER_H + 2.0, W, 2.0), Color(0, 0, 0, 0.10), true)
	draw_rect(Rect2(0.0, PRINTER_H, GUIDE_W, GUIDE_H), CASE, true)
	draw_rect(Rect2(W - GUIDE_W, PRINTER_H, GUIDE_W, GUIDE_H), CASE, true)

	draw_set_transform(Vector2.ZERO)


## One bezelled status light: a dark surround so the lens sits *in* the casing
## rather than floating on it.
func _led(x: float, y: float, col: Color) -> void:
	draw_rect(Rect2(x - 1.0, y - 1.0, LED_SIZE + 2.0, LED_SIZE + 2.0), SHADE, true)
	draw_rect(Rect2(x, y, LED_SIZE, LED_SIZE), col, true)


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
