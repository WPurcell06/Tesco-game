extends Node2D

# ---------------------------------------------------------------------------
# SCORING
#   final = elapsed time - (coins * SECONDS_PER_COIN)
#   LOWER IS BETTER. Coins are the reward-point currency: grabbing pricier
#   items shaves seconds off your run, so risk/reward is tunable from here.
#
#   Hazards do NOT add a number to the score. They bog the player down
#   (see SLOW_* in player.gd), which costs real seconds through the clock.
#   That means hazard severity is tuned in player.gd, not here.
# ---------------------------------------------------------------------------

const SECONDS_PER_COIN := 1.5

enum State { READY, PLAYING, FINISHED }

var state: int = State.READY
var level_index := 0
var level: Dictionary = {}

var elapsed := 0.0
var coins := 0
var hits := 0
var list_ids: Array = []
var order_mode := "fixed"     # "fixed" | "shuffle" | "any"
var got: Dictionary = {}      # id -> true, used by the "any" order mode
var list_pos := 0

var player: Player
var camera: Camera2D
var world: Node2D
var items: Array = []

var level_cols := LevelData.DEFAULT_COLS
var level_width := 0.0
var segments: Dictionary = {}   # board index -> Array of Vector2(x_start, x_end)
var _arrow_t := 0.0
var _chips: Dictionary = {}
var _sheet: Texture2D = null    # industrial tilemap, null = fall back to shapes
var _safe_pos := Vector2.ZERO   # last confirmed footing, for falling out of the aisle
var _safe_t := 0.0

# HUD
var hud: CanvasLayer
var lbl_level: Label
var lbl_time: Label
var lbl_coins: Label
var lbl_score: Label
var lbl_hint: Label
var _flash_text := ""
var _flash_t := 0.0
var list_box: VBoxContainer

# End-of-run panel
var end_panel: PanelContainer
var end_title: Label
var end_break: Label
var name_edit: LineEdit
var board_box: VBoxContainer
var btn_next: Button


# ===========================================================================
# LIFECYCLE
# ===========================================================================

func _ready() -> void:
	level_index = Session.level_index
	_build_hud()
	_load_level(0)


func _process(delta: float) -> void:
	if state == State.READY:
		if Input.is_anything_pressed():
			state = State.PLAYING
			lbl_hint.visible = false
	elif state == State.PLAYING:
		elapsed += delta

	if _flash_t > 0.0:
		_flash_t -= delta

	_arrow_t += delta
	if order_mode != "any":
		queue_redraw()

	if state == State.PLAYING and is_instance_valid(player):
		# remember the last place the player was safely standing
		if player.is_on_floor():
			_safe_t += delta
			if _safe_t > 0.15:
				_safe_t = 0.0
				_safe_pos = player.global_position
		# fell through a hole in the aisle floor
		elif player.global_position.y > LevelData.FLOOR_Y + 420.0:
			player.global_position = _safe_pos
			player.velocity = Vector2.ZERO
			player.stumble()
			hits += 1

	if is_instance_valid(player) and is_instance_valid(camera):
		camera.global_position = player.global_position + Vector2(0.0, -70.0)

	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://menu.tscn")
			return
		if event.keycode == KEY_R:
			_load_level(level_index)


# ===========================================================================
# LEVEL BUILDING
# ===========================================================================

func _board_y(index: int) -> float:
	return LevelData.FLOOR_Y - float(index) * LevelData.SHELF_SPACING


