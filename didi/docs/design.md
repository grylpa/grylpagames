# Pinpoint (folder `didi`) — design

**A stakeout** (2026-11-15). You watch a night square from a rooftop, in the rain. LIGHTNING lights
it for a moment: at the center a **courier** holds an umbrella (WHAT: its print and colors), and at the
same instant a **lookout** in a yellow raincoat is glimpsed at one of the eight street mouths (WHERE).
Then it goes nearly dark (the MASK), the street lamps come on, and umbrellas
stand at every corner. One tap answers both questions: the courier's umbrella, at the lookout's corner.

The trap is deliberate: other corners also hold an umbrella with the courier's print (`num_same`),
so remembering only the umbrella puts you at the wrong corner, and remembering only the corner leaves
you picking between umbrellas.

**Why this game, and why this shape.** Of the four flash games it was kept (Witness, Glimpse and
Lineup are hidden) because it is the closest to the research task with the most support behind it:
the "useful field of view" speed-of-processing training of the ACTIVE study -- a center item and a
peripheral target shown TOGETHER, briefly, then masked, with the display time adapted to the player.
The redesign made it faithful on the four points it missed: the two cues used to come one after the
other (the dot 150 ms after the shape), there was no mask, the time was fixed per level, and there
was no clutter. Its single tap (where + what in one) was kept over Witness's two answers: half the
input, more rounds a minute, and both halves still recorded (`got_dir`, `got_shape`). The study's
results must never become an app claim.

## Files

```
didi/scripts/
├── globals.gd        DidiG autoload: starting_level, save/load settings
├── level_config.gd   DidiLevelConfig.LEVELS — 8 levels, all the timing lives here
├── main.gd           orchestrator: menu, HUD, instructions
├── level.gd          the round machine: the flash, mask, lamps, answer clusters, staircase, scoring
├── agent.gd          one person, drawn three-quarter: under an UMBRELLA (print + colors), the LOOKOUT, a PASSERBY
├── plaza.gdshader    the square, three-quarter view: 8 streets, buildings, fountain, lamps, rain;
│                     its lightning, mask (rain on glass) and lamps
```

## A round

1. `_spawn_model()` — the LIGHTNING. The courier's umbrella at the center (its print `texture_idx`, one
   of `agent.PRINTS`, and its colors kept as `_round_model_texture_idx` / `_round_model_color`), and in
   the same frame `_spawn_periph_flash()` (the lookout, `_periph_dir_idx` 0-7, on ONE RING, `PERIPH_R`
   tiles out in every direction) and `_spawn_clutter()` (`clutter` passers-by in dark coats on the same
   ring, clear of the lookout and of each other). All of them last `_flash_ms`, and the plaza is lit
   while they show.
2. When they have gone, `_maybe_start_answer()` raises the MASK for `MASK_MS` (280): near darkness,
   so nothing lingers on the eye and the display time is the time the player really had.
3. `_dispatch_answer_stage()` — the LAMPS come on (`LAMPS_MS`) over eight clusters of `num_options`
   umbrellas, on one ring (`CLUSTER_R`) for every corner. `num_same` corners hold the courier's print,
   always including the lookout's. Exactly one umbrella has `is_correct`.
4. `_on_answer_agent_pressed()` scores as before: full marks for `is_correct`; +1 partial for the right
   corner with the wrong umbrella, or the right umbrella at the wrong corner; a miss otherwise. The
   answer stage times out after `_time_to_consider_fail_ms`.
5. `_show_feedback()` — the tapped umbrella is ringed green or red; after a miss the right one is
   ringed gold and the lookout stands again where it was, for `FEEDBACK_WRONG_MS`, so the player sees
   what they lost. Then the next round.

**Equal distances** (2026-11-15): the lookout and the clusters used to be placed toward the board's
edge squares, which put the corner directions 41% further out than the straight ones -- harder in
four directions than the other four. Both are on rings now.

