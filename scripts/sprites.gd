class_name Sprites
extends RefCounted

# Turns a (sheet, index) reference from the level designer into an AtlasTexture.
#
# Sheet PNGs live in res://sprites/. If a sheet is missing the lookup returns
# null and the entity falls back to its procedural drawing, so the game always
# runs whether or not art has been dropped in yet.

static var _cache: Dictionary = {}


static func region_of(sheet_name: String, index: int) -> Texture2D:
	if sheet_name.is_empty() or index < 0:
		return null

	var cfg: Dictionary = LevelData.sheets().get(sheet_name, {})
	if cfg.is_empty():
		return null

	var base: Texture2D = _load_sheet(sheet_name)
	if base == null:
		return null

	var tw: int = int(cfg.get("tile_w", 64))
	var th: int = int(cfg.get("tile_h", 64))
	var margin: int = int(cfg.get("margin", 0))
	var spacing: int = int(cfg.get("spacing", 0))
	var cols: int = maxi(1, int(cfg.get("cols", 1)))

	var cx: int = index % cols
	var cy: int = index / cols

	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = Rect2(
		margin + cx * (tw + spacing),
		margin + cy * (th + spacing),
		tw, th)
	return atlas


static func _load_sheet(sheet_name: String) -> Texture2D:
	if _cache.has(sheet_name):
		return _cache[sheet_name]

	var path := "res://sprites/" + sheet_name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	else:
		push_warning("Sprite sheet not found, falling back to shapes: " + path)

	_cache[sheet_name] = tex
	return tex


static func clear_cache() -> void:
	_cache.clear()
