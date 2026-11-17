# Mind Palace (folder `mmm`) — design

**Vaults, then the map** (since 2026-11-16): memory AND navigation. Every room of a castle joined by
corridors has a **vault** (a safe, the same in every room) with an OBJECT inside. Walking the castle you
open each vault by walking into it: the object shows, big ("FOUND / CROWN / Remember this room"), and
the vault shuts again. When every vault has been opened the view pulls back to the whole castle as a
**plain map** -- every floor the same gray -- and you are asked for each object in turn: **tap the room
it was in**. That takes a map of the castle in your head, built while walking it in the zoomed view,
where you never see more than a room. A right room takes its color back and shows its object; a wrong
one opens for a moment and costs a point, and you try again. Bombs and monsters end the round while you
walk.

History: until 2026-11-15 you took one coin per room and the map asked each room's FLOOR COLOR (the
same navigation test, about a less interesting fact, and "dull"). On 2026-11-15/16 the player
CARRIED each object and stored it themselves, first with requests interleaved and fetched by walking
back ("now it's just a memory game": the map in your head was no longer tested), then with this map at
the end -- carrying dropped: "we just don't have a good story for carrying yet". The map is plain gray on purpose: with the colors on, "the anchor
is in the red room" would answer it without knowing where that room is.

The name in the chooser and in game is "Mind Palace"; the folder and `file_names_prefix` stay `mmm`,
because every scores/settings file on disk is named after that prefix.

## Bomb art

Bombs use the `Bomb` animation in the shared `scenes/head_anim.tscn`, which mmm, lightsout, storm,
wolves and gorilla all draw from — a change here shows up in all of them.

The art is `art/bomb_crackle.png`, 12 frames of 128x128 generated from `bomb1-vig-4x.png`. It is
deliberately **grayscale**, because each game tints it (`modulate = Color(0.5, 0, 0)` for target
bombs), so the fuse can only be told apart from the ball by brightness and shape, never by hue.

The original art read as "a worm coming out of a ball": the cord was a fat, evenly wide tube that
was actually *brighter* (peak 247) than the flame blob on its end (143), and the only part the
three frames animated was a large, dim, round puff detached to the upper right. The replacement
drops the puff, redraws the cord as a tapered fuse that is dimmer than the flame, and puts a
necked, flickering teardrop flame with crackle sparks at the cord's real tip.

Everything is contoured. The ball carries a near-black outline all the way round (10..40
luminance on its edge) so it reads on light and dark backgrounds alike, and the fuse, the flame
and the sparks are outlined to match — about 2 px, against the ball's 4-6 px, since they are much
thinner shapes. The fuse stops at the dome rather than being drawn into it, so its two side
outlines meet the ball's own contour instead of cutting a channel through the bright dome. Sparks
sitting right at the top edge of the frame are the one place the ring cannot close (about three
pixels per frame).

The frame is fixed at 128x128 and every game positions the sprite by that footprint, so the only
way to make the fuse and flame read at play size was to give them more of the frame: the ball is
scaled to 84% and sat on the bottom, which takes the headroom above it from 38% of the ball's
height to 66%. The sprite's footprint is unchanged, so nothing moves in any game.

## Files

```
mmm/scripts/
├── globals.gd       MmmG autoload: starting_level, save/load settings
├── level_config.gd  MmmLevelConfig.LEVELS — 12 levels, 3 rounds each
├── main.gd          orchestrator: menu, HUD, instructions, score rows
├── level.gd         the castle: rooms, corridors, vaults, bricks, hazards, the map
├── player.gd        you; continuous movement, `mark_arrived()` ends the exploring phase
├── agent.gd         the things that move in the rooms and the bombs
├── pedestal.gd      a room's vault, drawn as a SAFE DOOR (Crack the Safe's): shut, or OPEN (door aside, the object inside); a BEACON until opened
├── object_badge.gd  how an object looks everywhere: a disc in its own color, white ring, white symbol
├── fetch_hud.gd     the overlay: the WHERE IS card, the big announcements, the results
├── pipe.gd          one floor tile: holds `has_brick` and the room color (`has_coin` is no longer used)
```

## A round

1. The level's briefing goes up at once, held, and `create_board()` builds the castle behind it (see
   "The briefing and the build"): `num_rooms` rooms (`create_rooms`), joined (`add_corridors`), then
   `add_player`, `add_pedestals` (one per room, where the coin used to be), `add_bricks` (never next
   to a pedestal, `_near_pedestal`), `add_bomb_agents` (never within `BOMB_CLEAR` (2) tiles of one: a
   bomb beside a pedestal made it unusable), `add_moving_agents`. The round starts when
   the card's Start is pressed (`_begin_round()`).
2. You walk with swipes or arrow keys -- `move_dir()` sets a direction and you keep going until you
   turn or hit something, like Gorilla. Entering a tile calls `mark_visited_room()`.
3. **The objects** (`OBJECTS`: twelve, each a symbol, a name and a color -- crown, anchor, ...): one in
   every vault, none twice (`add_pedestals`). How they are shown: see "In your face".
