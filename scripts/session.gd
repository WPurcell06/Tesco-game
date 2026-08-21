class_name Session
extends RefCounted

# Which aisle the player picked on the home screen. Static so it survives a
# scene change without needing an autoload.

static var level_index := 0

## Chosen on the home screen and applied to every aisle.
##   "ordered"  follow the list top to bottom, an arrow points at the next item
##   "any"      grab them in whatever order you like
static var order_mode := "ordered"


static func best_for(level_name: String) -> float:
	var rows := Leaderboard.for_level(level_name)
	var best := INF
	for r in rows:
		best = minf(best, float(r.get("score", INF)))
	return best


static func ui_font() -> FontFile:
	var path := "res://ui/font/KenneyFutureNarrow.ttf"
	if ResourceLoader.exists(path):
		return load(path) as FontFile
	return null


## Kenney's button PNGs have a chunky bevel, so the nine-patch margins keep the
## corners crisp at any size.
static func button_style(colour: String) -> StyleBoxTexture:
	var path := "res://ui/%s_button.png" % colour
	if not ResourceLoader.exists(path):
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.set_texture_margin(SIDE_LEFT, 18.0)
	sb.set_texture_margin(SIDE_RIGHT, 18.0)
	sb.set_texture_margin(SIDE_TOP, 18.0)
	sb.set_texture_margin(SIDE_BOTTOM, 22.0)
	sb.set_content_margin(SIDE_LEFT, 18.0)
	sb.set_content_margin(SIDE_RIGHT, 18.0)
	sb.set_content_margin(SIDE_TOP, 10.0)
	sb.set_content_margin(SIDE_BOTTOM, 16.0)
	return sb


static func panel_style() -> StyleBoxTexture:
	var path := "res://ui/panel.png"
	if not ResourceLoader.exists(path):
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 20.0)
		sb.set_content_margin(side, 22.0)
	return sb