## The adaptive flash (a staircase)

`_adapt(right)`: three fully right rounds in a row shorten the flash by `STEP_DOWN` (x0.85); any miss
(a partial, a wrong tap, a timeout) lengthens it by `STEP_UP` (x1.20), between `MIN_FLASH_MS` (34, two
frames) and `FLASH_CEILING` (1.6) x the level's `flash_ms`. This keeps every player near their own limit
(it settles near 80% right) instead of a fixed time that is too easy for some and too hard for others.
Not in the tutorial. The LEVELS add complexity instead: more umbrellas per corner, more look-alike
prints, two-colored canopies from level 5, passers-by from level 3.

## Timing and pause

Both the level's scheduler and `agent.gd` measure against `game.game_time`, which excludes paused
time. So while anything pauses the game — including a tutorial caption — a flash that is on screen
STAYS on screen, and the round clock does not advance. The plaza's lightning follows the figures
(`_light_plaza` lights it while they are visible), so it holds too. That is what makes this game teachable at
all: the coach can freeze the moment the shape appears and talk about something the player can
still see.

## Passing a level

Finishing a level's rounds is not the same as passing it. `Level._level_done()` measures the accuracy of
the level just played — `game.session_pct_correct()` over that level's own `corrects`/`mistakes` —
against a bar that rises with the level:

```
need = mini(60 + 2 * (level - 1), 70)
```

Below it the SAME level comes round again; at or above it, the next one. The gate's result is
`game.need_to_increase_level`, which `new_game()` feeds to `_load_cfg(game.need_to_increase_level)`.

Before this, `need_to_increase_level` was set to `true` unconditionally — finishing the rounds WAS
passing, so a player could get every single answer wrong and still be moved up, which made the
accuracy on the summary card decorative.

The bar is stated to the player as "at least NN%", so the test is `>=`. The last level
(`DidiLevelConfig.MAX_LEVEL`) is exempt: there is nothing to be promoted to, so it ends as it always did.

## "complete!" only when it was

This game can now END a level without PASSING it, so `show_level_done_popup` is called with the
gate result as its `passed` argument. The card reads "Level N complete!" with a check badge on the
success color, or **"Level N not passed"** with no badge on the warning color — a tick over "you
need at least NN% accuracy" is the card congratulating the player for failing.

The card also says what happens next in words, because a percentage on its own does not tell the
player the one thing they want to know:

- passed → `Level passed — on to level N.`
- failed → `You need at least NN% accuracy to pass to the next level.`

`MainGlobals.global_level_is_done()` is given the same result, so the level-done fanfare no longer
plays over a level that was not passed.

## A replay starts clean

Failing the gate brings the same level round again, and that has to be a fresh attempt.
`new_game()` clears `game.corrects`, `game.mistakes` and `_times_to_answer` on **every** level start, not
just `if from_scratch`.

The counters matter twice over. The visible half is the HUD still showing the failed attempt's
tally. The half that decides the game is that the GATE reads them — a replay which inherited the
misses that failed the level could not pass it even played perfectly. The timing list is the same argument applied to the card's "Average time" row.

`score` deliberately does NOT reset here — it accumulates across a session, and only
`game.reset(true)` clears it.

The HUD repaint is already covered: `main.gd`'s `new_game()` calls `hud.update_all()` immediately
after `$Level.new_game()`. (polkadots is the game where that was missing, which is why the shared
note about repainting next to the clearing exists.)

## A failed level earns nothing

`_score_at_level_start` is stamped at the top of `new_game()` — after the rollback, so consecutive
failures all measure from the same point — and a level that misses the gate goes back to it.
Otherwise the gate is a scoring exploit: the score is cumulative across a session, so every failed
attempt banked its points and the retry cost nothing — fail forever, earn forever.

**When** it happens is split on purpose:

