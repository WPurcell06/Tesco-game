class_name Leaderboard
extends RefCounted

# Scores are stored in user:// which, in a browser, means IndexedDB scoped to
# whatever origin the game is served from. That makes this a per-browser
# leaderboard, NOT a shared one. See README for how to make it shared.

const PATH := "user://leaderboard.json"
const MAX_ENTRIES := 12


static func load_all() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return []
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


static func for_level(level_name: String) -> Array:
	var out: Array = []
	for e in load_all():
		if typeof(e) == TYPE_DICTIONARY and e.get("level", "") == level_name:
			out.append(e)
	return out


static func submit(player_name: String, score: float, level_name: String) -> Array:
	var clean := player_name.strip_edges()
	if clean.is_empty():
		clean = "Anon"
	clean = clean.substr(0, 14)

	var all := load_all()
	all.append({"name": clean, "score": snappedf(score, 0.1), "level": level_name})
	all.sort_custom(func(a, b): return float(a.get("score", 999.0)) < float(b.get("score", 999.0)))

	# keep the best MAX_ENTRIES per level
	var kept: Array = []
	var counts: Dictionary = {}
	for e in all:
		var lv: String = str(e.get("level", ""))
		var n: int = int(counts.get(lv, 0))
		if n < MAX_ENTRIES:
			kept.append(e)
			counts[lv] = n + 1

	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(kept))
		f.close()
	return for_level(level_name)


static func clear() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string("[]")
		f.close()
