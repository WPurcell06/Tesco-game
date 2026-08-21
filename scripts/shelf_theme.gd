class_name ShelfTheme
extends RefCounted

# Which tiles from sprites/industrial.png build the shop shelving.
# Indices come from the Kenney Pixel Platformer Industrial Expansion tilemap
# (16 columns of 18x18). Change these numbers to restyle every aisle at once.

const SHEET := "industrial.png"
const COLS  := 16
const T     := 18

# --- the walkable shelf boards: orange I-beam, capped at each end -----------
const BEAM_LEFT  := 4
const BEAM_MID   := 5
const BEAM_RIGHT := 6

# --- the racking uprights standing between shelves --------------------------
# Kenney authored the support column as a THREE-PIECE assembly down one column
# of the tilemap, and it only looks right assembled that way:
#
#   POST_HEAD (38)  the beam tile that already has the two post tops attached.
#                   Replaces the plain beam tile wherever a column stands, so
#                   the post visibly meets the shelf instead of butting it.
#   POST_BODY (54)  the twin-shaft section. Its art runs edge to edge top and
#                   bottom, so any number of them stack seamlessly.
#   POST_FOOT (70)  the light footing plate that caps the bottom.
#
# All three are FULL TILE WIDTH - draw them at width_mult 1.0. Drawing the post
# narrower squashes two shafts into one smear.
#
# Do NOT use 36 / 37 / 68 (girder fragments - an "H" and a diagonal brace, with
# transparent gaps at the tile edges, so a stack reads as floating glyphs), and
# do NOT use 43: that is the LADDER, not a post.
const POST_HEAD  := 38
const POST_BODY  := 54
const POST_FOOT  := 70
const POST_EVERY := 5     # draw an upright every N tiles

# --- the yellow/black stripe used on a broken board's exposed end -----------
const STRIPE := 87

# --- aisle floor and back panel --------------------------------------------
const FLOOR_TILE := 1
const BACK_TILE  := 33


static func sheet_texture() -> Texture2D:
	var path := "res://sprites/" + SHEET
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func region(index: int) -> Rect2:
	return Rect2(float(index % COLS) * T, float(index / COLS) * T, T, T)