- The score ROW is written the moment the level ends (`main.gd` saves on `game.sig_level_is_done`),
  so the kept value is swapped in just for that emit and swapped straight back. Without it, failing
  the same level repeatedly would farm the score list. This is why the gate is computed at the TOP
  of `Level._level_done()`, before anything is emitted.
- The VISIBLE score keeps showing what the player played with while the summary card is up:
  watching the number drop out from under a summary you are still reading is alarming. The visible
  rollback lands in `new_game()`, behind `_rollback_score_on_next_level`, when Continue is pressed.

Only the failed level's points go back; everything earned in levels already passed is untouched.

## Tutorial

`didi/scripts/tutorial.gd`, entry `didi/scripts/main.gd::start_tutorial()`.

You cannot learn this by watching, because by the time you know to look, both cues are gone. So the
tutorial FREEZES ON THE LIGHTNING (pausing holds the figures and the light) and points at each cue in
turn while it is still lit -- the courier's umbrella, then the lookout -- and only then lets the lamps
come on. The decoys are named explicitly, because "the courier's umbrella also stands at other
corners" is the rule that makes the game hard and the one a player is least likely to work out before
losing several rounds to it. (Since the stakeout both cues appear together, so `model_shown` and
`periph_shown` fire in the same frame and no step waits for the second one.) No staircase in the
tutorial. `probe_tut.gd -- didi` drives it: 9 steps.

Specific to this game:

- **The round is held at the gate** (`tutorial_hold_round`) until the player dismisses the "watch
  the center" caption. The shape spawns half a second into a round, so waiting on `model_shown`
  alone meant that caption flashed past before it could be read, let alone acted on. Held, the
  round starts on their tap and the flash is the next thing they see.
- **The level popup is skipped** in tutorial mode (`create_board` calls `_on_game_popup_closed()`
  directly): a panel of level timings in front of the coach is the first thing a player would have
  to dismiss.
- **The final step ignores every tap but the right one** (`tutorial_only_correct_taps`): no score,
  no partial credit, no round ending. It also FRAMES the correct umbrella, because that step is a
  demonstration of what "right umbrella, right corner" looks like rather than a test — the closing
  step then says that in play nothing is framed and near misses do score.
- `_time_to_consider_fail_ms` is pushed out of reach for the tutorial and restored afterwards: a
  6 s answer clock is fine for play and absurd for someone reading a caption.
- Events reported to the coach: `model_shown`, `periph_shown`, `answer_ready`, `answered_right` —
  all `game.tutorial_notify`, no-ops outside tutorial mode.

## The scene: the square, three-quarter view

