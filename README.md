# Trolley Dash — MVP scaffold

A supermarket-aisle platformer. You run along shelf boards, jump up and drop
down between them, dodge hazards, and collect a shopping list **in order**.
Time is the score; coins collected reduce it.

## Getting it running (Godot web editor)

1. Go to <https://editor.godotengine.org>
2. On the project manager screen choose **Import** and pick `trolley-dash.zip`
3. Open the project, press **F5** (or the ▶ button, top right)

Nothing else to configure — no input map, no autoloads, no assets. Every visual
is drawn in code with `draw_rect` / `draw_circle`, so there are zero image files
to manage.

> **Back your work up.** The web editor stores the project in your browser's
> IndexedDB. Clearing site data wipes it. Use **Project → Export Project as ZIP**
> at the end of every session.

## The shopper

`sprites/player.png` is a 32x64 sheet holding two 32x32 frames: standing, and
mid-stride. Drawn at **3x**, so the visible shopper is 48x60 and every source
pixel is exactly three screen pixels. The stride rate follows actual speed, so a
boost visibly reads faster. Collision is a 34x58 box, deliberately narrower than
the sprite: edge grabs and gap jumps feel fairer that way.

To swap the art, keep the same 32x32 frame grid and the body inside x 3..19,
y 5..25, or adjust `BODY_LEFT` / `BODY_RIGHT` / `BODY_BOTTOM` in `player.gd`.

It's called Trolley Dash, so the shopper pushes one: a wireframe trolley drawn
procedurally in `Player._draw_trolley()` (no art asset — same lines/circles
technique the art-less hazards and power-ups use), ahead of them in whichever
direction they're facing, wheels spinning as they move. Geometry constants are
at the top of `player.gd` next to the rest of the shopper's art tuning.

## The top shelf is sealed

Running along the roof skipped every hazard in the aisle, so the top board is no
longer a platform: it is a **solid ceiling**. You bonk your head on it rather
than standing on it, which also stops a big jump carrying you off-screen. The
highest board that still holds items is unchanged.

## Order modes

Chosen on the home screen and applied to whatever aisle you pick.

| Mode | Behaviour |
|---|---|
| In order | follow the list top to bottom; a chevron floats above the shopper pointing at the next item |
| Any order | grab them however you like |

This overrides each level's own `order` field. The shopping list shows each
item's sprite next to its name; items without art yet get a coloured chip keyed
off their `type`, so the list still reads at a glance.

## Controls

| Action | Key |
|---|---|
| Move | Left / Right arrow |
| Jump | Up arrow or Space |
| Drop through a shelf | Down, or Page Down |
| Restart level | R |

## Files

| File | What it does |
|---|---|
| `scripts/level_data.gd` | **Start here.** Shelf geometry + every level's items, hazards and list order. |
| `scripts/game.gd` | Builds the world, HUD and scoring; owns the run state machine. |
| `scripts/player.gd` | Movement: accel, coyote time, jump buffering, variable jump height, drop-through, sprite animation. |
| `scripts/shelf_item.gd` | A collectable product. |
| `scripts/hazard.gd` | An obstacle sitting on a board. Jump it. |
| `level-editor.html` | Standalone visual level editor. Open it in any browser. |
| `scripts/leaderboard.gd` | Reads/writes `user://leaderboard.json`. |

## Scoring

```
final score = elapsed time − (coins × SECONDS_PER_COIN)
```

Lower is better. `SECONDS_PER_COIN = 1.5` at the top of `game.gd` sets how much
a coin is worth in shaved seconds.

**Hazards add nothing to the score.** Hitting one bogs you down — top speed
drops to 35% for 2.8 seconds — so the cost lands on the clock naturally. A hit
costs roughly 1.8–2.5 real seconds depending on how far you still had to travel,
which means hazards near the end of a route hurt less than hazards near the
start. That's a feature, but it's worth knowing when you place them.

Hazard severity is tuned in `player.gd`, not `game.gd`:

- `SLOW_TIME = 2.8` — how long the sludge lasts
- `SLOW_SPEED_MULT = 0.35` — top speed while slowed
- `SLOW_ACCEL_MULT = 0.45` — how sluggishly you get back up to it
- `SLOW_JUMP_MULT = 0.94` — **do not drop below ~0.92**, or the player can no
  longer clear a 180px shelf gap and is stuck until it wears off
- `HIT_GRACE = 0.5` — stops one hazard registering twice

Repeat hits refresh the timer rather than stacking, so you cannot be slowed
into a permanent crawl.

