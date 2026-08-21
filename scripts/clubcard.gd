class_name Clubcard
extends RefCounted

# Lifetime Clubcard points, banked at the end of every completed run and shown
# on the home screen. Stored in user:// exactly like the leaderboard, which in
# a web build means IndexedDB scoped to the serving origin - so this is a
# per-browser total, not a shared one. See README.

const PATH := "user://clubcard.json"


static func total() -> int:
	if not FileAccess.file_exists(PATH):
		return 0
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return 0
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return int(parsed.get("points", 0))


## Banks a run's points and returns the new lifetime total. Negative awards are
## ignored, so a slow run never eats into what you have already earned.
static func add(points: int) -> int:
	var t := total() + maxi(0, points)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"points": t}))
		f.close()
	return t


static func clear() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"points": 0}))
		f.close()
