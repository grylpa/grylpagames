# Whack — Game Design & Implementation Document

## Overview

**Game name:** Whack
**Folder:** `whack/`
**Singleton:** `WhackG`
**Save key (short name):** `whack`
**Initial time:** 10 minutes
**Background color:** `res://art/grass.png` tiled TextureRect (shared default); clear color `0x3C5D3EFF` as fallback
**Initial score:** 100, `game_over_on_zero_score = true`

Whack is a reaction-speed and accuracy game. A circular target appears at a random position on the screen. The player must tap it as fast as possible before it disappears. Only taps whose center lands inside the target count as hits. Two metrics are tracked: reaction time (ms from appearance to tap) and accuracy (100 = center hit, 0 = edge hit).

---

## File Structure

```
whack/
├── docs/
│   └── design.md           ← this file
├── art/                    (empty — uses shared sounds only)
├── scripts/
│   ├── globals.gd            (WhackG autoload)
│   ├── level_config.gd       (WhackLevelConfig — per-level params array)
│   ├── main.gd
│   ├── level.gd
│   └── draw_area.gd          (Control subclass, draws target via _draw())
└── scenes/
    ├── main.tscn
    └── level.tscn
```

---

## Registration

### `project.godot` autoloads
```
WhackG="*res://whack/scripts/globals.gd"
```

### `scripts/config.gd`
```gdscript
["whack", "Whack", "Tap the target as fast and accurately as you can"],
```

---

## Scene Structure

### `scenes/main.tscn`
Root node `Main` (Node, `main.gd`). Children:
- `Level` — instance of `level.tscn` (CanvasLayer)
- `HUD` — instance of `res://scenes/generic_game_hud.tscn`
- `GameTick` — Timer, wait=0.05s, autostart
- `Help` — instance of `res://scenes/help.tscn`, hidden

### `scenes/level.tscn`
Root node `Level` (CanvasLayer, `level.gd`). One child:
- `DrawArea` (Control, `draw_area.gd`) — `mouse_filter=STOP`, fills viewport, handles both drawing and tap input

---

## Globals (`WhackG`)

| Variable | Default | Description |
|----------|---------|-------------|
| `starting_difficulty` | 1 | Starting difficulty (1–6) |

Settings saved as `[starting_difficulty]`.

---

## Difficulty Levels

Defined in `scripts/level_config.gd` (`WhackLevelConfig.LEVELS` array). Number of levels = array size. Each entry:

| Field | Description |
|-------|-------------|
| `radius` | Target radius in pixels |
| `interval_min_ms` | Minimum ms between targets |
| `interval_max_ms` | Maximum ms between targets |
| `show_ms` | Ms before target auto-disappears |
| `hits_to_complete` | Hits to advance to next level |

| Level | Radius (px) | Min (ms) | Max (ms) | Show (ms) | Hits |
|-------|-------------|----------|----------|-----------|------|
| 1     | 48          | 1000     | 2500     | 2000      | 10   |
| 2     | 40          | 900      | 2000     | 1500      | 12   |
| 3     | 33          | 800      | 1800     | 1000      | 12   |
| 4     | 27          | 700      | 1500     | 1000      | 15   |
| 5     | 22          | 600      | 1200     | 800       | 15   |
| 6     | 17          | 500      | 1000     | 700       | 20   |
| 7     | 10          | 500      | 1000     | 500       | 999  |

---

## Gameplay Flow

1. Target appears at a random position (avoiding HUD top area and bottom button bar, plus `radius + 12px` edge padding)
2. Player taps within the target area (`distance_to_center <= radius`) → hit
3. Tap outside the target area → miss (penalty, no target disappears)
4. Target times out if not tapped within `show_ms` → miss penalty, next target scheduled
5. After `corrects_for_next_level` hits: level advance popup, then next level (except at max level — see below)

**Last-level loop (level 7):** At max difficulty, completing 999 hits saves the score silently and immediately restarts at level 7 — no popup, no difficulty increase. Both `_reaction_times` and `_accuracies` (rolling windows of last 20) persist across loops so the saved avg reaction time and avg distance reflect a running average over recent rounds.

