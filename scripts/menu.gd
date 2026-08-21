extends Node2D

# Home screen, built as a store interior: the four themed aisles hang off a
# ceiling rail as signage and All-Store Pick gets a wider sign of its own
# below. Built in code like the rest of the game, so there is no scene to
# wire up.
#
# Two layers, deliberately:
#   this Node2D's _draw()  the store itself - back wall, shelf banding, floor,
#                          ceiling rail. Renders under everything.
#   a CanvasLayer          every Control. Controls need a Control/CanvasLayer
#                          ancestor to anchor against the real viewport rect;
#                          parented straight onto a Node2D, PRESET_FULL_RECT
#                          has nothing to size against and the layout collapses
#                          to its content's natural size instead of centring.
#
# The design is authored against the project's fixed 1152x648 viewport, so
# blocks are positioned against VIEW rather than flowed - it is a poster, not
# a document, and the aspect never changes under it.

const CLICK := "res://ui/click.ogg"

const VIEW := Vector2(1152.0, 648.0)

# --- palette ------------------------------------------------------------------
const BG_DEEP   := Color(0.000, 0.165, 0.360)   # back wall
const FLOOR_TOP := Color(0.043, 0.145, 0.271)
const FLOOR_BOT := Color(0.086, 0.216, 0.373)
const DARK      := Color(0.043, 0.071, 0.125)   # every border and hard shadow
const CREAM     := Color(0.969, 0.961, 0.937)   # the price strip on a sign
const RED       := Color(0.902, 0.114, 0.145)
const ACCENT    := Color(1.000, 0.831, 0.000)
const MUTED     := Color(0.561, 0.702, 0.867)
const NO_TIME   := Color(0.725, 0.702, 0.639)   # "--" when an aisle is unplayed

# Per-aisle sign colour, and the short name the sign carries. Store signage is
# read at a glance from across the shop, so the signs use one word where the
# level's full name would not fit.
const AISLES := [
	{"colour": Color(0.227, 0.655, 0.341), "short": "PRODUCE"},
	{"colour": Color(0.949, 0.718, 0.020), "short": "SNACKS"},
	{"colour": Color(0.122, 0.435, 0.816), "short": "FROZEN"},
	{"colour": Color(0.486, 0.525, 0.596), "short": "HEALTH"},
	{"colour": Color(0.902, 0.114, 0.145), "short": "ALL-STORE PICK"},
]

# --- layout -------------------------------------------------------------------
# The rail is DERIVED, not fixed: the logo plate is taller than the plain
# wordmark it replaces, so everything below it shifts down to suit. RAIL_Y is
# only the starting value; _build recomputes _rail_y from the title's height.
const RAIL_Y      := 232.0     # the ceiling rail the four signs hang from
const RAIL_INSET  := 64.0
const TITLE_GAP   := 14.0      # title block bottom -> order toggle
const TOGGLE_H    := 40.0
const RAIL_GAP    := 30.0      # order toggle bottom -> ceiling rail

const STEM_H      := 20.0      # the hanger between rail and sign
const SIGN_W      := 194.0
const SIGN_H      := 78.0
const SIGN_GAP    := 22.0
const BIG_SIGN_W  := 420.0
const SHADOW_DROP := 5.0       # hard offset shadow, no blur - it is pixel art
const BORDER      := 3

# --- the logo plate -----------------------------------------------------------
# ui/logo.png is dark artwork on transparency, and the store wall behind it is
# dark blue - straight on the wall the black half of the logo all but vanishes.
# It is mounted on a lit cream sign plate instead, which fixes the contrast and
# happens to be exactly the vocabulary the aisle signs already use.
const LOGO_TOP   := 14.0
const LOGO_MAX_H := 130.0      # width follows from the art's own aspect
const LOGO_PAD   := 18.0

var _levels: Array = []
var _sfx: AudioStreamPlayer
var _layer: CanvasLayer
var _rail_y := RAIL_Y      # recomputed in _build from the title's height


func _ready() -> void:
	_levels = LevelData.levels()
	_build()
	_self_check()
	# after _build on purpose: if audio ever fails, the menu is already up
	Sfx.music("music_menu")


