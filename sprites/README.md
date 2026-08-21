# Sprite sheets

Drop PNG sheets in here using **exactly** the filenames you loaded in the level
designer. The designer stores a reference (`sheet` + `sprite` index), not the
image, so the two only line up if the names match.

The slicing config lives in `LevelData.sheets()`. The designer's GDScript export
writes that block for you.

Anything without a sprite falls back to the procedural shapes, so the game runs
fine with this folder empty.

Kenney's packs are all CC0 (no attribution required, though he deserves it).

`grocery.png` is the odd one out: hand-painted produce icons (not Kenney),
repacked from an irregular contact sheet into a uniform 7x4 grid of 96x96
cells so it slices the same way as everything else. Named indices for every
icon are in `scripts/grocery_theme.gd` — use those rather than raw numbers.
