class_name Player
extends CharacterBody2D

# The player is a shopper. Its origin sits at its FEET, which makes placing it
# on a shelf board trivial: just set position.y to the board top.
#
# Art: sprites/player.png, a 32x64 sheet holding two 32x32 frames.
#   frame 0  standing
#   frame 1  mid-stride
# The body occupies x 3..19, y 5..25 inside a frame. Drawn at 3x, so the visible
# shopper is 48x60 and every source pixel is exactly three screen pixels.

const SPEED         := 360.0
const ACCEL         := 2160.0
const FRICTION      := 1980.0
const JUMP_VELOCITY := -830.0   # reaches 216px = exactly 4 tiles, clears a 162px shelf
const GRAVITY       := 1600.0
const MAX_FALL      := 1350.0
const COYOTE_TIME   := 0.10     # grace period to still jump after walking off an edge
const JUMP_BUFFER   := 0.12     # grace period for pressing jump slightly too early
const BODY_W        := 34.0   # collision is narrower than the sprite, which
const BODY_H        := 58.0   # makes edge grabs and gap jumps feel fair

# --- sprite sheet geometry ---
const FRAME         := 32     # one cell in the source PNG
const ART_SCALE     := 3      # integer, so the pixels stay square
const BODY_LEFT     := 3      # bbox of the shopper inside a frame
const BODY_RIGHT    := 19
const BODY_BOTTOM   := 25
const RUN_FPS       := 9.0
const DROP_TIME     := 0.22     # how long collision is disabled when dropping through

# --- the trolley (this is Trolley Dash - the shopper needed one) ------------
# Drawn procedurally, same technique as the hazards/power-ups, rather than as
# a sprite: it's just lines and circles, and it needs to sit correctly on
# either side of the shopper depending on which way they're facing.
const TROLLEY_W        := 30.0    # basket depth in the facing direction
const TROLLEY_H         := 28.0    # rim to base
const TROLLEY_GAP       := 6.0     # clearance between the body and the near edge
const TROLLEY_WHEEL_R   := 4.0
const TROLLEY_CAGE      := Color(0.74, 0.80, 0.87)     # brushed-steel mesh
const TROLLEY_HANDLE    := Color(0.902, 0.114, 0.145)  # Tesco red grip

# --- hazard effect: you get bogged down rather than time-penalised ---
const SLOW_TIME       := 2.8    # seconds of sludge after a hit
const SLOW_SPEED_MULT := 0.35   # top speed while slowed
const SLOW_ACCEL_MULT := 0.45   # how sluggishly you get back up to that speed
const SLOW_JUMP_MULT  := 0.94   # CAREFUL: below ~0.92 you can no longer clear a
                                # 162px shelf gap and will be stuck until it wears off
const HIT_GRACE       := 0.5    # stops one hazard registering twice

# --- stun: you keep your momentum but lose the controls entirely ---
const STUN_FRICTION   := 810.0   # banana peel: you skid to a stop
const BUBBLE_FRICTION := 2340.0  # soap bubble: you stop dead and float

# --- tumble: clip a solid obstacle and you go over, sliding on your back ---
# A tumble is a variant of stun, not its own control path: same "no input"
# rule, different friction and a sprite that lies down. Two seconds is a long
# time to lose, which is why the hazard that caused it is knocked off the
# shelf on impact - you pay once and the obstacle is gone.
const TUMBLE_TIME      := 2.0
const TUMBLE_FRICTION  := 620.0   # lower than a skid: you slide a good way
const TUMBLE_POP_Y     := -260.0  # small hop, so it reads as knocked off your feet
const TUMBLE_PUSH_X    := 180.0
const TUMBLE_ANGLE     := 1.466   # 84 degrees in radians - flat out, not face down
const TUMBLE_TIP_TIME  := 0.18    # how fast you go over
const TUMBLE_RISE_TIME := 0.32    # how long scrambling back upright takes

# --- slip: ice is FASTER but barely steerable, which is the whole problem ---
const SLIP_SPEED_MULT := 1.30
const SLIP_ACCEL_MULT := 0.22
const SLIP_FRICTION   := 54.0

# --- power-up effect: the mirror image of the hazard slowdown ---
const BOOST_TIME       := 4.0
const BOOST_SPEED_MULT := 1.40
const BOOST_ACCEL_MULT := 1.35

var min_x := 0.0
var max_x := 2000.0