func _load_level(index: int) -> void:
	var all := LevelData.levels()
	level_index = clampi(index, 0, all.size() - 1)
	level = all[level_index]

	if is_instance_valid(world):
		world.queue_free()
	world = Node2D.new()
	add_child(world)
	items.clear()

	_sheet = ShelfTheme.sheet_texture()

	var shelves: int = int(level["shelves"])
	level_cols = int(level.get("cols", LevelData.DEFAULT_COLS))
	level_width = float(level_cols) * LevelData.TILE
	var gaps: Array = level.get("gaps", [])

	# --- boards. Board 0 is solid floor; boards in between are one-way, so you
	#     jump up through them and press DOWN to drop back down. Gaps split a
	#     board into separate segments with nothing in between.
	#
	#     The TOP board is different: it is a solid ceiling, not a platform.
	#     Running along the roof skipped every hazard in the aisle, so the
	#     player now bonks their head on it instead of standing on it.
	segments.clear()
	for b in range(shelves + 1):
		var segs := _segments_for(b, gaps)
		segments[b] = segs
		if b == shelves:
			continue
		for sg in segs:
			_make_board_segment(sg.x, sg.y, _board_y(b), b > 0)

	_make_ceiling(level_width, _board_y(shelves))

	# --- optionally scatter the items across whatever solid board is free
	var item_defs: Array = (level["items"] as Array).duplicate(true)
	if bool(level.get("randomise", false)):
		_scatter(item_defs, level, gaps)

	# --- items
	for d in item_defs:
		var it := ShelfItem.new()
		it.id = str(d["id"])
		it.label = str(d["label"])
		it.coins = int(d["coins"])
		it.tex = Sprites.region_of(str(d.get("sheet", "")), int(d.get("sprite", -1)))
		it.position = Vector2(_col_x(int(d["col"])), _board_y(int(d["shelf"])))
		it.body_entered.connect(_on_item_touched.bind(it))
		world.add_child(it)
		items.append(it)

	# --- hazards
	for hd in level["hazards"]:
		var hz := Hazard.new()
		var by := _board_y(int(hd["shelf"]))
		hz.kind = str(hd.get("type", "spill"))
		hz.box = Hazard.box_for(hz.kind)
		hz.tex = Sprites.region_of(str(hd.get("sheet", "")), int(hd.get("sprite", -1)))
		hz.position = Vector2(_col_x(int(hd["col"])), by - hz.box.y * 0.5)
		hz.body_entered.connect(_on_hazard_touched.bind(hz))
		world.add_child(hz)

	# --- power-ups (optional detours, never on the shopping list)
	for pd in level.get("powerups", []):
		var pu := PowerUp.new()
		pu.kind = str(pd.get("kind", "boost"))
		pu.label = str(pd.get("label", "Power-up"))
		pu.tex = Sprites.region_of(str(pd.get("sheet", "")), int(pd.get("sprite", -1)))
		pu.position = Vector2(_col_x(int(pd["col"])), _board_y(int(pd["shelf"])))
		pu.body_entered.connect(_on_powerup_taken.bind(pu))
		world.add_child(pu)

	# --- freezer doors (visual only, drawn over everything in the aisle)
	var doors: Array = level.get("doors", [])
	if not doors.is_empty():
		var dl := DoorLayer.new()
		for d2 in doors:
			dl.tiles.append(Vector2i(int(d2["col"]), int(d2["shelf"])))
		dl.tile_size = LevelData.TILE
		dl.spacing = LevelData.SHELF_SPACING
		dl.board_h = LevelData.BOARD_HEIGHT
		dl.floor_y = LevelData.FLOOR_Y
		world.add_child(dl)

	# --- player
	player = Player.new()
	player.position = Vector2(_col_x(1), LevelData.FLOOR_Y)
	player.min_x = 30.0
	player.max_x = level_width - 30.0
	world.add_child(player)

	# --- camera
	camera = Camera2D.new()
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_right = int(level_width)
	camera.limit_top = int(_board_y(shelves) - 90.0)
	camera.limit_bottom = int(LevelData.FLOOR_Y + 140.0)
	world.add_child(camera)
	camera.global_position = player.global_position

	# --- run state
	player.floor_level = LevelData.FLOOR_Y
	_safe_pos = player.global_position
	_safe_t = 0.0

	# the home screen's choice wins over the level's own setting
	if Session.order_mode == "any":
		order_mode = "any"
	else:
		order_mode = str(level.get("order", "fixed"))
		if order_mode == "any":
			order_mode = "shuffle"   # ordered mode needs an actual order
	got.clear()

	var pick := int(level.get("pick", 0))
	if pick > 0:
		# an "all store" run: the list is drawn fresh from everything on the
		# shelves, so no two runs ask for the same trolley
		var pool: Array = []
		for it in items:
			pool.append(it.id)
		pool.shuffle()
		list_ids = pool.slice(0, mini(pick, pool.size()))
	else:
		list_ids = (level["list"] as Array).duplicate()

	if order_mode == "shuffle":
		list_ids.shuffle()
	list_pos = 0
	elapsed = 0.0
	coins = 0
	hits = 0
	state = State.READY

	end_panel.visible = false
	lbl_hint.visible = true
	lbl_hint.text = "Press any key to start   |   %s" % str(level["name"])
	_refresh_targets()
	_rebuild_list_rows()
	_update_hud()
	queue_redraw()


