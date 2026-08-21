# Audio

Drop sound files in here named **exactly** as the event that fires them, with a
`.ogg` (preferred) or `.wav` extension. Nothing else to do: `scripts/sfx.gd`
resolves each event name to `res://audio/<name>.<ext>` at runtime, and any event
whose file is missing is a silent no-op — so the game runs correctly with this
folder empty, and each sound starts working the moment its file appears.

`.ogg` for anything long (music, the printer motor); `.wav` for short one-shots
if you want the lowest possible latency.

See the table in the project README for what each event is and what it should
sound like.

## About the current files

`music_menu.mp3` / `music_level.mp3` are the real tracks.

The `.wav` effects are **generated placeholders** — simple synthesised chiptune
blips, made so every event has a sound while real recordings are pending. They
are deliberately short and dry. Replace any of them by dropping a file with the
same name in here; the extension can change (`.wav`, `.ogg`, `.mp3`) because the
lookup tries each in turn, so a replacement needs no code change.

If you replace `receipt_print`, keep it seamlessly loopable - it is held open
with start_loop while the receipt feeds and cut the moment it stops.