## The menu can look perfectly healthy while the thing it launches is broken -
## a script that fails to compile takes its whole scene with it, and
## change_scene_to_file just returns an error nobody sees. So check the aisle
## scene loads UP FRONT and put any fault on screen rather than making the
## player discover it by clicking a button that does nothing.
func _self_check() -> void:
	if _levels.is_empty():
		_show_fault("No levels loaded - LevelData.levels() returned nothing.")
		return
	if load("res://game.tscn") == null:
		_show_fault("game.tscn will not load.\nA script it depends on failed to compile - see the Output panel.")


func _show_fault(msg: String) -> void:
	var font := Session.ui_font()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _flat(Color(0.55, 0.06, 0.08, 0.96), DARK))
	box.position = Vector2(60.0, VIEW.y - 190.0)
	box.custom_minimum_size = Vector2(VIEW.x - 120.0, 0.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _layer != null:
		_layer.add_child(box)
	var l := _label(msg, 15, Color(1, 1, 1), font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	push_error(msg)


# ===========================================================================
# THE STORE (drawn under the UI)
# ===========================================================================

func _draw() -> void:
	# back wall
	draw_rect(Rect2(0.0, 0.0, VIEW.x, VIEW.y), BG_DEEP, true)

	# faint shelf banding, so the backdrop reads as aisle rather than wallpaper
	var y := 0.0
	while y < VIEW.y:
		draw_rect(Rect2(0.0, y, VIEW.x, 4.0), Color(1, 1, 1, 0.045), true)
		y += 50.0

	# floor slab, with a hard edge where it meets the wall
	var floor_top := VIEW.y - 132.0
	draw_rect(Rect2(0.0, floor_top, VIEW.x, 132.0), FLOOR_TOP, true)
	draw_rect(Rect2(0.0, floor_top + 40.0, VIEW.x, 92.0), FLOOR_BOT, true)
	draw_rect(Rect2(0.0, floor_top - 5.0, VIEW.x, 5.0), DARK, true)

	# corner shading, so the middle of the screen carries the eye
	draw_rect(Rect2(0.0, 0.0, VIEW.x, 90.0), Color(0, 0, 0, 0.16), true)
	draw_rect(Rect2(0.0, VIEW.y - 60.0, VIEW.x, 60.0), Color(0, 0, 0, 0.12), true)

	# the ceiling rail the aisle signs hang from
	draw_rect(Rect2(RAIL_INSET, _rail_y, VIEW.x - RAIL_INSET * 2.0, 5.0), DARK, true)


# ===========================================================================
# UI
# ===========================================================================

func _build() -> void:
	var font := Session.ui_font()

	_layer = CanvasLayer.new()
	add_child(_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)

	if ResourceLoader.exists(CLICK):
		_sfx = AudioStreamPlayer.new()
		_sfx.stream = load(CLICK)
		_sfx.volume_db = -8.0
		add_child(_sfx)

	var title_bottom := _build_title(root, font)
	var toggle_y := title_bottom + TITLE_GAP
	_rail_y = toggle_y + TOGGLE_H + RAIL_GAP
	_build_mode_row(root, font, toggle_y)
	_build_signs(root, font)
	_build_clubcard(root, font)
	_build_controls(root, font)

	queue_redraw()


## Title, plus the logo slot: res://ui/logo.png replaces the wordmark the moment
## that file exists. Returns the y the next block may start at, because the two
## title treatments are different heights and everything below has to follow.
func _build_title(root: Control, font: FontFile) -> float:
	# load() can return null EVEN WHEN THE FILE EXISTS - the web editor can
	# miss importing a freshly added asset on its first run. So the logo path
	# only runs once the texture has actually loaded, and a failed load falls
	# back to the drawn wordmark instead of crashing the whole build (calling
	# get_width() on the null was exactly how the menu died to a blank wall).
	var tex: Texture2D = null
	if ResourceLoader.exists("res://ui/logo.png"):
		tex = load("res://ui/logo.png") as Texture2D
	if tex != null:
		# size off the ART's own aspect rather than a hardcoded box, so dropping
		# in a differently-shaped logo never stretches it
		var ar := float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		var lh := LOGO_MAX_H
		var lw := lh * ar
		var pw := lw + LOGO_PAD * 2.0
		var ph := lh + LOGO_PAD * 2.0
		var px := (VIEW.x - pw) * 0.5

		var shadow := ColorRect.new()
		shadow.color = DARK
		shadow.position = Vector2(px, LOGO_TOP + SHADOW_DROP)
		shadow.size = Vector2(pw, ph)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shadow)

		var plate := PanelContainer.new()
		plate.position = Vector2(px, LOGO_TOP)
		plate.size = Vector2(pw, ph)
		plate.add_theme_stylebox_override("panel", _flat(CREAM, DARK, LOGO_PAD, LOGO_PAD))
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(plate)

		var tr := TextureRect.new()
		tr.texture = tex
		# EXPAND_IGNORE_SIZE or the TextureRect's minimum size is the texture's
		# full 576x232 and it forces the plate open to that instead.
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Smooth artwork, not pixel art, and shown SMALLER than source - nearest
		# would alias the curved letterforms on the way down.
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(lw, lh)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(tr)

		return LOGO_TOP + ph + SHADOW_DROP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)

	# the trolley mark. Drawn rather than an asset - it is a few strokes, and
	# this way it recolours with the accent for free.
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	icon.draw.connect(_draw_trolley_icon.bind(icon))
	row.add_child(icon)

	var title := _label("TROLLEY DASH", 56, Color(1, 1, 1), font)
	title.add_theme_color_override("font_shadow_color", DARK)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 5)
	row.add_child(title)

	# A plain Control parent does not resize its children, so setting position
	# and size directly is enough - the default top-left anchors already mean
	# what we want, and an anchor preset here only fights them.
	row.position = Vector2(0.0, 26.0)
	row.size = Vector2(VIEW.x, 66.0)

	var sub := _label("GRAB THE LIST  -  BEAT THE CLOCK", 13, ACCENT, font)
	sub.position = Vector2(0.0, 100.0)
	sub.size = Vector2(VIEW.x, 20.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	return 120.0


func _draw_trolley_icon(who: Control) -> void:
	var c := ACCENT
	var s := 44.0
	# basket
	who.draw_polyline(PackedVector2Array([
		Vector2(s * 0.08, s * 0.16), Vector2(s * 0.22, s * 0.16),
		Vector2(s * 0.36, s * 0.62), Vector2(s * 0.86, s * 0.62),
		Vector2(s * 0.96, s * 0.30), Vector2(s * 0.28, s * 0.30),
	]), c, 2.6, true)
	# wheels
	who.draw_arc(Vector2(s * 0.44, s * 0.82), s * 0.08, 0.0, TAU, 14, c, 2.6, true)
	who.draw_arc(Vector2(s * 0.80, s * 0.82), s * 0.08, 0.0, TAU, 14, c, 2.6, true)


## Ordered runs follow the list top to bottom with a chevron pointing at the
## next item; any-order runs let you grab things however you like.
func _build_mode_row(root: Control, font: FontFile, at_y: float) -> void:
	# spans the full width to centre its contents, so it must not be a click
	# target itself - only the two buttons inside it are
	var wrap := HBoxContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("separation", 10)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.position = Vector2(0.0, at_y)
	wrap.size = Vector2(VIEW.x, TOGGLE_H)
	root.add_child(wrap)

	var cap := _label("ORDER", 12, MUTED, font)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wrap.add_child(cap)

	for spec in [["IN ORDER", "ordered"], ["ANY ORDER", "any"]]:
		var chosen: bool = Session.order_mode == str(spec[1])
		var b := Button.new()
		b.text = str(spec[0])
		b.custom_minimum_size = Vector2(148.0, TOGGLE_H)
		b.focus_mode = Control.FOCUS_NONE
		if font != null:
			b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color",
			Color(0.063, 0.137, 0.247) if chosen else Color(0.812, 0.878, 0.961))
		b.add_theme_color_override("font_hover_color",
			Color(0.063, 0.137, 0.247) if chosen else Color(1, 1, 1))
		var sb := _flat(ACCENT if chosen else Color(0.071, 0.275, 0.498), DARK)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_set_mode.bind(str(spec[1])))
		wrap.add_child(b)