Coins are set per item in `level_data.gd`. Put the high-coin items on the top
shelves behind hazards and the risk/reward tension appears on its own. Tuning
these three numbers together is the main balancing lever you have.

## Level editor

Open `level-editor.html` in any browser — one self-contained file, no server
or install needed.

Everything sits on a **60px tile grid**, so it maps straight onto tile assets
later. A shelf row is 3 tiles tall.

| | |
|---|---|
| Place | pick a tool, click a tile |
| Move | drag it |
| Edit | click it with Select, use the panel on the right |
| Delete | right-click it, or select and press Delete |
| Gaps | Gap tool, drag to paint a run, click again to fill back in |
| Tools | keys 1–5 |

Placing an item drops you straight into its name field. Items, hazards and
power-ups all have a **type** you can change — types are cosmetic right now and
exist as the hook for tile art.

Unticking "on the shopping list" leaves an item on the shelf as an optional
bonus rather than a required stop.

Hit **Copy** with **GDScript** selected and paste over the `return [ ... ]`
block in `scripts/level_data.gd`. **JSON** is the format to paste back into the
designer, or to send on.

Work autosaves to browser storage, but export regularly — that autosave is
per-browser and vanishes if site data is cleared.

## The five aisles

| # | Aisle | Collectibles | Hazard | What it does |
|---|---|---|---|---|
| 1 | Produce Pursuit | fruit & veg (real art, see below) | angry produce | mix of 1.0s stun (flat sprites) and slowdown (square sprites) |
| 2 | Snack Attack | chocolate & candy | fizzy drink spill | slowdown, still steerable |
| 3 | Frozen Frenzy | poultry, ice cream, ice pops | ice patch | 3.0s slip: faster but barely steerable |
| 4 | Health & Beauty | brushes, lipstick, makeup | spilled soap | 1.8s trapped in a bubble, pinned |
| 5 | All-Store Pick | all of the above | all four | the lot |

All five scatter their item positions on every run. Level 5 butts the four
aisles end to end into one 161-tile run with section banners, and draws its
shopping list as 10 items picked at random from the 32 on the shelves — so no
two runs ask for the same trolley. The upper shelves are cut away at each
junction, so crossing between sections means dropping to floor level.

Frozen Frenzy has frosted freezer doors drawn over the aisle. They are purely
visual and have no collision: they make the shelves behind them harder to read,
which is the point.

## Obstacles

- **Hazards** — a hazard's `type` drives its behaviour, not just its look:
  `peel` stuns, `spill` slows, `ice` makes you slide, `soap` bubbles you, and
  `crate` / `trolley` / `pallet` are generic slowdowns. Flat hazards (peel,
  spill, ice) read as floor surfaces; tall ones are clearly objects to hop.
- **Gaps** — a missing section of board. Fall through one on an upper shelf and
  you land on the shelf below, which costs you the climb back. Fall through one
  in the aisle floor and you are returned to your last safe footing with the
  same slowdown a hazard would cost.

In tiles: a jump climbs **4 tiles** and covers **7 tiles** of ground, so a hole
of **5 tiles is the practical ceiling** and 5 demands a clean run-up. A slowed
player only covers about 2 tiles per jump, so a wide hole will strand them until
the slowdown wears off — recoverable, not a soft-lock, but worth knowing.

## Art

Two Kenney packs are wired in (both CC0):

| Where | Asset |
|---|---|
| `sprites/industrial.png` | Pixel Platformer Industrial Expansion, 18x18, 16 columns |
| `ui/*.png` | UI Pack buttons and panel, used for the home screen and end panel |
| `ui/font/KenneyFutureNarrow.ttf` | every label in the game |
| `ui/click.ogg` | button press |

A third, non-Kenney sheet covers Produce Pursuit's own art:

| Where | Asset |
|---|---|
| `sprites/grocery.png` | hand-painted produce icons, repacked into a uniform 7-col x 4-row, 96x96-per-cell grid |

The source art was an irregular contact sheet (rows of 4-7 icons, not a clean
grid), so each icon was cropped to its own bounding box and recomposited onto
this uniform grid — that's what makes it lift-and-loop through
`Sprites.region_of` like every other sheet. Named indices for every icon live
in `scripts/grocery_theme.gd` (`GroceryTheme.APPLE_RED`, `.CARROT_ANGRY`,
`.BROCCOLI_KING`, and so on) — reference those from `level_data.gd` rather than
raw index numbers. Three families: plain produce (shopping-list items), angry
produce (hazards), and sparkly produce plus a can of beans (power-ups).

