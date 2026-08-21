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
const POST_PLAIN := 36
const POST_BRACE := 37
const POST_FOOT  := 68
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