var slow := 0.0          # seconds of slowdown remaining
var boost := 0.0         # seconds of speed boost remaining
var stun := 0.0          # seconds of no control remaining
var slip := 0.0          # seconds of ice physics remaining
var bubbled := false     # cosmetic + friction variant of stun
var tumbling := false    # ditto: knocked off your feet, drawn lying down
var facing := 1.0
var _anim := 0.0
var _tex: Texture2D = null

var _grace := 0.0

var _coyote := 0.0
var _buffer := 0.0
var _drop := 0.0
var _pgdn_held := false
var floor_level := 600.0   # y of the aisle floor; you cannot drop through it
var _shape: CollisionShape2D
var _box: RectangleShape2D


func _ready() -> void:
	collision_layer = 2   # layer 2 = player
	collision_mask = 1    # collides with layer 1 = shelf boards
	floor_snap_length = 6.0
	_box = RectangleShape2D.new()
	_box.size = Vector2(BODY_W, BODY_H)
	_shape = CollisionShape2D.new()
	_shape.shape = _box
	_shape.position = Vector2(0.0, -BODY_H * 0.5)
	add_child(_shape)
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://sprites/player.png"):
		_tex = load("res://sprites/player.png")


func _physics_process(delta: float) -> void:
	if _drop > 0.0:
		_drop -= delta
		if _drop <= 0.0:
			collision_mask = 1

	if slow > 0.0:
		slow -= delta
	if boost > 0.0:
		boost -= delta
	if slip > 0.0:
		slip -= delta
	if stun > 0.0:
		stun -= delta
		if stun <= 0.0:
			bubbled = false
			tumbling = false
	if _grace > 0.0:
		_grace -= delta

	var grounded := is_on_floor()
	_coyote = COYOTE_TIME if grounded else maxf(_coyote - delta, 0.0)

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)

	# Down (or Page Down) on its own drops you through a shelf. No jump needed.
	var want_drop := Input.is_action_just_pressed("ui_down") \
		or Input.is_key_pressed(KEY_PAGEDOWN) and not _pgdn_held
	_pgdn_held = Input.is_key_pressed(KEY_PAGEDOWN)

	# --- vertical ---
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if stun > 0.0:
		_buffer = 0.0

	if want_drop and grounded and stun <= 0.0 and global_position.y < floor_level - 1.0:
		# drop through a one-way board. Blocked on the aisle floor, which is
		# solid ground and has nothing underneath it to fall to.
		Sfx.play("drop_through")
		_buffer = 0.0
		_drop = DROP_TIME
		collision_mask = 0
		velocity.y = 70.0
	elif _buffer > 0.0 and _coyote > 0.0:
		Sfx.play("jump")
		_buffer = 0.0
		_coyote = 0.0
		velocity.y = JUMP_VELOCITY * (SLOW_JUMP_MULT if slow > 0.0 else 1.0)

	# variable jump height: let go early for a shorter hop
	var released := Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")
	if released and velocity.y < JUMP_VELOCITY * 0.35:
		velocity.y = JUMP_VELOCITY * 0.35

	# --- horizontal ---
	# You keep full control when hit; you are just wading through it.
	# a slowdown always wins over a boost, so a hazard still stings
	var bogged := slow > 0.0
	var speed_mult := 1.0
	var accel_mult := 1.0
	var friction := FRICTION
	if bogged:
		speed_mult = SLOW_SPEED_MULT
		accel_mult = SLOW_ACCEL_MULT
	elif boost > 0.0:
		speed_mult = BOOST_SPEED_MULT
		accel_mult = BOOST_ACCEL_MULT

	# ice overrides the lot: quicker, but you can barely change direction
	if slip > 0.0:
		speed_mult = SLIP_SPEED_MULT
		accel_mult = SLIP_ACCEL_MULT
		friction = SLIP_FRICTION

	var dir := Input.get_axis("ui_left", "ui_right")
	if stun > 0.0:
		# controls are gone; a bubble pins you, a tumble slides you along on
		# your back, a peel lets you skid
		dir = 0.0
		if bubbled:
			friction = BUBBLE_FRICTION
		elif tumbling:
			friction = TUMBLE_FRICTION
		else:
			friction = STUN_FRICTION

	if absf(dir) > 0.01:
		var target := dir * SPEED * speed_mult
		velocity.x = move_toward(velocity.x, target, ACCEL * accel_mult * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()

	global_position.x = clampf(global_position.x, min_x, max_x)

	if absf(velocity.x) > 12.0:
		facing = signf(velocity.x)
	if is_on_floor() and absf(velocity.x) > 20.0:
		# stride rate follows actual speed, so a boost visibly reads faster
		_anim += delta * RUN_FPS * clampf(absf(velocity.x) / SPEED, 0.35, 1.8)
	else:
		_anim = 0.0
	queue_redraw()


## Returns true if the hit actually registered (i.e. the player was not
## already in their invulnerable window). The Game uses this so a single
## bump only costs one time penalty.
func take_hit(from_x: float) -> bool:
	if _grace > 0.0:
		return false
	_grace = HIT_GRACE
	slow = SLOW_TIME                      # refreshes rather than stacking
	# a light nudge so you are not left standing inside the hazard
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -1.0
	velocity.x = away * 140.0
	return true


## True if a hazard is allowed to register right now.
func can_be_hit() -> bool:
	return _grace <= 0.0


func apply_slow(from_x: float = INF) -> void:
	_grace = HIT_GRACE
	slow = SLOW_TIME
	if from_x != INF:
		var away := signf(global_position.x - from_x)
		velocity.x = (away if away != 0.0 else -1.0) * 140.0


func apply_stun(seconds: float, in_bubble: bool) -> void:
	_grace = HIT_GRACE
	stun = maxf(stun, seconds)
	bubbled = in_bubble
	if in_bubble:
		velocity.x = 0.0


func apply_slip(seconds: float) -> void:
	_grace = HIT_GRACE
	slip = maxf(slip, seconds)


## Knocked clean off your feet by a solid obstacle: no control for TUMBLE_TIME,
## popped up and pushed away from whatever you clipped, drawn lying down.
func apply_tumble(from_x: float) -> void:
	Sfx.play("player_tumble")
	_grace = HIT_GRACE
	stun = maxf(stun, TUMBLE_TIME)
	tumbling = true
	bubbled = false
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -1.0
	velocity.x = away * TUMBLE_PUSH_X
	velocity.y = TUMBLE_POP_Y


## Applied when the player falls through a hole in the aisle floor and gets
## put back on their last safe footing. Same cost as clipping a hazard.
func stumble() -> void:
	_grace = HIT_GRACE
	slow = SLOW_TIME


## --- power-up effects -------------------------------------------------------
func give_boost() -> void:
	boost = BOOST_TIME

func clear_slow() -> void:
	slow = 0.0


func _draw() -> void:
	# The trolley goes over with the shopper, so it is rotated by the same
	# angle - but NOT mirrored, because _draw_trolley already handles which
	# side of the body it sits on itself.
	var ang := _tumble_angle()
	if ang != 0.0:
		var pv := Vector2(0.0, -BODY_H * 0.5)
		draw_set_transform(pv - pv.rotated(ang), ang, Vector2.ONE)
	_draw_trolley()
	if ang != 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var tint := Color(1, 1, 1)
	if stun > 0.0:
		tint = Color(0.80, 0.68, 1.00) if bubbled else Color(1.00, 0.94, 0.55)
	elif slip > 0.0:
		tint = Color(0.72, 0.94, 1.00)
	elif slow > 0.0:
		tint = Color(0.62, 0.72, 0.52)
	elif boost > 0.0:
		tint = Color(0.62, 0.96, 1.00)

	# a soap bubble is drawn around the shopper, not over them
	if stun > 0.0 and bubbled:
		draw_circle(Vector2(0.0, -BODY_H * 0.5), BODY_H * 0.72, Color(0.72, 0.86, 1.0, 0.28))
		draw_arc(Vector2(0.0, -BODY_H * 0.5), BODY_H * 0.72, 0.0, TAU, 32,
			Color(0.90, 0.96, 1.0, 0.75), 3.0, true)

	if _tex == null:
		_draw_fallback(tint)
		return

	var frame := 0
	if not is_on_floor():
		frame = 1                       # mid-stride reads well as airborne
	elif _anim > 0.0:
		frame = int(_anim) % 2
	if stun > 0.0:
		frame = 0

	# Origin is at the feet, so the frame is offset to put BODY_BOTTOM on y = 0
	# and the horizontal centre of the body on x = 0.
	var cell := float(FRAME * ART_SCALE)
	var body_mid := float(BODY_LEFT + BODY_RIGHT) * 0.5 * float(ART_SCALE)
	var dest := Rect2(-body_mid, -float(BODY_BOTTOM * ART_SCALE), cell, cell)
	var src := Rect2(0.0, float(frame * FRAME), float(FRAME), float(FRAME))

	# One transform covers both the facing flip and the tumble. The pivot is
	# the shopper's MIDDLE, not their feet: rotating about the feet reads as
	# the sprite spinning on the spot, about the middle it reads as falling.
	var flip := Vector2(-1.0, 1.0) if facing < 0.0 else Vector2.ONE
	var posed := ang != 0.0 or facing < 0.0
	if posed:
		var pivot := Vector2(0.0, -BODY_H * 0.5)
		draw_set_transform(pivot - pivot.rotated(ang), ang, flip)
	draw_texture_rect_region(_tex, dest, src, tint)
	if posed:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## How far over the shopper has toppled, 0 when upright. Tips over fast, holds
## there, then scrambles back up just before control returns - so the sprite is
## always standing again by the time the player can move.
##
## Multiplied by facing so they always go over FORWARDS. The sprite flip is a
## negative x scale, which mirrors the rotation too, and the two cancel out.
func _tumble_angle() -> float:
	if not tumbling or stun <= 0.0:
		return 0.0
	var elapsed := TUMBLE_TIME - stun
	var down := clampf(elapsed / TUMBLE_TIP_TIME, 0.0, 1.0)
	var up := clampf(stun / TUMBLE_RISE_TIME, 0.0, 1.0)
	var facing_sign := facing if facing != 0.0 else 1.0
	return TUMBLE_ANGLE * minf(down, up) * facing_sign


## A wireframe shopping trolley, pushed ahead of the shopper in whichever
## direction they're facing. No art asset for this exists, so it's drawn the
## same way the hazards without sprites are: lines, arcs and circles.
func _draw_trolley() -> void:
	var dir := facing if facing != 0.0 else 1.0
	var near_x := dir * (BODY_W * 0.5 + TROLLEY_GAP)
	var far_x := near_x + dir * TROLLEY_W
	var rim_y := -TROLLEY_H - 4.0    # basket rim, roughly waist height
	var base_y := -6.0               # basket floor, just above the wheels

	# the cage is a trapezoid, narrower at the base than the rim like a real
	# shopping trolley, not a plain box
	var rim_near := Vector2(near_x, rim_y)
	var rim_far := Vector2(far_x, rim_y)
	var base_far := Vector2(far_x - dir * 4.0, base_y)
	var base_near := Vector2(near_x + dir * 4.0, base_y)
	draw_polyline(PackedVector2Array([rim_near, rim_far, base_far, base_near, rim_near]),
		TROLLEY_CAGE, 2.0, true)
	for f in [0.35, 0.68]:
		draw_line(rim_near.lerp(base_near, f), rim_far.lerp(base_far, f), TROLLEY_CAGE, 1.5)

	# wheels, with a spinning spoke so it reads as rolling even at a standstill
	var spin := _anim * 2.2
	var spoke := Vector2(cos(spin), sin(spin)) * TROLLEY_WHEEL_R
	# float(wx): an inline array literal is untyped, so wx arrives as a Variant
	for wx in [base_near.x, base_far.x]:
		var wp := Vector2(float(wx), base_y + 3.0)
		draw_circle(wp, TROLLEY_WHEEL_R, Color(0.16, 0.16, 0.18))
		draw_line(wp - spoke, wp + spoke, Color(0.55, 0.58, 0.62), 1.0)

	# handle, rising back toward the shopper's hands
	var grip := rim_near + Vector2(-dir * 2.0, -14.0)
	draw_line(rim_near, grip, TROLLEY_HANDLE, 2.5)
	draw_line(grip, grip - Vector2(dir * 8.0, 0.0), TROLLEY_HANDLE, 2.5)


## Used only if sprites/player.png is missing, so the game still runs.
func _draw_fallback(tint: Color) -> void:
	var r := Rect2(-BODY_W * 0.5, -BODY_H, BODY_W, BODY_H)
	draw_rect(r, tint * Color(0.99, 0.79, 0.16), true)
	draw_rect(r, Color(0.14, 0.12, 0.11), false, 3.0)
	draw_circle(Vector2(facing * 6.0, -BODY_H * 0.72), 4.0, Color(0.14, 0.12, 0.11))

	# sludge clinging to the bottom while slowed
	if slow > 0.0:
		var goo := Color(0.42, 0.55, 0.28, clampf(slow / SLOW_TIME, 0.25, 0.85))
		draw_arc(Vector2.ZERO, BODY_W * 0.5 + 3.0, 0.15 * PI, 0.85 * PI, 18, goo, 5.0, true)
