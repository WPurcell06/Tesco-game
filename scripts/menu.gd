extends Node2D

# Home screen: title, aisle select, and each aisle's best time.
# Built in code like the rest of the game, so there is no scene to wire up.

const CLICK := "res://ui/click.ogg"

# Tesco's own brand blue/red, used for the backdrop and header band so the
# home screen reads as the shop rather than a generic dark game menu.
const TESCO_BLUE := Color(0.0, 0.220, 0.478)   # #00387A
const TESCO_RED  := Color(0.902, 0.114, 0.145) # #E61D25

var _levels: Array = []
var _sfx: AudioStreamPlayer


func _ready() -> void:
	_levels = LevelData.levels()
	_build()


func _build() -> void:
	var font := Session.ui_font()

	# Controls need a Control/CanvasLayer ancestor to anchor against the actual
	# viewport rect. Parented straight onto this Node2D, PRESET_FULL_RECT has
	# no real area to size against and the whole layout collapses to its
	# content's natural (left-hugging) size instead of filling and centering.
	var layer := CanvasLayer.new()
	add_child(layer)

	# Tesco blue backdrop with a red header band, echoing the storefront's own
	# colour split rather than the generic dark panel it had before.
	var bg := ColorRect.new()
	bg.color = TESCO_BLUE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var header := ColorRect.new()
	header.color = TESCO_RED
	header.position = Vector2(0.0, 0.0)
	header.size = Vector2(1152.0, 96.0)
	layer.add_child(header)

	# a faint band of shelving behind the title, so the home screen looks like
	# it belongs to the game rather than a settings dialog
	var strip := TextureRect.new()
	var sheet := ShelfTheme.sheet_texture()
	if sheet != null:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = ShelfTheme.region(ShelfTheme.BEAM_MID)
		strip.texture = at
		strip.stretch_mode = TextureRect.STRETCH_TILE
		strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		strip.modulate = Color(1, 1, 1, 0.16)
		strip.position = Vector2(0.0, 150.0)
		strip.size = Vector2(1152.0, 54.0)
		layer.add_child(strip)

	if ResourceLoader.exists(CLICK):
		_sfx = AudioStreamPlayer.new()
		_sfx.stream = load(CLICK)
		_sfx.volume_db = -8.0
		add_child(_sfx)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 6)
	layer.add_child(root)

	root.add_child(_logo_slot(font))
	root.add_child(_spacer(10))
	root.add_child(_mode_row(font))
	root.add_child(_spacer(12))

	var grid := VBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 8)
	root.add_child(grid)

	# Blue/red alternating to match the storefront palette. Grey buttons with
	# white text were unreadable, so aisle 4 keeps grey and every label
	# carries a dark outline that works on any of the skins.
	var colours := ["blue", "red", "blue", "grey", "red"]
	for i in range(_levels.size()):
		grid.add_child(_aisle_row(i, colours[i % colours.size()], font))

	root.add_child(_spacer(14))
	root.add_child(_title("arrows move  -  up or space jumps  -  down drops through  -  R restarts",
		15, Color(0.50, 0.54, 0.64), font))


## Reserved space for the title graphic. Drops in res://ui/logo.png the moment
## that file exists; until then it draws a labelled placeholder at the exact
## size the art needs to be.
func _logo_slot(font: FontFile) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0.0, 150.0)

	if ResourceLoader.exists("res://ui/logo.png"):
		var tr := TextureRect.new()
		tr.texture = load("res://ui/logo.png")
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(560.0, 150.0)
		holder.add_child(tr)
		return holder

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(560.0, 150.0)
	box.add_child(_title("TROLLEY DASH", 62, Color(1, 1, 1), font))
	box.add_child(_title("logo goes here  -  ui/logo.png  -  560 x 150",
		13, Color(1, 1, 1, 0.55), font))
	holder.add_child(box)
	return holder


## Ordered runs follow the list top to bottom with an arrow pointing at the next
## item. Any-order runs let you grab things however you like.
func _mode_row(font: FontFile) -> Control:
	var wrap := CenterContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)

	row.add_child(_title("ORDER", 16, Color(0.62, 0.66, 0.76), font))

	for spec in [["In order", "ordered"], ["Any order", "any"]]:
		var b := Button.new()
		b.text = str(spec[0])
		b.custom_minimum_size = Vector2(170.0, 50.0)
		if font != null:
			b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_outline_color", Color(0.08, 0.09, 0.12, 0.95))
		b.add_theme_constant_override("outline_size", 5)
		var chosen: bool = Session.order_mode == str(spec[1])
		b.add_theme_color_override("font_color",
			Color(1, 1, 1) if chosen else Color(0.72, 0.75, 0.82))
		var sb := Session.button_style("yellow" if chosen else "grey")
		if sb != null:
			for st in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_set_mode.bind(str(spec[1])))
		row.add_child(b)

	return wrap


func _set_mode(mode: String) -> void:
	Session.order_mode = mode
	for c in get_children():
		c.queue_free()
	_sfx = null          # about to be freed; _build makes a fresh one
	_build()


func _title(txt: String, size: int, col: Color, font: FontFile) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, float(h))
	return c


func _aisle_row(index: int, colour: String, font: FontFile) -> Control:
	var lvl: Dictionary = _levels[index]
	var name_txt := str(lvl["name"])

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var btn := Button.new()
	btn.text = name_txt
	btn.custom_minimum_size = Vector2(430.0, 62.0)
	if font != null:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
	btn.add_theme_color_override("font_outline_color", Color(0.08, 0.09, 0.12, 0.95))
	btn.add_theme_constant_override("outline_size", 5)
	var sb := Session.button_style(colour)
	if sb != null:
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)
	btn.pressed.connect(_play.bind(index))
	row.add_child(btn)

	var best := Session.best_for(name_txt)
	var best_txt := "best  --" if best == INF else "best  %.1fs" % best
	var lbl := _title(best_txt, 18, Color(0.55, 0.90, 0.65) if best != INF else Color(0.45, 0.48, 0.56), font)
	lbl.custom_minimum_size = Vector2(130.0, 0.0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	return row


func _play(index: int) -> void:
	if _sfx:
		_sfx.play()
	Session.level_index = index
	get_tree().change_scene_to_file("res://game.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode >= KEY_1 and k.keycode <= KEY_9:
			var idx := k.keycode - KEY_1
			if idx < _levels.size():
				_play(idx)