## The four themed aisles hang in a row off the rail; All-Store Pick sits on a
## wider sign below, because it is the whole shop rather than one aisle.
func _build_signs(root: Control, font: FontFile) -> void:
	var count := mini(4, _levels.size())
	var total := float(count) * SIGN_W + float(maxi(count - 1, 0)) * SIGN_GAP
	var x := (VIEW.x - total) * 0.5
	var y := _rail_y + 5.0

	for i in range(count):
		root.add_child(_hanging_sign(i, SIGN_W, Vector2(x, y), font))
		x += SIGN_W + SIGN_GAP

	if _levels.size() >= 5:
		var bx := (VIEW.x - BIG_SIGN_W) * 0.5
		root.add_child(_hanging_sign(4, BIG_SIGN_W, Vector2(bx, y + STEM_H + SIGN_H + 26.0),
			font, false))


## One sign: hanger stem, coloured board carrying the aisle number and name,
## and a cream price strip along the bottom holding the best time.
func _hanging_sign(index: int, width: float, at: Vector2, font: FontFile,
		with_stem: bool = true) -> Control:
	var lvl: Dictionary = _levels[index]
	var name_txt := str(lvl["name"])
	var spec: Dictionary = AISLES[index % AISLES.size()]
	var stem := STEM_H if with_stem else 0.0

	# The WHOLE sign is the click target, handled here rather than by a
	# transparent Button laid over the top. An overlay depends on child order,
	# on the overlay's size surviving add_child, and on nothing decorative
	# sitting above it - three ways to end up with a sign that looks right and
	# does nothing. One control with one gui_input has none of those failure
	# modes, and every decorative child below is explicitly IGNORE so it cannot
	# swallow the press.
	var holder := Control.new()
	holder.position = at
	holder.custom_minimum_size = Vector2(width, stem + SIGN_H + SHADOW_DROP)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	holder.gui_input.connect(_on_sign_input.bind(index))

	if with_stem:
		var rod := ColorRect.new()
		rod.color = DARK
		rod.position = Vector2(width * 0.5 - 1.5, 0.0)
		rod.size = Vector2(3.0, STEM_H)
		rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rod)

	# hard offset shadow: a second rect behind, no blur, because everything
	# else in this game is pixel art and a soft shadow reads as a smudge
	var shadow := ColorRect.new()
	shadow.color = DARK
	shadow.position = Vector2(0.0, stem + SHADOW_DROP)
	shadow.size = Vector2(width, SIGN_H)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow)

	var board := PanelContainer.new()
	board.position = Vector2(0.0, stem)
	board.size = Vector2(width, SIGN_H)
	board.add_theme_stylebox_override("panel", _flat(spec["colour"], DARK, 0.0, 0.0))
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(board)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	board.add_child(col)

	# --- the board itself: number + name
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 9)
	head.custom_minimum_size = Vector2(0.0, 43.0)
	col.add_child(head)

	var num := _label(str(index + 1), 30, Color(1, 1, 1), font)
	num.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.42))
	num.add_theme_constant_override("shadow_offset_x", 0)
	num.add_theme_constant_override("shadow_offset_y", 2)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(num)

	var nm := _label(str(spec["short"]), 15, Color(1, 1, 1), font)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(nm)

	# --- price strip: the aisle's best time, set like a shelf ticket
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _strip_style())
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(strip)

	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 6)
	strip.add_child(strip_row)

	var best_cap := _label("BEST", 9, Color(0.541, 0.522, 0.467), font)
	best_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	best_cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	best_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	strip_row.add_child(best_cap)

	var best := Session.best_for(name_txt)
	var best_txt := "--" if best == INF else "%.1fs" % best
	var best_lbl := _label(best_txt, 14, RED if best != INF else NO_TIME, font)
	best_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strip_row.add_child(best_lbl)

	holder.tooltip_text = name_txt
	return holder


