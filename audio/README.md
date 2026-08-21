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
