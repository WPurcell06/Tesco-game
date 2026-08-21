class_name GroceryTheme
extends RefCounted

# Named indices into sprites/grocery.png, a 7-column packed sheet of the
# hand-painted produce icons used by Produce Pursuit (aisle 1).
#
# The source art (a 4x7-ish irregular contact sheet, some rows short) was
# cropped icon-by-icon and repacked into this uniform 96x96 grid so it can
# be looked up the same way as every other sheet, through Sprites.region_of.
#
# Three families, by role:
#   plain fruit/veg    shopping-list items, good to collect
#   angry fruit/veg    hazards - a rotten/annoyed version of the same food,
#                      tagged "peel" or "crate" in level_data.gd depending on
#                      whether the icon is flat or square (see below)
#   sparkly fruit/veg  power-ups - golden/frozen/crowned variants, plus a can
#                      of beans standing in as a fourth bonus pickup

const SHEET := "grocery.png"

# --- collectables ------------------------------------------------------------
const APPLE_RED     := 0
const APPLE_GREEN   := 1
const PEAR          := 2
const CABBAGE       := 3
const BROCCOLI      := 4
const CARROT        := 5
const CORN          := 6
const STRAWBERRY    := 7
const TOMATO        := 8
const PEPPER_GREEN  := 9
const GRAPES        := 10
const ORANGE        := 11
const WATERMELON    := 12

# --- hazards (angry produce) -------------------------------------------------
# Hazard.gd's hitbox is a plain stretched rectangle, so the sprite's own
# aspect ratio decides which hazard "kind" it should be tagged with in
# level_data.gd: PEEL_ANGRY and TOMATO_ANGRY are wide/flat, a natural fit for
# the "peel" kind's low box (and its stun effect). Everything else here is a
# roughly square icon and goes under "crate" instead (square box, "slow"
# effect) so it isn't squashed into a banana-peel-shaped hitbox.
const PEEL_ANGRY       := 13   # kind "peel" - flat, matches the low hitbox
const APPLE_ANGRY      := 14   # kind "crate" - square-ish
const PEAR_ANGRY       := 15   # kind "crate" - tall, but closer to square than flat
const BROCCOLI_ANGRY   := 16   # kind "crate" - square
const CARROT_ANGRY     := 17   # kind "crate" - tall, but closer to square than flat
const CABBAGE_ANGRY    := 18   # kind "crate" - square-ish
const CORN_ANGRY       := 19   # kind "crate" - square
const TOMATO_ANGRY     := 20   # kind "peel" - a wide splat, matches the low hitbox
const ORANGE_ANGRY     := 21   # kind "crate" - square-ish
const STRAWBERRY_ANGRY := 22   # kind "crate" - square-ish


# --- power-ups ----------------------------------------------------------------
const APPLE_GOLDEN  := 23   # boost
const PEAR_FROZEN   := 24   # clean
const BROCCOLI_KING := 25   # coins
const BEANS_CAN     := 26   # coins (second flavour, so it isn't a repeat)