## Moves every item to a random free tile that actually has board under it.
## Hazards, power-ups, the spawn tile and holes are all excluded, so a scattered
## level is always completable.
func _scatter(defs: Array, lvl: Dictionary, gaps: Array) -> void:
	var shelves: int = int(lvl["shelves"])

	var blocked := {}
	blocked[Vector2i(1, 0)] = true                      # the spawn tile
	for g in gaps:
		blocked[Vector2i(int(g["col"]), int(g["shelf"]))] = true
	for h in lvl.get("hazards", []):
		blocked[Vector2i(int(h["col"]), int(h["shelf"]))] = true
	for p in lvl.get("powerups", []):
		blocked[Vector2i(int(p["col"]), int(p["shelf"]))] = true

	var free: Array = []
	for sh in range(shelves):
		for c in range(level_cols):
			var key := Vector2i(c, sh)
			if not blocked.has(key):
				free.append(key)

	if free.size() < defs.size():
		push_warning("Not enough free tiles to scatter every item; leaving them put.")
		return

	free.shuffle()
	for i in range(defs.size()):
		defs[i]["col"] = free[i].x
		defs[i]["shelf"] = free[i].y


## Returns the solid stretches of a board once its missing tiles are cut out.
## Adjacent gap tiles merge into a single hole automatically.
func _segments_for(index: int, gaps: Array) -> Array:
	var hole := {}
	for g in gaps:
		if int(g.get("shelf", -1)) == index:
			hole[int(g.get("col", -1))] = true

	var segs: Array = []
	var run := -1
	for c in range(level_cols):
		if hole.has(c):
			if run >= 0:
				segs.append(Vector2(float(run) * LevelData.TILE, float(c) * LevelData.TILE))
				run = -1
		elif run < 0:
			run = c
	if run >= 0:
		segs.append(Vector2(float(run) * LevelData.TILE, level_width))
	return segs


## In ordered mode, a chevron floats above the shopper pointing at whatever
## they need next. Without it an ordered run is guesswork on a 161-tile aisle.
func _draw_guide_arrow() -> void:
	if order_mode == "any" or state != State.PLAYING or not is_instance_valid(player):
		return
	if list_pos >= list_ids.size():
		return
	var target_id := str(list_ids[list_pos])
	var target: ShelfItem = null
	for it in items:
		if it.id == target_id and not it.collected:
			target = it
			break
	if target == null:
		return

	var from := player.global_position + Vector2(0.0, -Player.BODY_H - 34.0)
	var dir := (target.global_position - from).normalized()
	var bob := sin(_arrow_t * 3.4) * 5.0
	var origin := from + Vector2(0.0, bob)

	var tip := origin + dir * 22.0
	var back := origin - dir * 8.0
	var side := dir.orthogonal() * 12.0
	var pts := PackedVector2Array([tip, back + side, back - side])
	draw_colored_polygon(pts, Color(0.99, 0.79, 0.16, 0.92))
	draw_polyline(PackedVector2Array([tip, back + side, back - side, tip]),
		Color(0.20, 0.16, 0.10, 0.85), 2.0)


## Draws one tile from the industrial sheet at world position x,y.
## width_mult lets a tile be drawn narrower than a full grid square.
func _blit(index: int, x: float, y: float, width_mult: float = 1.0) -> void:
	if _sheet == null:
		return
	var wdt := LevelData.TILE * width_mult
	var off := (LevelData.TILE - wdt) * 0.5
	draw_texture_rect_region(_sheet,
		Rect2(x + off, y, wdt, LevelData.TILE),
		ShelfTheme.region(index))


