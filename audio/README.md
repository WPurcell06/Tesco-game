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

The `.wav` effects are the recorded takes, decoded from the supplied `.m4a`,
trimmed to their content and peak-normalised. Every recording arrived with
roughly 0.6s of room tone in front of the sound, which would have delayed every
trigger, so each file is cut to the window where its RMS is above 6% of its own
peak, plus 30ms of pre-roll and a 40ms fade out.

`receipt_print` additionally has its tail crossfaded into its head, because it
is held open with start_loop while the receipt feeds and a hard seam would tick
once a cycle.

Two events still use generated placeholders because there is no take for them:
`hazard_knock` (a short whoosh, deliberately kept behind the hazard sound it
layers under) and `receipt_tear`. Three more reuse the nearest take: `fall_out`
borrows the tumble, `hazard_ice` borrows Hazard 3, `hazard_spill` borrows
Hazard 2.

Per-event levels are set in `LEVELS` at the top of `scripts/sfx.gd`, not baked
into the files - a jump fires every second or so and needs trimming relative to
a level-complete that fires once. Adjust the mix there.

To replace any of these, drop a file with the same name in here. The extension
may differ (`.ogg`, `.mp3`, `.wav` are tried in that order), so no code changes.