**The world tile is 54px, which is exactly 3x the 18px art.** That matters: a
non-integer scale makes some source pixels 3 screen pixels wide and others 4,
which is very visible on pixel art. `default_texture_filter` is set to Nearest
for the same reason. If you swap in art at a different size, keep the tile an
integer multiple of it.

Shelf tiles are chosen in `scripts/shelf_theme.gd` — beams, uprights, feet and
the broken-end stripe are all just index numbers, so you can restyle every aisle
by editing that one file. The beam hangs below the walking surface the way a
real shelf does, leaving a 2-tile opening for the player.

## Home screen

`menu.tscn` is now the main scene: title, the five aisles as Kenney buttons, and
each aisle's best time beside it. Keys 1-5 jump straight into an aisle. In game,
the HUD shows `AISLE n/5`, Escape returns home, and the end panel has Home /
Retry / Next aisle.

Themed around Tesco's own blue/red rather than a generic dark panel: a blue
backdrop, a red header band behind the title, and aisle buttons alternating
blue/red (grey stays on aisle 4, kept for contrast reasons — see the comment
in `menu.gd`). The whole menu is built under a `CanvasLayer` — Controls need
a `Control`/`CanvasLayer` ancestor to anchor against the real viewport rect;
parented straight onto the scene's `Node2D` root, `PRESET_FULL_RECT` has
nothing to size against and the layout collapses to its content's natural
size instead of filling and centering. `game.gd`'s HUD already did this
correctly — `menu.gd` now matches it.

## Sprites

The game draws procedural shapes by default and needs no art to run. To use
real art:

1. Load a PNG sheet in the designer's **Sprites** tab and set tile width,
   height, margin and spacing until the grid preview looks right.
2. Select something on the level grid, then click a sprite to assign it.
3. Copy the **GDScript** export — it writes both the `sheets()` slicing config
   and the levels.
4. Drop the same PNG into `sprites/` using the identical filename.

Sprites are stored as a reference (`"sheet": "kenney_items.png", "sprite": 42`),
so nothing binary ever enters the level data. A missing sheet logs a warning and
falls back to shapes rather than crashing.

## Collection order

Set per level in the editor's **Order** dropdown, then overridden at runtime by the home screen's In order / Any order choice:

| mode | behaviour |
|---|---|
| `fixed` | strictly the order shown in the list |
| `shuffle` | same list, reshuffled at the start of every run |
| `any` | grab them in whatever order you like |

Two more per-level switches:

- **scatter** (`randomise`) — item positions are rerolled every run onto any
  free tile with board under it. Hazards, power-ups, holes and the spawn tile
  are excluded, so a scattered level is always completable.
- **pick** (`pick: N`) — ignore the list and draw N items at random from
  everything on the shelves. This is what makes level 5 different every run.

`shuffle` is the one that adds run-to-run variance while keeping routing
meaningful; `any` turns the level into a pure travelling-salesman problem.

## Power-ups

Optional pickups that are never on the shopping list, so taking one always costs
a detour. Three kinds:

| kind | effect |
|---|---|
| `boost` | 40% top speed for 4s |
| `clean` | clears a hazard slowdown immediately |
| `coins` | +3 coins |

A slowdown always beats a boost, so a hazard still stings while boosted. Effects
live in `Game._on_powerup_taken` and are a few lines each to change.

## Known limits of this MVP

- **The leaderboard is per-browser, not shared.** `user://` in a web build is
  IndexedDB scoped to the serving origin, so each player only sees their own
  scores. For a real shared board you need a small HTTP endpoint and an
  `HTTPRequest` node in `_on_save_pressed`; the JSON shape is already right.
- Hazards slow you rather than killing you. Swapping to lives/restart is a
  change in `_on_hazard_touched` only.
- No audio, no menus, no per-level unlock gating.
- `level-editor.html` (ships separately, not in this checkout) doesn't know
  about `grocery.png` yet — its Sprites tab and embedded level set were built
  against `industrial.png` only. If you open Produce Pursuit there, re-sync
  its sheet config and level JSON with `scripts/level_data.gd` and
  `scripts/grocery_theme.gd` first, or it'll overwrite the new art references.
- One-way platform drop-through briefly disables the player's collision mask,
  so you can drop through the aisle floor's neighbours but not the floor itself.

## Serving it locally

Export via **Project → Export → Web**, then serve the folder over HTTP (not
`file://`). It needs cross-origin isolation headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Godot's own `--headless` export server sets these; most static hosts need them
configured explicitly or the game will fail to start.