**Sound effects:**
- Appear: `res://art/sounds/click-2.mp3`
- Hit: `res://art/sounds/tap-1.mp3`
- Miss (out-of-area tap): `res://art/sounds/bump-sound-7.mp3` (no sound played — penalty only, sound suppressed to avoid spam on rapid tapping)
- Wrong (decoy hit / target timeout): `res://art/sounds/swoosh.mp3` (once per mistake event)

**Visual feedback:**
- Green flash at tap position on hit
- Red flash at tap position on miss
- Urgency orange ring around target when >70% of show time elapsed

---

## Scoring

- Hit (in-target tap): `+max(1, 20 - reaction_ms/200)` score, `+10s` time
- Miss (out-of-target tap): `−3` score, `−3s` time
- Timeout (target disappears unhit): `−5` score, `−5s` time
- `game_over_on_zero_score = true`

**Distance metric:** raw pixel distance from tap center to target center, for successful hits only.
- 0 = perfect center hit
- Values up to `radius` (e.g. 0–48 px at level 1)
- Out-of-target taps do not affect the distance average

**Reaction time:** time from target appearance to valid (in-target) tap, in ms. Stored per hit. Mean over last 20 hits used for stats.

---

## Score Row Format

| Index | Field |
|-------|-------|
| 0 | unixtime |
| 1 | score |
| 2 | time_left_sec |
| 3 | times_run |
| 4 | didwin |
| 5 | wasaborted |
| 6 | last_level (POS_SCORE_DIFFICULTY = 6) |
| 7 | mean_reaction_ms (POS_SCORE_MEAN_REACTION_MS = 7) |
| 8 | mean_dist_px (POS_SCORE_MEAN_DIST_PX = 8) |

---

## Stats Screen

- **Scores tab**: Date | Score | Level
- **Speed tab**: grouped by level, shows avg reaction time and avg distance (px)
- **Chart tab**: Score, Avg Reaction Time, Avg Dist; x-axis toggle available

**Bottom bar in main menu:** help (`h`), mute (`t`), scores (`o`) buttons.

---

## Main Menu

One slider entry:
1. **Difficulty** (1–6) — starting level

---

## Shared System Notes

See `rlmadness/docs/design.md` → "Shared system changes" for details on:
- Chart tab design and x-axis toggle
- `score_was_changed` save gate
- Per-level saves: `save_score` is called at each level completion so the speed table shows all levels played within a session, not just the final one
- Monotonic mode, % Correct column

---

## Score feedback

Every scoring event puts a floating number where it happened: green `+n` for a hit, red `-n` for a
mistake. The flash that was already there says *something* happened; the number says what it cost,
which is the part the player is trying to learn.

| event | shown | why |
|---|---|---|
| hit | `+max(1, 20 - reaction_ms / 200)` | at the tap, so it also reads as accuracy feedback |
| decoy tapped | `-5` | at the tap |
| tap on empty space during a live round | `-3` | at the tap |
| real target left to expire | `-5` | at the target's last position, captured before it is cleared |
| empty round survived without a tap | `+NO_TARGET_REWARD` (5) | at the centroid of the decoys the player left alone |
| empty round in which the player tapped anything | nothing | see below |

Waiting out a round with no real target is the one correct decision the game used to pay nothing
for: letting a real target expire costs 5 and tapping a decoy costs 5, but tapping nothing when
there was nothing to tap scored zero either way, so patience was never worth anything.

The reward is gated on `_round_was_tapped`, set by **any** tap in the round, not just a penalized
one:

- Gating it on the *penalty* instead would make a tapped decoy net out to zero — pay 5, get 5 back
  — silently refunding a wrong tap. That was the first version of this and it was wrong.
- Tapping bare grass in an empty round is free by design (`_on_draw_area_input` deliberately
  charges nothing when there is no real target), but it is still not *waiting*, so it must not earn
  the reward either. Score change for that round: zero.

### No round is ever empty