4. **A vault is SOLID and opened by walking INTO it** (`can_go_to` refuses it; `move_player_on_tick`
   calls `_use_pedestal` when the next step, or the next step of a drawn path, is a vault, and stops the
   player there). Stepping ONTO one would let a walk across a room brush it by accident.
5. `_use_pedestal` on a vault not opened yet (`seen`): it opens for `OPEN_SHOW_MS`, its object is
   announced, +1, `delivery` (`found`). **Walked into again** (`_peek`): it opens for a moment and the
   object's name rises over it -- no points, no cost (`peeked`); the player may refresh their memory
   while roaming, as in a real house.
6. When `_round_complete()` (every vault opened) walking is over (`player.arrived`; collisions off) and
   `_finish_exploring()` runs: the last safe gets NO FOUND card (its card and then the recap left a dead
   pause between them, "a short freeze"), and `RECAP_AFTER_S` (0.35 s) after it opens an **"ALL n FOUND"**
   card pops up with every object's badge in a row, one by one (`fetch_hud.gd` `show_recap`). Behind it,
   a CUT, not a glide: a short dip to dark (`fetch_hud.gd` `curtain`, `CURTAIN_CLOSE_S` 0.3 s), the
   player and the monsters gone, every floor gray and the view set on the whole castle (framed below the
   banner) behind it, held fully dark a few frames, and the gray map fades in while the card is still up
   (`CURTAIN_OPEN_S` 0.9 s). Then `_start_map()` (`map_shown`). Until 2026-11-16 the camera GLIDED out from
   the player's room over floors still furnished: it showed how the walked rooms lie together, the very
   map the round asks the player to have built in their head (the user). A dark screen behind the card
   until the questions was "bleak"; hence the fade-in under the card. A sequence still running when the
   round is reset stops (`_round_token`).
   **There is no session clock** (`main.gd`: `game.uses_session_clock = false`; the HUD shows none, the
   level card no "Time left", the round's win no longer adds time). It only cut sessions short at a
   random moment, mid-walk or mid-question; the time that matters is each question's (below).
7. **The questions** (`_update_questions`): the vaults' objects in a random order, one at a time,
   `QUESTION_GAP_MS` apart (`asked`). A tap on any floor tile of a room (pipe.gd `pipe_pressed` ->
   `_on_floor_tapped`) answers for that room:
   - the right room: +5, plus up to +5 for speed (one less every 2 s), `right`; the object pops up
     LARGE, about 2x2 cells, centered on its safe (`pedestal.gd` `big`) -- also where it shows only for a
     moment (keep_found off); the room takes its floor back where the level allows (`room_answered`);
   - a wrong room: -1, `gaveup`, its pedestal opens on what is really there for `REVEAL_MS` (level 1
     only, `reveal_wrong`), and the question stays open. Sets `_round_had_wrong_answer`. A room already
     found ignores taps while something marks it.
   - **the time bar runs out**: every question has its own time, a bar draining along the banner's foot
     (`fetch_hud.gd` `time_frac`: green, amber, then red and throbbing in its last quarter). It ADAPTS to
     the player over the session, a staircase (`ANSWER_*` in level.gd): from 12 s, an answer in under
     60% of the time tightens it by 10%, a run-out loosens it by 25%, within 4..20 s -- the pressure kept
     near the edge of what this player can do, the way adaptive speed training works, not a clock's
     random cut (the user, 2026-11-16: "add a per question time bar that adapts"). Counted only while the
     game runs (paused time is not), none in the tutorial. A run-out is a miss: -1, a mistake
     (`answer_timeouts` counted), `gaveup`, and the right room flashes amber with its object shown large
     for a moment ("Time's up: it was here"); then the next question. The time an answer took (for the
     score's speed bonus and the recorded `rt` distribution) is the same pause-free count.
   After the last one, **everything is shown** (`_reveal_all`, "when all are done, show all"): room by
   room every floor comes back and every safe opens on its object, LARGE (about 2x2 cells, centered on
   the safe; a safe is never next to a wall, so it stays in its room), with a pop (`REVEAL_STEP_S`), then
   `level_is_done(true)` (not in the tutorial, nor if play was left meanwhile; `map_done`).

**Game over clears the overlays** (`on_time_over` / `on_lives_depleted` -> `_end_overlays`): the map's
question, the announcements and the room name go, and any recap, cut or reveal still running stops
(`_round_token`); the curtain lifts. The "WHERE IS" banner stayed up under the game-over card.

**No green at the edges**: the great hall's rect runs `SKY_MARGIN_TILES` (40) past the board on every
side, and the window's clear color is the hall's near-black (`main.gd`). Framed below the question's
banner, the pulled-out map reached past the hall, and the old lawn-green clear color showed as a strip
along the top and sides. On the higher levels nothing stays on show
   while answering, so this is the first time the player sees the whole palace at once.

The time each map answer took is kept in `times_to_answer` (the last 20), reported as `rt` by
`main.gd::get_game_score()`.

Touching a moving agent or a bomb kills the round outright: `check_agent_collisions()` →
`player.mark_hit()` → `remove_player(false)` → `level_is_done(false)`.

The speed bonus (`min(5, 60 - seconds)` score and time) is paid only for a round that was WON. It
used to be applied before the win/lose branch, so a round lost after ten seconds paid the same as
one won in ten seconds.

## The vault is a safe door (2026-11-16)

`pedestal.gd`: a SAFE DOOR seen straight on, the SAME in every room ("it should be a recognized item"),
drawn the way Crack the Safe draws its safe (copied and scaled to a tile; games do not share scripts):
brushed steel lit from the top left, beveled, a recessed panel, four hex bolts, a big chrome dial with a
black face, silver ticks, a gold pointer and a knurled knob, a three-spoke handle, and a small LAMP --
red until the safe is first opened, green after. 1.12 tiles a side. Open: the door swung aside on its
hinges (a steel slab seen nearly edge-on) and the object's badge in the dark compartment, drawn above
everything round it (`z_index` 30) since the player stands beside it.

**It stands out on every floor** (the user's rule): a soft light halo behind it, a thick BLACK outline
and a bright GOLD frame inside that, and a deep shadow -- the black carries it on light floors, the gold
and the halo on dark ones. The beacon (rings round a safe not opened yet) is a child that redraws every
frame; the door is drawn only when its state changes.

Tried and dropped the same day: a brass dome on a round plinth (a serving dish); a flat strongbox in
three-quarter view ("much less contrasting and visible ... much less nice"); a real 3-D strongbox
rendered like the hall's columns ("this 3-D almost front view doesn't match any other item"); furniture
fitting each room (offered, turned down for one recognizable thing).

## In your face (2026-11-15)

The first version said everything in one small gold line. The user: "everything should be much much
more in-your-face". Now (`fetch_hud.gd`, `object_badge.gd`, `pedestal.gd`):

- **Every object is a BADGE** -- a disc in the object's own color with a white ring and its symbol --
  the same in an open vault and in the announcements and the card.
- **The map's question is a BANNER** across the top (`banner_rect`, popping in, its border pulsing),
  and the map is framed BELOW it (`_frame_for(..., top)`). It was a big card in the middle that then
  flew into a card at the top, and in both places it covered rooms of the map being asked about ("the
  question sometimes hides a vault").
- **Announcements**: a vault's object ("FOUND / CROWN / In the kitchen", gold) pops up large in the
  upper third -- or the lower part when the opened safe is in the screen's upper half, so it never covers
  the safe it is about (`announce_found(..., avoid_y)`; in the upper third it usually did) -- the screen dimmed a little, holds 1.25 s and shrinks away. Queued, one at a time. **Laid out once and
  scaled through a transform**: fitting the text to the moving rect asked for a new font size every
  frame, each rasterized afresh -- half a second a frame.
- **Vaults not opened yet are BEACONS** (rings spreading out, a warm glow), so the ones still to find
  stand out from across a room.
- **Results over the vault**, big, rising and fading: "✓ +8", "✗ That's the teacup" (shrunk to fit the
  screen when long).
- Nothing is drawn on the player. (While objects were carried, one floated over the head at the
  player's size, then was held small in two hands -- "even worse".) `fetch_hud.gd` still has the
  CARRYING card (`set_carry`), unused.

## The palace's look (2026-11-12)

It had the oldest look in the app -- a tinted PHOTO of marble tiles for the floors, the same photo
for the corridors, and the road games' lawn outside -- and was redrawn over several rounds with the user:
- **Floors: each room a KIND** (since 2026-11-16, `room_kinds.gd`): living room (oak parquet), kitchen
  (cream and slate checker tiles, four a cell), bathroom (aqua mosaic, sixteen a cell), library and study
  (walnut / cherry planks, three a cell), bedroom and nursery (carpet with a diamond in each carpet tile),
  garden (a flagstone a cell, grass between), ballroom and dining room (marble checker), cellar (rough
  stone), sunroom (terracotta). Shuffled per castle, all different up to twelve rooms (`_room_kinds`,
  `_kind_of`; `OneCell.room_kind`, set in `add_pipe`). Drawn by `castle_floor.gdshader` with `use_cols`
  on and the kind's `style`, `col_a`, `col_b` (pipe.gd `_show_kind`); every style keeps the CELLS
  readable (its pattern lines up with them, or a faint joint marks them). The room's NAME shows as the
  player walks in (`fetch_hud.gd` `show_room`, where the cards are -- there are none while walking), and
  the FOUND card says where ("In the kitchen"). **On the map every room is plain gray stone** (`style`
  0, tint) until found, then it shows its kind's floor: knowing "the kitchen" must still be joined to
  where the kitchen is.
  Before: each room's floor was its own COLOR (the old quiz asked for it), POLISHED MARBLE `style` 1
  tinted by the node's modulate, the cells in a two-tone checker -- still how `style` 1 draws with
  `use_cols` off.
- **Corridors**: the same marble in warm gray, `pipe.gd` `CORRIDOR_STONE` (0.44/0.42/0.40).
- **Walls** (`level._add_castle_walls` / `_draw_castle_walls`): warm IVORY stone along every edge where
  floor meets the hall, with a GOLD outer edge (bright facing the light, deep away from it), a dark line
  against the floor, and a shadow falling outward on its own node one z lower. Each end of a wall is an
  OUTSIDE corner (strip and line run on by the wall's width), STRAIGHT (stop), or INSIDE (the line stops
  a wall's width short) -- the strips' lines used to run on and cross at the corners. They were cold gray
  first. The empty cells' old wall sprites are hidden (`empty_space.gd`).
- **Doorways are plain** -- the walls' own joints -- and their corners CONTINUE: `_draw_castle_walls`
  draws the stone of every wall first and every edge line after. Drawn wall by wall, the next strip's
  stone covered the end of the last one's lines, so each doorway corner lost a stretch of its line ("the
  room openings are not ok"). Two decorations of the openings were tried and removed first: gold-edged
  posts with a gold-trimmed threshold ("way too vulgar"), then small stone blocks with a thin threshold
  ("don't belong there", "a flat ugly line").
- **Outside: a dark GREAT HALL** (`palace_sky.gdshader` `style` 3, `_fit_ground_to_board`): the rooms
  are lit chambers in it. Near-black marble slabs three tiles across, faintly veined, fine gold inlay
  lines between them and a gold ring on one slab in four (at two tiles across, and brighter, it read as
  graph paper). The veins are thin and faint. Tried and turned down: a starry sky ("boring"), a moonlit
  moat (outdoor nature round an indoor palace: "doesn't match the rooms"), a sea of clouds; all still in
  the shader (`style` 0-2).
- **The hall is furnished** (placed by `level._place_hall_decor`, drawn by `hall_decor.gd`
  `MmmHallDecor`), the third try:
  - COLONNADES (3-5 in a row across), FOUNTAINS (3x3) and TOPIARY are real 3-D (`hall_art.gd`
    `MmmHallArt`): a fluted marble column with an Attic base, a gold necking band, a rounded echinus, a ROUND
    abacus no wider than the flare and a small gold ball on top. (Ionic volutes stuck out like ears; a
    square abacus showed its top and front in one tone, "a flat rectangle that doesn't fit"; a wide round
    one made it a mushroom.) The key light is steep, from above and the left, so faces turned up are
    clearly brighter than faces turned to the viewer; a two-tier marble fountain, water in both bowls, a translucent sheet falling from the
    upper lip and a jet from a gold spout; a clipped leaf ball on a stem in a stone planter with a gold
    band. Modelled in code, lit warm from the top left with a cool fill, seen from a high THREE-QUARTER
    angle (`PITCH_DEG` 58: straight from above a column is a circle and a tree a disc), rendered ONCE at
    first need into textures (`PX_PER_CELL` 96) centered on each piece's ground point. Their floor
    shadows are 2-D (`_shadow`: one soft oval drawn out away from the light; stacked copies showed as
    stripes) because the compatibility renderer cannot cast onto a see-through floor. Fountains carry
    slow rings on the basin's water, drawn as the camera sees them.
  - REFLECTING POOLS (4x2) and RUGS (3x2 / 4x3, either way round; runners one cell wide had no room for
    the border and medallion: "do not look good") lie flat and are shaders in their own rect
    space: `hall_pool.gdshader` (a veined, beveled marble rim; dark water moving in two sets of small
    waves, shaded under the rim on the light's side, the hall's warm light lying along it, glints; water
    lilies with notches and veins, a few in flower) and `hall_carpet.gdshader` (guard stripes, a navy
    border of gold rosettes spaced to fit each side whole with a larger one in each corner, a red field with a lattice of small flowers, a round medallion with pendants,
    corner quarters, wool fibers and weave, fringe at the short ends).
  - LAID OUT, not scattered (`_place_hall_decor`): scattered at random, small and many, they read as
    clutter with the whole castle in view. Within the CASTLE's bounds plus `DECOR_REACH` (the board is
    much bigger than the castle; its most open spots were far off screen). PLAZAS first: a fountain at
    each of the most open spots (`PLAZA_OPEN`, open spaces between the rooms ranked before the margin),
    one per 900 cells, at least 9 cells from the next, with a topiary on EITHER side or neither (one
    alone was lopsided); COLONNADES along the longest room walls, `COLONNADE_OUT` cells out, centered,
    columns two cells apart (`spacing`); then one pool and two rugs in open space. Every piece: a clear
    cell all round, `rise` rows clear above a standing piece, `DECOR_GAP` from the others.
  - Two earlier sets were turned down: busts, armor, shields and candelabra ("strange"), then the same
    kinds as now drawn from flat code shapes ("very very sloppy": no material, no light, no texture).
- **Patterns are laid from the BOARD, not from MODEL_MATRIX.** In this game that matrix moves with the
  camera, so as it glided between rooms or followed the player down a corridor every tile kept changing
  which square of the checker it was, and the floor flashed between its two tones (measured: all tiles at
  once, ratio 0.86). Each tile now has its own material copy and is told its cell (`pipe.gd` `set_rot` ->
  `cell`); the hall is told its rect's place (`origin`). Hairlines are also sized in screen pixels
  (`fwidth`), and veins fade out where they would be thinner than a pixel.
- **Bricks are castle props** (`castle_prop.gd`, `MmmCastleProp`): `has_brick % 3` picks a stone
  PILLAR (a flat column top on a square plinth -- shaded as a ball it read as one), a BARREL or a
  wooden CRATE. The logic is unchanged (still `has_brick`, still blocks the tile).
- The GrassField is still fitted under the hall (the probes check it), hidden.

## Look and sound (the 2026-10-24 pass)

- **Walls shade each room's edges** (`level._add_wall_shade()`, `WALL_SHADE` 0.30 of a tile, faint):
  a band along every edge where a room meets anything but more of itself or a corridor (doorways stay
  open). Only the edge darkens -- the floor's COLOR is what the player remembers, and every room's
  middle is untouched. The floor sprites are at z -1 (`pipe.gd` `_ready`) so the band lies over the
  floor and under the pedestals and bricks. It loops over the board array, not `game.board_size`.
- **Sounds** (`devtools/make_mmm_sounds.py`, `make_ambient_sounds.py`; names in code kept): `motor` =
  the castle's MUSIC, `mmm_ambient.ogg` -- a harp ostinato in D dorian, a recorder-like tune that comes
  and goes, a soft reed drone, a frame drum. It was a car engine registered and never played, then a
  band of noise ("just white noise"), then a soundscape of wind, torches, drips and a far harp ("very
  strange ... just a mess"): continuous and tonal now, no noise bed. It starts with the first round and plays ON between
  rounds (stopping it at every round end was the "gaps"); `main.gd` `show_main_menu` stops it. The
  HAZARDS ARE HEARD: `fuse` (a bomb near: a clock ticking and a fuse spitting sparks) and `enemy` (a
  monster near: claws clicking on stone, heavy steps, a raspy breath in and out -- nothing voiced: a
  growl through vowel formants was heard as "a cow mooing") are loops whose loudness
  follows the nearest bomb and the nearest moving monster, silent beyond `HAZARD_HEAR_TILES` (4) and
  -4 dB when touching (`_hazard_sounds`, only while the round is really played). `feet` =
  steps on stone (were on grass); `right` = the right room on the map;
  `gaveup` = a wrong room; `swoosh` = the map opening out; `delivery` = a vault opened; `explosion` (a BOMB set off) =
  the big explosion Lights Out uses (`make_action_sounds.boom`, a little shorter) when a hazard catches
  you (it was a car crash, then a 45-95 Hz boom a phone plays as nothing); `caught` (`mmm_caught`) = a
  MONSTER catching you, a harsh unvoiced snarl and a heavy chomp (`check_agent_collisions` picks by
  `agent_type`);
  `start` = a heavy door closing. The first hazard loops were a hissing fuse and a steady buzz.

## Difficulty

`_apply_level()`: `num_rooms = 2 + level` (capped by `MAX_POSSIBLE_ROOMS`, the palette and the 12
`OBJECTS`), so level 1 is three rooms and three vaults: more vaults, and a bigger castle to hold in
your head. Board size grows with the level and agents speed up.

**The map's help is withdrawn level by level** (`MmmLevelConfig` flags, `flag(level, key)`;
2026-11-16). Every tapped room flashes (green right, red wrong, `_flash_room`) on every level; beyond
that:

| from level | withdrawn | why |
|---|---|---|
| 2 | `reveal_wrong`: a wrong room showing what is really in it ("✗ That's the teacup"); now "✗ Not there" | it told the player where ANOTHER object was, answering a later question for them |
| 3 | `color_found`: a found room taking back its floor | colored rooms narrowed what was left to choose from |
| 4 | `keep_found`: a found room's object staying on show (it shows for `REVEAL_MS`, then covers) | the same, for the objects |

Where neither the floor nor the object marks a found room any more, tapping it again is simply a wrong
room. The tutorial gets level 1's help.

## Passing a level

A level is `rounds_per_level` rounds (`rounds` in `MmmLevelConfig`, read by `_apply_level()`), and
it is **passed on the share of them that were FULLY CORRECT** — the round survived AND every room
named right first try:

```
passed = 100 * _rounds_fully_correct / _rounds_played >= MmmLevelConfig.pass_pct_for(level)
```

One wrong room on the map sets `_round_had_wrong_answer` and spoils the round for the gate. The round
can still be finished -- the question stays open and the player tries again -- it just no longer counts
toward the level.

**The gate has its own counters on purpose.** Every other gated game reads
`game.session_pct_correct()`, but here `game.corrects` / `game.mistakes` already count MAP ANSWERS
and the HUD shows them (`hud.show_corrects_mistakes()`). Putting round verdicts in the same pair
would mix two different units in one number and make the counter on screen wrong.

Below the bar the SAME level is played again; at or above it, the next one. `level_is_done()`
records each round's verdict with `game.add_correct_or_mistake()` and steps `round_in_level`; when
that reaches `rounds_per_level`, `_finish_level()` judges the level and `_advance_if_needed()` —
called from `new_game()` — acts on the verdict.

Before this, **a level could not be failed, only postponed.** `round_in_level` only moved inside
`_advance_if_needed()` when `game.need_to_increase_level` had been set, and that happened on a WIN
— so a lost round did not count toward the level at all. You could lose forever and simply keep
being handed the same round.

**The percentages have to land on a rung.** A level is a fixed number of rounds, so out of 3 the
only scores that exist are 0, 33, 66 and 100. `pass_pct` is 60, which is exactly 2 of 3. Recheck it
whenever `rounds` changes.

The last level is judged the same way but never promotes.

## "complete!" only when it was

The level card is shown with the gate result as its `passed` argument, so it reads "Level N
complete!" with a check badge or **"Level N not passed"** with none. Under it, `Rounds fully right: 2 of 3`,
`Accuracy: 66%`, and what happens next:

- passed -> `Level passed — on to level N.`
- failed -> `You need at least 60% of the rounds fully right to pass to the next level.`

Mid-level rounds keep the small "Well done!" / "Oh no!" panel, now numbered from the round that was
just played rather than from the one about to start.

`MainGlobals.global_level_is_done()` takes the gate result, so the fanfare does not play over a
level that was not passed.

**Each card is followed through its own `closed` signal** (`level_is_done`, `_finish_level`), not
the app-wide `sig_game_popup_closed` / `sig_level_done_popup_closed`, which fire for ANY card. With
a briefing card at the start of every round, those would have ended the round the moment Start was
pressed -- the bug Storm had first.

## The briefing and the build

The same mechanism as Storm's, copied into `level.gd` (games do not share scripts).

- **The card goes up at once, held.** `new_game()` shows the level's briefing and holds it
  (`game_popup.hold()`): it reads only "Building world", with no Start button, and nothing closes it.
  It is laid out at its final size, the real text already in it and hidden. When the board is ready
  and the card has been up at least `BRIEF_HOLD_MS` (1 s), `_release_brief()` puts in the real text
  (`_brief_text()`: "Rooms" -- the count the board actually got -- and "Rounds"; what to do is the
  instructions screen's, and was repeated here until 2026-11-12) and shows Start. The round -- its clock, `level_is_ready`, the start sound -- begins when
  the card closes (`_begin_round()`). The tutorial has no card and starts as soon as its board is built.
- **The background stays opaque while held**, unlike Storm's, where the build is watched (kept from
  the color quiz, when the whole castle behind a dim card showed every answer; harmless now).
- It replaced a yellow "Building board" label (`BuildingLabel`, now removed with its style) after
  which the round started at once.
- **The board is built in slices.** `_breathe()` in every loop of the build hands the frame back after
  `BUILD_SLICE_US` (14 ms), so the card stays drawn. Built in one go, level 12 froze the game for
  3.5-4.5 s; it now takes about 1.5 s, without freezing (measured in a window).
- **The build flag is raised the moment `new_game()` stops waiting** for the last build, so two builds
  can never share one board (Storm crashed on exactly that when the flag was raised late).
- **A won round waits for the build too** before its `reset()` in `level_is_done()`. `reset()` frees
  the cells, and a build paused in `_breathe()` read them on resuming: an engine segfault (signal 11)
  in `is_fillable()`, not a script error. `probe_gate` hit it by deciding rounds before the board
  existed; it now waits for `_building` to drop (`_settle()`), as a player has to.
- **The corridor search is a faster copy of the shared one**, finding exactly the same paths
  (`_corridor_astar()` and `_corridor_reachable()`, as in Storm: the cost inline, packed arrays for
  the states, a byte mask of built tiles, and a flood under looser rules that skips a search that
  could not succeed). Measured in Storm: the search 2x faster, and most of the hopeless searches skipped.
- **A corridor's tiles are listed in walking order** (`_try_corridor_L()`, Storm's fix). A straight
  run going up or left was listed low to high, and the door put one step back from its first two
  tiles could land off the board -- a crash Storm showed about one build in five.

`devtools/probe_mmm_build.gd` checks all of it: rounds at random levels often mid-build leave a whole
board, the fast search matches the shared one on every query, corridors are in walking order, and the
briefing holds, releases after the build and a second, starts the round on close, and does not end it.
`level.probe_real_round` lets it do that in tutorial mode (which is what keeps a probe from writing
scores) with the real levels and the real card, which tutorial mode otherwise swaps for the lesson's.

## A replay starts clean

`new_game()` runs after EVERY round, so it cannot clear the level's counters unconditionally.
`_level_is_over` is set by `_finish_level()` and is what tells `_advance_if_needed()` that a LEVEL
is starting: only then does it reset `round_in_level` and the round tally (`_rounds_played`,
`_rounds_fully_correct`, `_round_had_wrong_answer`). Otherwise a retry would inherit the rounds that
failed the level and could not pass it even played perfectly.

`game.corrects` / `game.mistakes` are deliberately left alone — they are the session's map answers,
not the level's rounds.

## A failed level earns nothing

`_score_at_level_start` is stamped when a level begins — in `new_game()` for the first level of a
session, in `_advance_if_needed()` for every level after it, in both cases AFTER the rollback so
consecutive failures all measure from the same point. A level that misses the gate goes back to it
(`_rollback_score_on_next_level`), applied when Continue is pressed rather than when the level ends,
because watching the score drop out from under a summary you are still reading is alarming.

Without it the gate is a scoring exploit: the score is cumulative across a session, so every failed
attempt banked its points and the retry cost nothing.

## Tutorial

`mmm/scripts/tutorial.gd` (vaults, then the map; 2026-11-16). Two things are not obvious on sight: that a
vault is opened by walking INTO it, and that the test comes later, on a plain map -- you must know
where in the castle each room is. The coach spots the first vault ("remember which room it's in"), asks the
player to notice the way to the second room, and stays with them through both
questions on the map.

- **The smallest castle**: two rooms, so two vaults (`_tutorial_setup`: `num_rooms = 2`, no bombs, no
  monsters, no bricks).
- **A silent step waits for the castle** before the player is pointed at: a quick reader tapped past
  the title while the castle was still being built, and the next step's spotlight had no player to
  frame (`advance_when` on `tutorial_player_rect()`).
- The player is framed by their CELL (`tutorial_player_rect`) and the pedestal by its
  (`tutorial_pedestal_here_rect`, also a keep-clear zone in `main.gd`, with the showing cards).
- The captions name the actual objects (`tutorial_last_found_name`, `tutorial_request_name`).
- Events: `found`, `map_shown`, `asked`, `room_answered`, `map_missed`, `map_done`. A finished tutorial
  round never shows the round card.
- `devtools/probe_tut.gd -- mmm` plays it: routes into a vault not opened yet (the route may END on a
  solid vault), and on the map taps a tile of the room holding what is asked about.

## The ground and the camera

The Level is a `CanvasLayer` with `follow_viewport_enabled`, so everything in it moves WITH the
camera. This game's camera is parented to a moving node and PANS, so a screen-anchored ground in
that layer covers the screen once, at the start, and is then walked off the edge of — bare screen
at the sides.

The ground therefore sits in a nested `BgLayer` (`CanvasLayer`, `layer = -1`) — the arrangement
gorilla already used. That layer DOES follow the viewport, because what is in it is no longer a
screen-sized texture but a board-sized lawn (see "The lawn" below): a ground that covers the board
has to be drawn in the board's space, or it appears at the wrong scale the moment the camera zooms.
storm, delemfp and gorilla are the same. Games whose Level layer does not follow the camera at all
(deliverem, guidem, lightsout, parkem, pneumo, pop, taxi, wolves) have no BgLayer and put the lawn
straight into the Level layer.

`probe_look.gd` fails if a BgLayer goes missing, is empty, or stops following a camera its Level
follows.

**The camera frames the room you are in** (copied from Storm), **at one zoom for the whole round.**
One camera (`game_cam`): during play it centers the player's room at the zoom that fits the castle's
LARGEST room -- its tiles plus `FRAME_MARGIN` (a quarter tile) a side, across the screen's width, or
between the HUD strip and the button bar if it is taller than that (`_play_zoom`,
`_largest_room_zoom()`, `_frame_for()`). Each room at its own largest zoom was tried first and moved
too much: with rooms of 5 to 11 tiles the zoom changed by up to 2x between rooms. Walking into another room glides the frame over (`ROOM_GLIDE_SEC`); in a
corridor it follows the player at the zoom it had (`_follow_player_room()`, run after the player each
frame: `process_priority = 1`). Stepping into a corridor clears the framed room, so the next room
walked into is framed afresh even when it is the one just left: the frame used to be redone only for
a DIFFERENT room, and walking out into a corridor and back left the view where the corridor had taken
it -- on level 12 the player walked off the top of the screen. `probe_mmm_build` walks that route and
checks the player is on screen, and that every room gets the same zoom. While storing the
player never sees more than a room and the corridor they are in -- the map in their head is theirs to
build. The questions are asked on the whole castle.
It replaced a camera parented to the player at ONE zoom for every room, sized for the widest room
the game can make plus two tiles -- so a 5-wide room took up half the screen's width. Measured: a
7 x 9 room fills the band from y 78 to 726 of 788 (at its own zoom, before the zoom was fixed).

**The map frames the corridors too** (`_castle_rect()`, as in Storm): the rooms' outline
grown by `CORRIDOR_REACH` (3), the reach the corridor search is confined to, kept to the board. It
framed the rooms alone, and in 10 of 12 builds some corridor ran up to 3 tiles outside and was cut off
(`probe_mmm_build`, framing the rooms alone: 50 of 596 tiles).

**A bit faster in a corridor** (`_set_player_pace()`, `CORRIDOR_RUN` 2): a corridor holds no pedestal and
asks nothing. Each step into a corridor tile is taken at twice the walking speed, and in a corridor
the next step is taken the frame the player arrives rather than at the next game tick (`_process()`).
Measured at 60 fps: 145 ms a corridor tile against 236 in a room, about 1.6x. (Storm runs at 3x.)

**No room wider than 11 on a phone** (`_room_side()`, `MOBILE_MAX_ROOM_SIDE`, as in Storm): a room's
side sets the tile size, and 13 would give about 5.4 mm tiles. mmm's range, 5..10 made odd, tops out
at 11 already; the cap keeps it so if the range grows.

**Twelve rooms fit where Storm's nine did** on the same 75 x 75 board at level 12 (6 builds of 6 got
all 12): mmm's rooms are 5, 7, 9 or 11 tiles a side, Storm's 9, 11 or 13 -- about half the area.

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the eleven grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(get_node_or_null("BgLayer"), get_node_or_null("BgLayer/TextureRect") as CanvasItem, game, 7)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to `BgLayer` (a nested `CanvasLayer`, `layer = -1`, `follow_viewport_enabled`) so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 7 — so no two games show the same field.

It is called twice: at the end of `_ready()`, so the lawn is already there before the first board is
built, and at the START of `create_board()`, for a level that changes the board's size. `fit()`
re-sows only when the rect actually changed, because the field is a `MultiMeshInstance2D` of tens to
hundreds of thousands of blades and building it is not something to redo between rounds.

Every empty cell used to carry its own 40x40 `grass.png`; `empty_space.gd`'s `_ready()` now hides it.
That per-cell sprite was the real reason the board looked tiled — the background alone was never
it — and the per-cell random rotation some of these games applied made it worse, because the tile
wraps seamlessly and turning a cell breaks the wrap.

`probe_lawn.gd` checks all eleven: the field exists, is the first child of its layer, is sown before
any board is built, covers the board and the canvas, retires the tiled ground only once it has
something in it, and that no cell shows its own grass again.

## No snake body

This game's agents are a head and nothing else. `agent.gd` and `player.gd` used to carry the whole
trailing-body rig copied from the delivery games — `body_ids`, `bodies`, `nbody_parts`, a
`time_back_positions` trail, `find_closest_dist()`, `add_body`/`remove_body`/`final_remove_body`, a
`Skeleton` `Line2D` to string the segments on, and a `tube_animation.tscn` built from
`agent_body2.png` / `agent_body3.png` — but the level always assigned an EMPTY `body_ids`, so the
build loop never ran and not one segment was ever created. Measured by running the game and counting
the nodes, not by reading it.

All of it is gone: both scripts, the `Skeleton` node in `agent.tscn` and `player.tscn`, the
`tube_animation` scene and script, and the two PNGs. `angles` keeps a single entry, the head's
heading, which is all `set_rots()` ever read.

**parkem is the one game that really does grow a body** (four segments on level 1, two on level 2),
so its rig stays. Do not copy this game's `agent.gd` there, or the reverse.

While it existed, this game's build loop called `anim.play("EnemyBody")` — an animation its
`SpriteFrames` never defined; only `"main"` was there. It never raised anything because the loop
never ran, but a single segment would have sat frozen on frame 0. storm had the identical bug.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

## The chooser tile

`art/game_screen_200.png` is **drawn** (`devtools/make_thumbs.py`, `mmm()`), not grabbed. The old
tile was the castle as a floor plan: flat colored boxes joined by gray lines on a flat green that
was not even the game's current lawn. Accurate, and it read as a diagram.

It is now a palace: four towers at dusk, each in one of the room colors from the game's palette
(`GenericGameUtil.colors`: red, blue, yellow, cyan, picked to be far apart), which is what a round
asks you to remember. Each tower is shaded as a round one lit from the left, with a crenellated
parapet, faint stone courses, a cone roof in a deeper shade of its own color (the red one has none),
and a warm light in some windows; the tallest, in front, has a door and a pennant, and the one
furthest back is hazed toward the sky. They stand on the lawn every grass game now has
(`GrassField`'s ground and blade colors). The grass and the towers are drawn in depth order: a blade
rooted above a tower's foot is behind it, one rooted below is in front. All the grass used to go on
last, so every tower wore the same fringe at its foot however far away it stood. Checked at chooser
size: it still reads as four colored towers.

## Look (2026-10)

- Monsters, bombs and the player are drawn by `scripts/monster_art.gd` (a menacing bug; a glossy black
  bomb with a colored band, brass collar, curling fuse and spark, upright and centered; the player a
  glossy round creature with feet, eyes that blink); turns and corners eased by
  `scripts/head_anim.gd` + `scripts/path_smoother.gd`.
- Bricks are drawn by `scripts/block_art.gd`: three types (deep red long bricks; pale pink narrow
  bricks; red with sandy ones mixed in) in one mortar.
- Doors are the shared drawn gate / nail stubs (`scripts/door_art.gd`).

## The main menu's poster

`scripts/menu_world.gd` (`main.gd` `menu_backdrop()`, extending the shared `scripts/menu_poster.gd`;
the shared `main_menu.gd` keeps only a slim panel at the foot): a palace floating in the game's night sky (palace_sky.gdshader) on a rock with roots hanging, two islets with turrets beside it, five towers with stone courses and arched windows, glowing stepping stones floating up to the gate; behind it slowly twinkling stars, a moon and a violet glow. Its windows light one by one in the rooms' colors until the whole palace glows, then go dark (11 s). THE PALACE IS DRAWN ONCE and never moves -- only soft things do (mist, the window light, the stones' glow, the flags): the first version bobbed the whole palace and twinkled fast, which the user saw as jitter and flicker.
Made up, never the board: the menu also opens mid-game.