`plaza.gdshader` on a ColorRect first in the Level layer (`_fit_ground_to_board`), covering the board plus
a four-tile margin and the whole canvas, laid out from the board's CENTER and `tile` in world units. The
square seen STEEPLY FROM ABOVE, as an old top-down adventure game draws a town: the round square and its
EIGHT STREETS laid out flat (each answer direction is a street, each spot stands at a street's mouth),
the buildings between the streets drawn with their roofs AND the brick front wall that faces us (lit
windows here and there), lamp posts at the street mouths standing up the screen, a round fountain in the
middle, rain.

**Three tries, 2026-11-15.**
1. STRAIGHT DOWN: the directions were crisp (streets) and the umbrellas' prints read whole, but people
   were shapes -- "different background colors of the same game", the lookout an eye.
2. STREET VIEW (from a low rooftop, people side-on): the story came through, but it was LESS EFFECTIVE --
   the eight spots became a circle on a perspective floor with nothing marking the directions, the
   prints shrank to thin side-on domes, and buildings, posts and bodies cluttered the flash. Both the
   WHAT and the WHERE got harder to catch.
3. THREE-QUARTER (this): the top view's geometry and prints, the street view's people.

**Fairness.** The square, streets, lamps and roofs are the same under a 45-degree turn; only the front
walls break it (they face us, at the top), and they stand outside the ring, behind no one. Every
umbrella is the same size (`CANOPY_TILES`), every person without one too (`PERSON_BOOST` larger), and each
figure stands `FIG_DROP_TILES` below its point so its UMBRELLA, not its feet, is on the ring.

Its lights, set every frame by `_light_plaza()`: `flash` -- the square only MODERATELY brighter, so the eye goes to
the people (drawn in their true colors); `mask` -- RAIN RUNNING DOWN THE GLASS we look
through, `MASK_MS`: streams and scattered beads over a dark blue wash, soft and low contrast; `lamps` --
warm pools at the street mouths, for the answer. The rain: thin slanted streaks and splash rings.

**The mask's history.** Blocky noise read as TV static; a sheet of driving rain was "disturbing"; plain
BLACK was calm but lets the afterimage linger (a dark field prolongs it), so the player effectively saw
longer than the flash -- weaker training. The research masks with a PATTERN for that reason; rain on glass
is a pattern that fits the story and stays gentle.

**The figures** (`agent.gd`, origin at the feet): UMBRELLA -- the canopy seen almost from above (eight
panels drawn round, then foreshortened by `SQUASH`), carrying one of seven PRINTS (`plain`, `stripes`,
`dots`, `rim`, `cap`, `half`, `ribs`), with the person's coat hem and legs below its front edge; LOOKOUT --
a yellow raincoat under a clear umbrella; PASSERBY -- a plain black umbrella. The print
is DARK on a light canopy and light on a dark one (a pale tint made every umbrella read the same).
`spin` turns the canopy; the spots' umbrellas copy the courier's unless the level has `rotate`. The person
under an umbrella is random and means nothing. Figures are lit by the moment (`set_light`), sorted front
to back by their y, and tapped on the umbrella and the person under it.

**The camera fits the whole SQUARE** (`_create_camera`): `VIEW_W_TILES` x `VIEW_H_TILES`, between the HUD
strip and the button bar, its middle `VIEW_MID_TILES` above the fountain. Fitting the board's width alone (as the old board game did) put the
buildings above the shorter desktop canvas and the ring too high.

**Two or more per spot, ALWAYS** (`num_options` >= 2). The research task always asks for both answers --
the center item (from two) and the place (from eight). One per spot was tried at levels 1-2 for a gentler
start and taken back the same day: with one umbrella at a spot, knowing the spot is enough, and the
center item stops mattering. The gentle start is instead the research's own: at level 1 `num_same` is 8
(the courier's umbrella stands at every spot) and the decoy beside it is CLEARLY different
(`same_color_alts` off: another color as well as another print -- "a car or a truck"). From level 2 the
decoys share the courier's color, so only the print tells them apart; later levels add decoy spots
(`num_same` < 8), more people per spot, two-color canopies, turned umbrellas and passers-by.

**Each spot is a GROUP IN ITS STREET, centered on the lookout's place, with no one ON it**
(`_get_cluster_positions`): a PAIR down the street, one nearer the fountain and one farther
(`QUEUE_STEP` apart); a TRIO as a triangle whose center is the lookout's place, its tip toward the
fountain and its base toward the screen's edge (`TRIANGLE_H`, `TRIANGLE_HALF_BASE`). So the groups are
clearly separate (each in its own street, set apart by the roofs), sit exactly round where the lookout
flashed, and no single umbrella is singled out by standing on that very spot. Tried and replaced the
same day: people side by side across the street (at 170 and 190 degrees for a lookout at 180, and the
sixteen umbrellas formed one even ring with no visible groups); the same round the lamp posts; and a
queue with one umbrella exactly on the lookout's place. At most 3 per spot (`num_options`), so the groups
stay on screen. The lamp posts stand at the KERB of each street mouth, clear of the groups. The
passers-by stand at the OTHER spots first (the research's hardest stage fills the other places with
look-alikes), then between them. No jitter: the research task's targets are at fixed places too.

**The light on the figures is NEUTRAL** (`LIGHT_FLASH`, `LIGHT_LAMPS` both white): an umbrella's color is
part of what the player remembers, and a cold light in the flash and a warm one in the answer shifted the
same color two ways, so the right umbrella did not match the courier's. The scene carries the lightning
and the lamplight.

**The lookout** is a yellow raincoat under a SEE-THROUGH umbrella -- the same size and drawing as every
umbrella, the only clear one -- and the passers-by carry plain BLACK umbrellas. Everything in the square
is an umbrella. Tried and dropped the same day: a yellow figure from straight above (it read as an eye),
and a whole slim person raising a lit torch (too big and too dull beside the umbrellas; the question
"what is it?" had only meant that the flash was too short to tell).

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

**Per-direction accuracy, drawn as a 3x3.** Every direction asks the same question, so there is
no reason to be better at one than another and a corner the player keeps missing is a finding —
which one percentage for the session cannot show. Each answer records a `slot` (row * 3 + column,
4 the centre) and a `dir_name`, so `scripts/direction_rose.gd` knows nothing about this game's
own index order; it is the same arrangement as the rule games handing over a rule name rather
than a key.

**A direction that stands out is outlined.** Under "direction makes no difference" the hits in
one direction are binomial with the player's overall rate, so the deviation is measured in its
own standard errors. `DirectionRose.FLAG_SD` is 2.5, not the 2.0 the baseline band uses, because
this is EIGHT tests at once: at 2.0 the chance of at least one false mark across eight is about
31%, which would mark a healthy player most sessions; at 2.5 it is about 9.5%. A direction with
fewer than `MIN_PER_DIR` rounds is never marked — a proportion out of four is not a finding.

**And Pinpoint's second question.** A wrong answer here can keep the place and lose the shape or
the other way round, because the player taps a cluster in a direction, so `got_dir` and
`got_shape` travel with the trial and the panel reports which half survived. Rounds wrong on both
counts say nothing about which went first and are left out of that figure.

Timeouts are recorded as wrong in that direction. Leaving them out would flatter whichever
direction the player freezes on.

## The chooser tile

`art/game_screen_200.png` (200 x 200) is **drawn** (`devtools/make_thumbs.py`, `pinpoint()`), not grabbed. The old tile was a screen grab of the eight answer clusters, with one shape recoloured green.

It is now a **radar screen**, not the game's own shapes: a dark scope, one inner ring and a crosshair,
a bright rim, a sweep, and a single large blip off to one side. "Where did it flash?" is the question
the game asks, and a radar is the picture of it. Drawn bold -- few lines, thick rim, big blip -- so it
still reads at chooser size; a finer radar with more rings lost its appeal when small. A compass with a
push pin and an eye with a spark at the edge of its view were turned down.

**Open (2026-11-15):** the radar no longer fits the stakeout, nor does the `dispatch` sound (a radar
ping, now played with the lightning). Both wait until the stakeout's look is approved.

## Sounds

Made for this game by `devtools/make_answer_sounds.py` (synthesized, seeded; it makes the same set
for Witness, Pinpoint, Lineup, Glimpse, Friends and Moving Cards, each in its own key and with its own
"shown" sound). Names in code kept: `dispatch` = the target appearing (a radar ping), `delivery` = a right
answer (a rising two-note chime), `swoosh` = a wrong one (a soft low note), and `ambient_audios` holds
one loop (`didi_ambient.ogg`, -6 dB: harp arpeggios in D lydian, a glass bell phrase now and then, made by `devtools/make_ambient_sounds.py` with its music engine `devtools/music.py`. The first version laid band-passed white noise under a thin chord (heard as hiss), the second was a slow pad of held chords (heard, over minutes, as "almost-single-tone" and irritating); the tune is kept sparse and soft, never tied to when a shape flashes). They replaced a heavy bell, an
arcade coin, a swoosh and three stock ocean-wave loops picked at random.
The ambient is calm for the same reason the backdrop is featureless: this game measures attention,
and nothing in the background should pull it.