A round with no real target *and* no decoys puts nothing on the screen at all. Level 1 shipped able
to produce one — `no_real_chance: 0.1` against `num_decoys: 0`, measured at **9.8% of level-1
rounds** — and nobody ever noticed, because a contentless round is indistinguishable from the gap
between rounds: 2000 ms of nothing, against an inter-round gap that is already 700–1500 ms. It had
no consequence, so it read as a slightly slow round. The wait-it-out reward would have given it
one, paying 5 points for sitting through a blank screen with no decision in it.

Two changes, because either alone is insufficient:

- level 1's `no_real_chance` is `0.0`, which is what a level with no decoys has to be;
- `_spawn_round()` forces `_round_has_real` back on for an **organic** round that would otherwise
  contain nothing.

The guard has to sit **before** the `if _round_has_real:` block that places the target. Putting it
lower down, beside the decoy count, is too late to bring a target back — the flag flips and nothing
reads it again. That version looked right, passed the plain run, and was pure dead code; a config
seeded to 50% empty still produced 982 blank rounds out of 2000. It only counts as a guard if it
holds with the config broken.

It skips staged rounds (`forced != null`) so the tutorial keeps full control of what it shows —
its empty-round lesson deliberately stages `real: false` with two decoys.

Because every level that can produce an empty round has decoys, the reward's anchor is always the
decoy centroid in practice; the playfield-center fallback is defensive only.

`_round_was_tapped` is set in `_on_draw_area_input` just after the `_round_active` check, so it
covers every tap through one line. It sits **below** the `tutorial_ignore_taps` guard, which is
what you want: a tap swallowed during a watch-only tutorial step never happened as far as the game
is concerned, and so does not cost the player the reward.

`_pops` holds `{pos, text, color, age}`; the level ages them and `draw_area.gd` draws them rising
`POP_RISE_PX` over `POP_LIFE_SEC` and fading on `1 - t²` so the number holds long enough to read
before it goes.

Two details that matter:

- They are aged **above** the `game.paused()` guard, like the tap flash, so a caption freezing the
  game does not leave a number stuck on screen.
- They are drawn **last**, over the targets, with a dark backing stroke. These land on the
  playfield — as often as not on top of a saturated circle — and a thin colored glyph on a
  saturated circle is unreadable.

---

## Tutorial

`whack/scripts/tutorial.gd`, registered in `MainCfg.tutorials`, level 1. Thirteen steps.

It exists because "avoid the decoys" does not tell a player what a decoy looks like, and one kind
is genuinely indistinguishable by color. The order is chosen by how much each mistake costs:

1. **A decoy can share the target's color.** `_spawn_round()` gives decoys
   `"draw_dot": not round_same_color`, while the real target is always `"draw_dot": true`. In a
   same-color round the white center dot is the *only* difference. Taught last of the decoy kinds,
   after color has been established, so the dot lands as the rule that always works.
2. **Not every round has a target.** `no_real_chance` is 0.1 at level 1 and 0.2 at level 2. Tapping
   a decoy costs 5 points and a mistake; waiting costs nothing.
3. **Differently-colored decoys** — the default blue, and the five-color palette — come first,
   because they are the easy case and set up the harder one.
4. **The dot is an aiming guide**, not decoration: accuracy is scored as distance from the center.

### The countdown ring

The ring is the thing nobody notices until it has cost them: a target that expires is scored
exactly like tapping the wrong thing (`_on_round_timeout()` takes the same -5 and mistake as
`_on_decoy_hit()`), and nothing on screen says so.

Teaching it needs the countdown **stopped part-way**, which is what `half_gone` is for. `_process()`
fires it once per round as the window passes its midpoint; the step that follows is a *talking*
step, so the game freezes with the ring visibly half closed and the coach can point at it. Measured
across runs, that step opens with the ring at exactly 50%.

The round is given `"show_ms": 7000.0` so the ring depletes at a readable pace rather than the
level's two seconds, and so half a window is still a comfortable amount of time to take the target
afterwards. `_round_window()` is what both the timeout and the drawn arc read, so an overridden
window cannot make the arc disagree with when the round actually ends.

### Two steps, not one, for anything that ends by itself