## Centre of a tile column in world space.
func _col_x(col: int) -> float:
	return (float(col) + 0.5) * LevelData.TILE


## A single unbroken slab across the whole aisle, sitting just above the highest
## shelf. Solid from every direction, so there is no way on top of it.
func _make_ceiling(width: float, y: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width + LevelData.TILE * 2.0, LevelData.TILE)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	# the slab's UNDERSIDE sits on the old board line
	cs.position = Vector2(width * 0.5, y + LevelData.TILE * 0.5)
	body.add_child(cs)
	world.add_child(body)


func _make_board_segment(x0: float, x1: float, y: float, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, LevelData.BOARD_HEIGHT)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2((x0 + x1) * 0.5, y + LevelData.BOARD_HEIGHT * 0.5)
	cs.one_way_collision = one_way
	cs.one_way_collision_margin = 10.0
	body.add_child(cs)
	world.add_child(body)


# ===========================================================================
# GAMEPLAY EVENTS
# ===========================================================================

func _on_item_touched(body: Node, it: ShelfItem) -> void:
	if state != State.PLAYING or not (body is Player):
		return
	if it.collected or list_pos >= list_ids.size():
		return

	if order_mode == "any":
		# any listed item counts, whenever you reach it
		if not list_ids.has(it.id) or got.has(it.id):
			return
		got[it.id] = true
	elif it.id != str(list_ids[list_pos]):
		return   # the list must be collected in sequence

	it.collected = true
	it.visible = false
	it.set_deferred("monitoring", false)
	coins += it.coins
	list_pos += 1
	_refresh_targets()
	_rebuild_list_rows()

	if list_pos >= list_ids.size():
		_finish()


func _on_powerup_taken(body: Node2D, pu: PowerUp) -> void:
	if state != State.PLAYING or pu.taken or body != player:
		return
	pu.collect()
	match pu.kind:
		"boost":
			player.give_boost()
			_flash(pu.label + "!")
		"clean":
			player.clear_slow()
			_flash(pu.label + "!")
		"coins":
			coins += 3
			_flash(pu.label + "  +3")


func _on_hazard_touched(body: Node, hz: Hazard) -> void:
	if state != State.PLAYING or not (body is Player):
		return
	if not player.can_be_hit():
		return

	match hz.effect():
		"stun":
			player.apply_stun(1.0, false)
			_flash("Slipped!")
		"bubble":
			player.apply_stun(1.8, true)
			_flash("Bubbled!")
		"slip":
			player.apply_slip(3.0)
			_flash("Ice!")
		_:
			player.apply_slow(hz.global_position.x)
	hits += 1


func _refresh_targets() -> void:
	if order_mode == "any":
		# everything still outstanding is a valid target
		for it in items:
			it.set_target(list_ids.has(it.id) and not it.collected)
		return
	var target_id := ""
	if list_pos < list_ids.size():
		target_id = str(list_ids[list_pos])
	for it in items:
		it.set_target(it.id == target_id and not it.collected)


func final_score() -> float:
	return elapsed - float(coins) * SECONDS_PER_COIN


func _finish() -> void:
	state = State.FINISHED
	if is_instance_valid(player):
		player.set_physics_process(false)

	end_title.text = "%s  -  list complete" % str(level["name"])
	end_break.text = "Time %.1fs      Hazards hit %d      Coins %d (-%.1fs)\nFINAL SCORE   %.1f" % [
		elapsed, hits, coins, float(coins) * SECONDS_PER_COIN, final_score()
	]
	name_edit.text = ""
	btn_next.disabled = level_index >= LevelData.levels().size() - 1
	end_panel.visible = true
	_refresh_board(Leaderboard.for_level(str(level["name"])))
	name_edit.grab_focus()


# ===========================================================================
# HUD
# ===========================================================================

## Applies a Kenney UI button skin. Silently does nothing if the PNGs are
## missing, so the game still runs on a bare checkout.
func _style_button(b: Button, colour: String) -> void:
	var font := Session.ui_font()
	if font != null:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.62))
	b.custom_minimum_size = Vector2(140.0, 52.0)
	var sb := Session.button_style(colour)
	if sb == null:
		return
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)