## A press anywhere on an aisle sign starts that aisle.
func _on_sign_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_play(index)


## Lifetime Clubcard balance, sat on the floor strip.
func _build_clubcard(root: Control, font: FontFile) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(40.0, VIEW.y - 96.0)
	panel.add_theme_stylebox_override("panel",
		_flat(Color(0.024, 0.078, 0.157, 0.72), DARK))
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	# the card itself, drawn: blue with a red band, same as the in-game pickup
	var card := Control.new()
	card.custom_minimum_size = Vector2(46.0, 30.0)
	card.draw.connect(_draw_clubcard.bind(card))
	row.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	col.add_child(_label("CLUBCARD BALANCE", 9, MUTED, font))
	col.add_child(_label("%s pts" % _thousands(Clubcard.total()), 21, Color(1, 1, 1), font))


func _draw_clubcard(who: Control) -> void:
	var r := Rect2(0.0, 0.0, 46.0, 30.0)
	who.draw_rect(r, Color(0.0, 0.220, 0.478), true)
	who.draw_rect(Rect2(0.0, 11.0, 46.0, 7.0), RED, true)
	who.draw_rect(Rect2(5.0, 4.0, 13.0, 5.0), Color(1, 1, 1, 0.85), true)
	who.draw_rect(r, DARK, false, 2.0)