The empty-round lesson was first written as a single doing step: explain and wait for
`round_gone`. The caption disappeared the moment the round expired, which was before it could be
read. Anything the game ends on its own now gets a frozen step to explain it and a short doing step
to watch it happen. The same shape is used for the ring.

### Caption and circles arrive together

`tutorial_stage_now()` spawns the round inside the step's `setup`, which the runner calls *before*
the step opens. Queueing it instead left the circles to appear on the level's normal 700-1500 ms
gap, so the caption described things that were not on screen yet — and then jumped, because
`keep_clear` only had something to avoid once they arrived. Both faults were the same fault.

That also made the two `await round_shown` steps pointless: with the round already up the event
fires during setup, and the step would flash past unseen. They were folded into the steps that
follow, taking the tutorial from 16 steps to 15.

**`tutorial_stage_now()` replaces whatever is on screen** rather than queueing behind it, and
**`tutorial_only_staged` stops the level scheduling its own rounds.** Together they are what keep a
step talking about the round it is actually showing. `new_game()` queues one
immediately and so does every hit, and one of those could land in the gap between two steps: an
unstaged round, with no band, which then blocked the staged one because a round was already active.
The visible symptoms were worse than they first looked. At level 1 `num_decoys` is 0, so an
unstaged round has **no decoys and a fresh random position** — during the "decoys are not always
blue" step the decoys would vanish and the target reappear somewhere else, and the countdown step's
target would jump part way through. In the harness it had shown up only as an occasional caption
reposition, one run in four, which badly understated it: the harness was watching the caption, not
asking whether the round stayed put.

### Taps are ignored while the coach says "watch"

`level.tutorial_ignore_taps` swallows taps for the length of the "watch the ring" step, and the
next step's setup clears it.

The step also carries `"watch_only": true`, and deliberately **no `spot`**. A doing step normally
leaves the board undimmed and live, so it invited the very tap that breaks it. Dimming alone was
not enough: a spotlight punches a bright hole in the dim and frames it, which is how the app says
"act here". The round has a single circle on a dimmed board, so nothing needs pointing at — the
same treatment as the "SAME orange" step.

Measured mid-step against that step, which is the one it should resemble:

| | step 6 "SAME orange" | step 8 "watch the ring" |
|---|---|---|
| spotlight | none | none |
| holes punched in the dim | 0 | 0 |
| dim blocks input | yes | yes |
| a tap does anything | no | no |
| footer | "tap to continue" | "watch" |

The only remaining difference is that the board keeps running, which is the entire point of the
step.

The two guards cover different layers, deliberately. The dim stops a real finger reaching the
board; `tutorial_ignore_taps` stops anything that gets past it — and the flag is the one the
harness can exercise, since a probe calling `_on_draw_area_input()` directly never touches the
overlay.

This makes that step behave like every talking step, where the board already ignores taps because
`_on_draw_area_input()` returns early on `game.paused()` — measured: `tap_registers=false` on a
talking step with a target plainly on screen. The watch step is the only *doing* step that asks the
player not to act, which is why it is the only one needing the flag. Since a tap there now does
nothing, exactly as on a frozen step, the caption does not tell the player not to tap.