func _mk_label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	var f := Session.ui_font()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.88)
	sb.border_color = Color(0.99, 0.79, 0.16, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	return sb


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	# ---- top-left stats
	var left := VBoxContainer.new()
	left.position = Vector2(18, 14)
	left.add_theme_constant_override("separation", 2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)

	lbl_level = _mk_label("", 15, Color(0.75, 0.80, 0.88))
	lbl_time = _mk_label("", 30, Color(1, 1, 1))
	lbl_coins = _mk_label("", 17, Color(0.99, 0.79, 0.16))
	lbl_score = _mk_label("", 20, Color(0.55, 0.90, 0.65))
	left.add_child(lbl_level)
	left.add_child(lbl_time)
	left.add_child(lbl_coins)
	left.add_child(lbl_score)

	# ---- top-right shopping list
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _panel_style())
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-250, 14)
	right.custom_minimum_size = Vector2(228, 0)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 3)
	right.add_child(list_box)

	# ---- bottom hint
	lbl_hint = _mk_label("", 17, Color(1, 1, 1, 0.85))
	lbl_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl_hint.position = Vector2(-300, -70)
	lbl_hint.custom_minimum_size = Vector2(600, 0)
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lbl_hint)

	# ---- controls reminder
	var ctrl := _mk_label(
		"LEFT / RIGHT move  •  UP or SPACE jump  •  DOWN + JUMP drop through a shelf  •  R restart",
		13, Color(1, 1, 1, 0.45))
	ctrl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ctrl.position = Vector2(-360, -30)
	ctrl.custom_minimum_size = Vector2(720, 0)
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(ctrl)

	_build_end_panel(root)


func _build_end_panel(root: Control) -> void:
	end_panel = PanelContainer.new()
	var pstyle: StyleBox = Session.panel_style()
	if pstyle == null:
		pstyle = _panel_style()
	end_panel.add_theme_stylebox_override("panel", pstyle)
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-250, -230)
	end_panel.custom_minimum_size = Vector2(500, 0)
	end_panel.visible = false
	root.add_child(end_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	end_panel.add_child(v)

	end_title = _mk_label("", 22, Color(0.99, 0.79, 0.16))
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_title)

	end_break = _mk_label("", 16, Color(1, 1, 1))
	end_break.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_break)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Your name"
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_edit)

	var btn_save := Button.new()
	btn_save.text = "Save score"
	btn_save.pressed.connect(_on_save_pressed)
	_style_button(btn_save, "yellow")
	row.add_child(btn_save)

	var sep := _mk_label("Best times - this aisle", 14, Color(0.75, 0.80, 0.88))
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sep)

	board_box = VBoxContainer.new()
	board_box.add_theme_constant_override("separation", 2)
	v.add_child(board_box)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row2)

	var btn_menu := Button.new()
	btn_menu.text = "Home"
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	_style_button(btn_menu, "grey")
	row2.add_child(btn_menu)

	var btn_retry := Button.new()
	btn_retry.text = "Retry (R)"
	btn_retry.pressed.connect(func(): _load_level(level_index))
	_style_button(btn_retry, "blue")
	row2.add_child(btn_retry)

	btn_next = Button.new()
	btn_next.text = "Next aisle"
	btn_next.pressed.connect(func(): _load_level(level_index + 1))
	_style_button(btn_next, "green")
	row2.add_child(btn_next)


func _on_save_pressed() -> void:
	var rows := Leaderboard.submit(name_edit.text, final_score(), str(level["name"]))
	_refresh_board(rows)
	name_edit.editable = false


func _refresh_board(rows: Array) -> void:
	for c in board_box.get_children():
		board_box.remove_child(c)
		c.queue_free()
	if rows.is_empty():
		board_box.add_child(_mk_label("  no scores yet", 14, Color(1, 1, 1, 0.5)))
		return
	var rank := 1
	for e in rows:
		var line := "%2d.  %-14s  %6.1f" % [rank, str(e.get("name", "?")), float(e.get("score", 0.0))]
		var col := Color(0.99, 0.79, 0.16) if rank == 1 else Color(1, 1, 1, 0.85)
		board_box.add_child(_mk_label(line, 14, col))
		rank += 1


