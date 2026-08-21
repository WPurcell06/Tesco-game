# Sprite sheets

Drop PNG sheets in here using **exactly** the filenames you loaded in the level
designer. The designer stores a reference (`sheet` + `sprite` index), not the
image, so the two only line up if the names match.

The slicing config lives in `LevelData.sheets()`. The designer's GDScript export
writes that block for you.

Anything without a sprite falls back to the procedural shapes, so the game runs
fine with this folder empty.

Kenney's packs are all CC0 (no attribution required, though he deserves it).
