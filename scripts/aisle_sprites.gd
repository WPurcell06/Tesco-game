class_name AisleSprites
extends RefCounted

# Named indices into the three hand-drawn aisle sheets that sit alongside
# sprites/grocery.png. Same lookup path as everything else (Sprites.region_of),
# so each sheet is a uniform grid read left-to-right, top-to-bottom.
#
# Grid geometry - this MUST match the sheet config in LevelData.sheets():
#   treats.png    tile 32x32,   6 columns  (12 sprites, 2 rows)
#   poultry.png   tile 32x32,   2 columns  (4 sprites, 2 rows)
#   beauty.png    tile 120x120, 3 columns  (6 cells, 2 rows - index 5 is empty)
#
# Two families, by role:
#   plain       shopping-list items, good to collect
#   angry       hazards - a scowling version of the same product
#
# The pixel-art sheets (treats, poultry) are packed 1:1 from 32x32 Piskel
# exports. beauty.png is the odd one: the four makeup images are full-colour
# art pasted unscaled and centred in their 120x120 cells, and the soap monster
# is a 32x22 pixel sprite scaled 3x (96x66) with nearest-neighbour so it stays
# crisp next to them.

const TREATS  := "treats.png"
const POULTRY := "poultry.png"
const BEAUTY  := "beauty.png"


# --- collectables ------------------------------------------------------------

# treats.png, row 0 - the sweets aisle shopping list
const CAKE       := 0
const DONUT      := 1
const LOLLIPOP   := 2
const CONE_PLAIN := 3
const CONE_CHOC  := 4
const ICE_LOLLY  := 5

# poultry.png, row 0 - the meat counter
const ROAST_CHICKEN := 0
const DRUMSTICK     := 1

# beauty.png, row 0 + first cell of row 1 - the health & beauty aisle
const BLUSHER_PEACH := 0
const LIPSTICK_RED  := 1
const BLUSHER_DARK  := 2
const LIPSTICK_GREEN := 3


# --- hazards (angry products) ------------------------------------------------
# Hazard.gd stretches a plain rectangle over the sprite, so the art's own
# aspect ratio decides which hazard "kind" it should be tagged with in
# level_data.gd. All of these are roughly square icons, so "crate" (square box,
# "slow" effect) fits them better than the flat "peel" box.

# treats.png, row 1 - angry counterparts of the sweets, same order as row 0
const ANGRY_MARSHMALLOW := 6    # kind "crate" - square-ish blob
const ANGRY_DONUT       := 7    # kind "crate" - square
const ANGRY_GUMMY       := 8    # kind "crate" - square-ish blob
const ANGRY_CONE        := 9    # kind "crate" - tall, but closer to square than flat
const ANGRY_CANDY       := 10   # kind "crate" - square-ish
const ANGRY_ICE_LOLLY   := 11   # kind "crate" - tall, but closer to square than flat

# poultry.png, row 1 - angry counterparts of the meat counter
const ANGRY_ROAST_CHICKEN := 2  # kind "crate" - square-ish
const ANGRY_DRUMSTICK     := 3  # kind "crate" - square-ish

# beauty.png - the lone health & beauty hazard
const ANGRY_SOAP := 4           # kind "crate" - a wide-ish bubble, still boxy

# beauty.png index 5 is deliberately blank - the sheet is a 3x2 grid with only
# five sprites in it. Don't point a level at it.