func _rebuild_list_rows() -> void:
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()

	var head_txt := "SHOPPING LIST" if order_mode == "any" else "SHOPPING LIST  (in order)"
	list_box.add_child(_mk_label(head_txt, 14, Color(0.99, 0.79, 0.16)))

	var defs: Dictionary = {}
	for d in level["items"]:
		defs[str(d["id"])] = d

	for i in range(list_ids.size()):
		var id := str(list_ids[i])
		var d: Dictionary = defs.get(id, {})
		var name_txt: String = str(d.get("label", id))

		var done := got.has(id) if order_mode == "any" else i < list_pos
		var is_next := (not done) and order_mode != "any" and i == list_pos

		var tint := Color(1, 1, 1, 0.45)
		if done:
			tint = Color(0.55, 0.90, 0.65, 0.6)
		elif is_next or order_mode == "any":
			tint = Color(1, 1, 1)

		list_box.add_child(_list_row(d, name_txt, done, is_next, tint))


## One line of the list: the item's own sprite (or a coloured chip if it has
## none yet) followed by its name, so you are looking for a picture not a word.
func _list_row(d: Dictionary, name_txt: String, done: bool, is_next: bool,
		tint: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)

	var marker := _mk_label(">" if is_next else " ", 15, tint)
	marker.custom_minimum_size = Vector2(12.0, 0.0)
	row.add_child(marker)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26.0, 26.0)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = tint
	var tex := Sprites.region_of(str(d.get("sheet", "")), int(d.get("sprite", -1)))
	if tex != null:
		icon.texture = tex
	else:
		# no art assigned yet: a coloured chip keyed off the item's type, so the
		# list still reads at a glance
		icon.texture = _chip(str(d.get("type", "box")))
	row.add_child(icon)

	var lbl := _mk_label(name_txt, 15, tint)
	if done:
		lbl.text = name_txt + "  ok"
	row.add_child(lbl)
	return row


## A small solid swatch, cached per type. Placeholder until real item art lands.
func _chip(type_name: String) -> Texture2D:
	if _chips.has(type_name):
		return _chips[type_name]
	var h := float(abs(type_name.hash()) % 360) / 360.0
	var col := Color.from_hsv(h, 0.55, 0.92)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(col)
	for i in range(8):
		img.set_pixel(i, 0, col.darkened(0.35))
		img.set_pixel(i, 7, col.darkened(0.35))
		img.set_pixel(0, i, col.darkened(0.35))
		img.set_pixel(7, i, col.darkened(0.35))
	var tex := ImageTexture.create_from_image(img)
	_chips[type_name] = tex
	return tex


## A short-lived message under the HUD, used for power-up pickups.
func _flash(txt: String) -> void:
	_flash_text = txt
	_flash_t = 1.6


func _update_hud() -> void:
	if lbl_time == null or level.is_empty():
		return
	lbl_level.text = "AISLE %d/%d   %s" % [
		level_index + 1, LevelData.levels().size(), str(level["name"])]
	lbl_time.text = "%.1fs" % elapsed
	lbl_coins.text = "Coins %d   (-%.1fs)   Hits %d" % [coins, float(coins) * SECONDS_PER_COIN, hits]
	lbl_score.text = "Score %.1f" % final_score()

	if is_instance_valid(player) and player.slow > 0.0:
		lbl_score.text += "   ** SLOWED **"
		lbl_score.add_theme_color_override("font_color", Color(0.72, 0.85, 0.42))
	elif is_instance_valid(player) and player.boost > 0.0:
		lbl_score.text += "   ** BOOSTED **"
		lbl_score.add_theme_color_override("font_color", Color(0.42, 0.86, 0.95))
	else:
		lbl_score.add_theme_color_override("font_color", Color(0.55, 0.90, 0.65))

	if _flash_t > 0.0:
		lbl_hint.text = _flash_text


# ===========================================================================
# WORLD RENDERING (no art assets - everything is drawn procedurally)
# ===========================================================================