func _build_controls(root: Control, font: FontFile) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.position = Vector2(VIEW.x - 460.0, VIEW.y - 96.0)
	col.size = Vector2(420.0, 0.0)
	root.add_child(col)

	for spec in [
		["LEFT / RIGHT MOVE   -   UP or SPACE JUMP", MUTED],
		["DOWN DROP THROUGH   -   R RESTART", MUTED],
		["PRESS 1-5 TO START AN AISLE", ACCENT],
	]:
		var l := _label(str(spec[0]), 11, spec[1], font)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.custom_minimum_size = Vector2(420.0, 0.0)
		col.add_child(l)


# ===========================================================================
# HELPERS
# ===========================================================================

## Chunky flat panel: solid fill, hard dark border, square corners. Everything
## on this screen is built from it.
##
## The margins are parameters because a sign board needs ZERO of them: its
## 78px height is fixed, and 6px top and bottom leaves only 60px for a header
## and ticket strip that need 72 between them - the strip would be pushed out
## of the board. The header centres itself and the strip carries its own
## padding, so a sign gives up the outer margin rather than the fit.
func _flat(fill: Color, border: Color, mh: float = 12.0, mv: float = 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(BORDER)
	sb.set_corner_radius_all(0)
	sb.set_content_margin(SIDE_LEFT, mh)
	sb.set_content_margin(SIDE_RIGHT, mh)
	sb.set_content_margin(SIDE_TOP, mv)
	sb.set_content_margin(SIDE_BOTTOM, mv)
	return sb


## The cream ticket strip along the bottom of a sign: only its TOP edge is
## drawn, so it reads as part of the board rather than a box sitting on it.
func _strip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.border_color = DARK
	sb.set_border_width_all(0)
	sb.border_width_top = BORDER
	sb.set_corner_radius_all(0)
	sb.set_content_margin(SIDE_LEFT, 11.0)
	sb.set_content_margin(SIDE_RIGHT, 11.0)
	sb.set_content_margin(SIDE_TOP, 4.0)
	sb.set_content_margin(SIDE_BOTTOM, 4.0)
	return sb


func _label(txt: String, size: int, col: Color, font: FontFile) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 12345 -> "12,345". Clubcard totals run into the thousands quickly and read
## badly as a bare digit run.
func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func _set_mode(mode: String) -> void:
	Sfx.play("ui_click")
	Session.order_mode = mode
	for c in get_children():
		c.queue_free()
	_layer = null
	_sfx = null          # about to be freed; _build makes a fresh one
	_build()


func _play(index: int) -> void:
	Sfx.play("ui_select")
	if _sfx:
		_sfx.play()
	Session.level_index = index
	# change_scene_to_file returns an error rather than raising: if the game
	# scene or any script it depends on fails to compile, the call quietly does
	# nothing and the player is left clicking a dead menu. Say so instead.
	var err := get_tree().change_scene_to_file("res://game.tscn")
	if err != OK:
		_show_fault("Could not open the aisle - game.tscn failed to load (error %d).\nSee the editor Output panel for the script error." % err)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode >= KEY_1 and k.keycode <= KEY_5:
			# bounded by the fixed five aisles, not by _levels - if the level
			# list failed to load, the keys should still report the fault
			# through _play rather than silently doing nothing
			_play(k.keycode - KEY_1)