Without it the step is a dead end reachable by doing the one thing the tutorial has just spent four
steps training the player to do. Hitting that target ends the round, so the ring never reaches its
halfway mark and `half_gone` never arrives. Seeded and measured with a harness that taps on every
frame of every step: **60 s** stuck on that step (the runner's escape hatch firing), against 4.0 s
for the longest step with the guard in place — and that 4.0 s is the empty round's own window, not
an escape.

### A missed target is not a dead end

`level.tutorial_retry_spec` holds a round the coach wants back if it expires; `_on_round_timeout()`
re-stages it instead of scheduling a normal one.

The countdown lesson is the only `hit_target` step whose round can expire — every other one is
staged with `tutorial_no_timeout`, so it waits indefinitely. This one has to let the ring actually
run out, which means the player can miss it, and the step is waiting for a hit: a miss left nothing
to hit and nothing to satisfy the step. Re-staging turns the miss into part of the lesson, which is
the right answer anyway — the point of the step is that a target you let expire is gone.

The spec is armed by that step's setup and cleared by the next one, so the empty-round lesson,
which depends on a round expiring and staying gone, is not affected. Measured: armed on step 10,
clear on 11, 12 and 13, and clear after teardown along with `tutorial_ignore_taps` and
`tutorial_only_staged`. Waiting 11.7 s without tapping — well past the 7 s window — leaves
`round_active=true` with a target present.

### The tutorial must not finish the level

`_on_hit()` skips `_level_done()` while `game.tutorial_mode` is set. Level 1 needs 5 hits and the
coach asks for exactly 5, so the last lesson landed on the level-done popup — and that popup is a
visible screen, which means `game.paused()`, which means the empty round the coach was waiting on
could never reach its window. The step hung until its 30 s escape and the player saw two decoys
sitting there doing nothing.

Worth noting how it presented: nothing about the symptom pointed at hit counting. The runner's
own diagnostic is what named it, reporting `screens:level_done` on a step that had no business
being frozen.

### The tap ring

`_flash_at()` marks where a tap landed. Its fade runs **above** the `game.paused()` guard in
`_process()`: below it, a caption freezing the game froze the ring too, so it sat at full strength
into the next step. It is an acknowledgement of a tap that has already been scored and has no
reason to wait for the game. `FLASH_FADE_PER_SEC` is 12 (was 2.5, which lasted 400 ms), and
`_spawn_round()` clears it outright so it can never overlap a new round. Measured at 60 fps
including across the frozen step: at most 33 ms.

### How the rounds are staged

The game would only produce "a real target beside two same-colored decoys" by luck, so the coach
queues them: `level.tutorial_rounds` holds specs of the form
`{"real": bool, "decoys": int, "mode": "blue" | "multi" | "same"}`, consumed one per `_spawn_round()`
and inert when empty.

A spec may also carry `"band": [min, max]`, a fraction of the playable height, which
`_try_random_pos()` uses to confine that round's circles. Every staged round uses `[0.68, 1.0]`.

This is not cosmetic. With circles free to spawn anywhere they can span the whole field, and the
caption then has nowhere to go — measured, a decoy ended up 59% buried. Lowering the band helps
only gradually, because a caption at the top of the screen is tall enough to reach a long way down:
49% at `0.42`, 46% at `0.55`, and 13% worst-of-ten at `0.68`, with nothing ever crossing the 50%
at which `_follow_keep_clear()` would re-place the caption. The real target is never covered at all
— `SPOT_COST_WEIGHT` already pushes the caption off whatever is spotlighted; it is the decoys that
need the band. The closing step tells the player real targets use the whole screen.

`level.tutorial_no_timeout` holds a round on screen while the coach talks about it. It is switched
**off** for the last lesson, which can only be taught by letting an empty round expire —
`_on_round_timeout()` is what emits `round_gone`.

Both are cleared by `main.gd::_restore_tutorial_globals()`, which also runs from `_exit_tree()`, so
leaving mid-tutorial cannot leave staged rounds or a frozen timeout in a real session.

### Notifications

`round_shown`, `hit_target`, `hit_decoy`, `round_gone`, `half_gone` — all fired where the level
already knew something had happened, and all no-ops outside tutorial mode.

### Verified

The headless harness walks all 13 steps in order and confirms the teardown: rounds queued 0,
`tutorial_no_timeout` false, `tutorial_mode` false, `starting_level` restored.

It also measures, every frame: the caption against every circle, the ring as each step opens, and
**whether the round changes under a step** — the target moving or a decoy disappearing while one
caption is up. Across runs: 13 steps, 0 target jumps mid-step, 0 decoys vanishing mid-step, 0
caption repositions, no circle outside the staged band, the ring frozen at 50%, the caption
overlapping nothing, no doing step ever frozen, and the empty round expiring on its own 4000 ms
window rather than on the step's 30 s escape.

A second harness plays an impatient player, tapping the target on every frame of every step
whatever the coach asked for: all 13 steps still complete, longest step 4.0 s.