func _draw() -> void:
	if level.is_empty():
		return

	var shelves: int = int(level["shelves"])
	var w := level_width
	var roof := _board_y(shelves)

	# store interior
	draw_rect(Rect2(-400.0, roof - 500.0, w + 800.0, LevelData.FLOOR_Y - roof + 1000.0),
		Color(0.14, 0.16, 0.20), true)

	# shelf unit carcass
	draw_rect(Rect2(0.0, roof, w, LevelData.FLOOR_Y - roof), Color(0.23, 0.26, 0.31), true)

	# alternating shelf backs
	for b in range(shelves):
		var by := _board_y(b)
		var back := Rect2(0.0, by - LevelData.SHELF_SPACING + LevelData.BOARD_HEIGHT,
			w, LevelData.SHELF_SPACING - LevelData.BOARD_HEIGHT)
		var shade := Color(0.28, 0.31, 0.37) if b % 2 == 0 else Color(0.25, 0.28, 0.34)
		draw_rect(back, shade, true)

	# section banners, used by the combined all-store level
	var font := ThemeDB.fallback_font
	for sc in level.get("sections", []):
		var sxp := float(int(sc["col"])) * LevelData.TILE
		draw_line(Vector2(sxp, roof - 8.0), Vector2(sxp, LevelData.FLOOR_Y),
			Color(1.0, 0.79, 0.16, 0.20), 3.0)
		draw_string(font, Vector2(sxp + 14.0, roof - 18.0), str(sc["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.82, 0.30, 0.75))

	# faint tile grid so the shelf reads as built from units
	var grid := Color(1.0, 1.0, 1.0, 0.045)
	for c in range(level_cols + 1):
		var gx := float(c) * LevelData.TILE
		draw_line(Vector2(gx, roof), Vector2(gx, LevelData.FLOOR_Y), grid, 1.0)

	# --- racking uprights, drawn behind everything on the shelves
	if _sheet != null:
		var c := 0
		while c < level_cols:
			var px := float(c) * LevelData.TILE
			for b3 in range(shelves):
				var oy := _board_y(b3) - LevelData.SHELF_SPACING + LevelData.TILE
				var idx := ShelfTheme.POST_BRACE if b3 % 2 == 0 else ShelfTheme.POST_PLAIN
				_blit(idx, px, oy, 0.55)
			_blit(ShelfTheme.POST_FOOT, px, _board_y(0) - LevelData.TILE, 0.55)
			c += ShelfTheme.POST_EVERY

	# --- boards. Only the solid segments, so gaps read as genuine holes.
	#     The beam hangs BELOW the walking surface, the way a real shelf does.
	for b2 in range(shelves + 1):
		var yy := _board_y(b2)
		var runs: Array = segments.get(b2, [])
		if b2 == shelves:
			runs = [Vector2(0.0, w)]     # the ceiling is never broken
		for sg in runs:
			if _sheet == null:
				var seg_w: float = sg.y - sg.x
				draw_rect(Rect2(sg.x, yy, seg_w, LevelData.BOARD_HEIGHT), Color(0.80, 0.82, 0.86), true)
				draw_rect(Rect2(sg.x, yy, seg_w, 4.0), Color(0.95, 0.96, 0.98), true)
				continue
			var c0 := int(round(sg.x / LevelData.TILE))
			var c1 := int(round(sg.y / LevelData.TILE))
			for cc in range(c0, c1):
				var idx := ShelfTheme.BEAM_MID
				if cc == c0:
					idx = ShelfTheme.BEAM_LEFT
				elif cc == c1 - 1:
					idx = ShelfTheme.BEAM_RIGHT
				_blit(idx, float(cc) * LevelData.TILE, yy)
			# yellow/black stripe on the exposed end of a broken board
			if sg.x > 1.0:
				_blit(ShelfTheme.STRIPE, sg.x, yy, 0.5)
			if sg.y < w - 1.0:
				_blit(ShelfTheme.STRIPE, sg.y - LevelData.TILE * 0.5, yy, 0.5)

	# aisle floor
	draw_rect(Rect2(-400.0, LevelData.FLOOR_Y + LevelData.BOARD_HEIGHT, w + 800.0, 400.0),
		Color(0.18, 0.20, 0.24), true)

	_draw_guide_arrow()
