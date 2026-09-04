# Crack the Safe — Design Document

## Overview

A breathing game where the player cracks a combination safe by performing the correct gesture sequence in rhythm. Swipe up (inhale), hold, swipe down (exhale), hold — timed to a guided breathing preset. Each successful full cycle unlocks the safe and increments the score.

## File Structure

```
crack/
├── docs/design.md
├── scenes/
│   ├── main.tscn      — Node root with Level child
│   └── level.tscn     — CanvasLayer with CrackCanvas + overlays
└── scripts/
    ├── globals.gd      — CrackG autoload; presets, settings, GenericGameUtil
    ├── main.gd         — orchestrator; main menu wiring
    ├── level.gd        — game logic + _do_draw()
    └── crack_canvas.gd — thin Control whose _draw() calls level._do_draw(self)
```

## Gameplay

- **Player action**: Swipe up (inhale) → hold → swipe down (exhale) → hold.
- **Scoring**: each full 4-step sequence within the timing threshold = +1 unlock. Safe toggles open/closed with a green flash.
- **Session ends** when the timer expires; a results panel shows statistics.

## Gesture State Machine

`_gesture`: 1=swipe_up, -1=swipe_down, 0=holding  
`_last_swipe_dir`: 1 or -1 (direction of most recent swipe)

`_seq_state` tracks a 4-step sequence:
- `-1`: waiting for swipe_up
- `0`: got swipe_up, waiting for hold_after_up
- `1`: got hold_after_up, waiting for swipe_down
- `2`: got swipe_down, waiting for hold_after_down → calls `_try_score()`

`_gesture_timer_ms` is reset on every gesture change (delta accumulation, not wall clock).

## Scoring / Timing Check (`_try_score`)

```
d = CrackG.get_guided_durations()  → [swipe_up_ms, hold_top_ms, swipe_down_ms, hold_bot_ms]
if all 4 seq_durations within TIMING_THRESHOLD_MS of targets → score +1, toggle _safe_open
```

`TIMING_THRESHOLD_MS` is defined in `globals.gd`.

## Dial Animation

The combination dial arms rotate freely based on gesture:
- Swipe up → `_long_angle += LONG_SPEED * delta` (45°/s)
- Swipe down → `_long_angle -= LONG_SPEED * delta`
- Hold after up → `_short_angle += SHORT_SPEED * delta`
- Hold after down → `_short_angle -= SHORT_SPEED * delta`

Arms are visual only — timing is judged purely by gesture durations.

## Controls

| Input | Desktop | Mobile |
|-------|---------|--------|
| Swipe up (inhale) | Hold ↑ | Drag up |
| Swipe down (exhale) | Hold ↓ | Drag down |
| Hold | Release | Release |

## Settings

Index 0: `duration_min` (1–20)  
Index 1: `selected_preset` (index into GUIDED_PRESETS)

## Presets (same as udbr/river)

| Label | Values |
|-------|--------|
| 4-1-4-1 | standard relaxing |
| 6-1-6-1 | slow deep |
| 4-4-4-4 | box breathing |
| 2-1-2-1 | faster |

## Visual (procedural _do_draw)

**Closed state**: gunmetal door rectangle, corner bolts, side handle, combination dial with 36 tick marks, inner disc, long/short needle arms, score at bottom.

**Open state**: dark interior cavity, glowing green border, 4 gold bars centered in door, score at bottom.

**HUD overlay** (drawn on door at all times):
- Recent gesture durations (last 4, in seconds)
- Live current gesture duration + direction indicator: `"Now: Xs <dir>"`, where `<dir>` is the player's *current* gesture, drawn as filled glyphs — `▲` inhaling (up), `▼` exhaling (down), `■` holding. Filled shapes (not the word "hold" or thin arrows) so they read as a live state and stay uniform in weight/size.
- Goal durations line (from preset)
- **Removed:** there used to be a phase label at the top (`Inhale ▲` / `Hold ■` / `Exhale ▼`) with a menu setting to show or hide it. It was driven by `_elapsed_ms` — a free-running cycle clock that knows nothing about what the player is actually doing — so it drifted out of step with them and there was no way to tell which beat the game thought you were on. The label, `_current_phase_label()`, the `PhaseLabel` node and the `show_instructions` setting are all gone. `show_instructions` was the last slot of the settings array, so older saves still load.

**Flash**: green overlay + "OPEN!" or "LOCKED!" text for 0.8s on each score event.

## Statistics Screen

At session end, `_on_session_complete()` shows:
- Session duration + unlock count
- Average swipe-up / hold-top / swipe-down / hold-bot durations vs targets
- Graph: gesture state over time (y_norm: swipe_up=0.05, hold_top=0.25, neutral=0.5, hold_bot=0.75, swipe_down=0.95), sampled every 200ms, rendered via `udbr/scripts/graph.gd`.

---

## Tutorial

`crack/scripts/tutorial.gd`, registered in `MainCfg.tutorials`. Thirteen steps, four of them doing
steps.

### What it exists to fix

**Players flick.** Everywhere else in this app — and on every phone — a swipe is a fast flick.
Here it is the opposite: the finger keeps sliding for as long as the inhale lasts, four whole
seconds, because the *duration* of the slide is the measurement. A player who flicks sees a game
that does not respond at all. Two steps are spent on this, one of them a `demo_path` that traces a
slow drag up the screen, because no rewording of "swipe" survives contact with what players already
believe a swipe is.

Then, in order: that a hold is a *beat* rather than a gap between beats; that the four moves are a
sequence which `_reset_seq()` silently restarts when broken; and that `_try_score` needs **all
four** durations inside `TIMING_THRESHOLD_MS`, so three out of four scores nothing.

### A hold completes when the NEXT move starts

`_on_action_completed` is reached only from `_on_gesture_changed`, so an action is recorded when the
gesture *changes*. The bottom hold is therefore not completed when the player lifts their finger —
it is completed when they **begin the next inhale**, which is also the instant `_try_score` judges
the sequence.

Two steps were originally written as "lift off and hold", awaiting `held_top` / `held_bottom`. Each
would have stalled after the player did exactly what it asked, waiting on a move no caption had
mentioned yet. Both now name the move that ends the hold ("lift off … then breathe out", "lift off,
hold, then begin your next breath in"), and the sequence-completion rule is taught explicitly
instead of being a trap. This is recorded in `docs/tutorials.md` as a general rule.

### It forces a guided preset

`start_tutorial()` stashes `CrackG.selected_mode` and sets **2** (the first `GUIDED_PRESETS` entry,
4-1-4-1). The shipped default is `selected_mode = 0` ("Active"), in which `_try_score()` returns
immediately — the safe can **never** open, so the tutorial's payoff step would wait forever on an
`unlocked` the game is incapable of sending. Assign `selected_mode`, never `guided_mode`: the
latter is a getter-only computed property and assigning to it does nothing (the same trap udbr
documents).

`duration_min` is likewise stashed and set to 20 — the default session is 1 minute and the tutorial
asks for two full breathing cycles at four seconds a phase. Both are restored from
`_on_tutorial_done` **and** `_exit_tree`; verified by probe, including the abandon path.

### Hooks and spots

`_on_action_completed` emits `inhaled` / `exhaled` / `held_top` / `held_bottom`, placed **after**
the 80 ms flicker guard so a twitch the game ignored can never advance a step. `_try_score` emits
`unlocked` or `sequence_missed`.

The safe is drawn procedurally, so there are no nodes to hand the overlay: `tutorial_hud_rect()`,
`tutorial_score_rect()` and `tutorial_demo_up()` / `tutorial_demo_down()` recompute the same
geometry `_do_draw()` uses.

### The pattern is acted out before it is asked for

The coach plays the whole combination as **one continuous animation**, repeated three times, before
asking the player to do any of it. A finger slides up the line for the full inhale, comes off at
the top for the hold, slides back down for the exhale, comes off at the bottom — and then, as it
begins the next breath in, the safe swings open.

It is deliberately **not** one beat per tap. A breathing pattern is a rhythm, and a rhythm chopped
into five tap-gated stills is not a rhythm any more: the timing, which is the only thing being
taught, is exactly what gets lost. The step waits for nothing and requires nothing — it plays its
three cycles and ends itself via `advance_when`, though a tap still skips it.

The caption is a **live Callable** (`tutorial_demo_caption()`) that follows the animation, naming
each beat as it happens and carrying a "2 of 3" counter, so picture and words stay together without
the player doing anything. `_refresh_live_text()` re-lays the panel out only when the string
actually changes.

**The finger never jumps.** Every beat begins exactly where the last one ended, because that is
what the gesture is: up, off, down, off, up again. The first build had a separate "next breath in"
beat that slid halfway up and then rewound to the bottom for the next repetition — a 236 px snap,
measured. The fix was to stop treating it as its own beat: the next breath in **is** the following
cycle's inhale, and the safe opening at its first instant is the whole point being made. The lock opens **once**, on the final inhale, and stays open. An earlier version opened it at the
start of the second and third inhales too, shutting it again a second and a half later — a brief
and quite different screen partway through an upward slide, which read as a glitch rather than a
payoff. Measured across the whole animation: largest single-frame move 1.97 px (exactly the slide's
own speed), safe opens once, never shuts mid-demo.

The line spans 16%–76% of the board height. It was a third of that while the caption was still
docked at the bottom, and a finger that only crosses a third of the height does not look like a
four-second breath; the side caption is what bought the room back.

Three things this needed:

- **`demo_hand`** — a new step key: a `Callable(elapsed_sec)` returning `{"pos", "down", "path"}`,
  giving the step control of the finger every frame. `demo_path` animates a fixed route on the
  runner's own clock and cannot hold a pause of a specific length against durations the game
  defines.
- **`down: false`** draws the hand backed away from the line (`_HAND_LIFT_PX` 48), **larger**
  (`_HAND_LIFT_SCALE` 1.22) and faded, with a hollow ring left where it lifted off. A hold is the
  one beat with nothing to see. Distance alone reads as the finger having slid sideways; growing
  it is what sells "raised toward you" on a flat board.
- **`caption_side: "left"`** — a narrow column, as aliens and udbr use, with the line placed just
  beside it (38% of width, ~29 px clear of the text). A full-width panel docked at the bottom sits
  on the animation; a column on the *far* side of the screen is no better, because the step needs
  the player to read and watch at the same time and they cannot do both 180 px apart. The hand is
  tilted so its body falls down-and-right, away from the words. Measured over a full watched run:
  0 frames where the panel touched the animation.

The animation was invisible at first for a reason worth remembering: the overlay only repainted
when it had a spotlight or a `demo_path`, and a `demo_hand` step has neither — so the hand was
recomputed every frame and drawn on none of them. `_has_demo_hand()` is now part of that condition.

Beat 4 drives `_safe_open` directly, and `tutorial_demo_end()` puts it back — the level is frozen
while the coach talks, so nothing else would. It cannot leak into real play either: `new_game()`
resets `_safe_open`.

### The demo drives the real safe

The level is frozen while the coach talks, so nothing on the board moves on its own — and a
demonstration of a gesture on a board that does not react to it teaches the gesture as decoration.
`tutorial_demo_sequence()` therefore drives the actual state, exactly as `_process` would:

| driven | so that |
|---|---|
| `_long_angle` / `_short_angle` | the dial arms turn under the slides and holds, as they do for a real swipe |
| `_gesture`, `_gesture_timer_ms` | the live "Now: 2.1 s ▲" readout counts along with the demo |
| `_display_durations` | the row of completed beats fills in, so the caption pointing at it has something to point at |
| `_safe_open` | the lock **toggles** on each completed sequence, as `_try_score` does |

Three sequences therefore read **open, closed, open** (measured at 10 s, 20 s, 30 s) — not one
opening at the end. Everything is computed from `elapsed` alone and never accumulated, so calling
it on any set of frames lands on the same state.

`tutorial_demo_end()` shuts the lock but deliberately **keeps** the duration row and the dial: the
next two captions point at that row and call it "what the demo just did". `tutorial_demo_clear()`
wipes it, and runs when the player's own turn begins.

**The demo breathes slightly imperfectly** — `_DEMO_OFFSETS` makes it 4.1 - 1.2 - 3.9 - 0.9 against
a 4 - 1 - 4 - 1 target. A row of perfect numbers would teach that the preset has to be hit dead on,
which is not the rule: anything inside `TIMING_THRESHOLD_MS` counts. Being visibly a little off and
opening anyway is the clearest way to say so, and it leaves a realistic example on the HUD for the
next caption to point at.

**Every caption lasts a whole beat.** The "and THAT is when the lock reads all four" line used to
run for the first two seconds of an inhale and then swap — on screen too briefly to read, and it is
the one sentence in the demo that explains what just happened to the safe. Captions now change only
at beat boundaries; measured shortest time on screen is 0.9 s, which is the bottom hold itself.

**The end is held.** `_DEMO_TAIL_SEC` (2.6 s) keeps the finished picture — safe open, the row of
what it did — before `advance_when` moves on. Without it the flag went true on the same frame the
animation ended and the closing caption was never seen at all.

**The combination step spotlights the goal line alone** (`tutorial_goal_rect()`, 33 px tall) rather
than the whole three-line HUD block (89 px). Before the demo has run, two of those three rows are
empty, so framing all of it to say "here is the combination" points mostly at blank space.

### Coming off the glass is animated

`lift` is a float, 0 (flat) to 1 (fully raised), not a flag. Snapping between the two made a hold
look like a teleport rather than a movement to copy. It ramps over `_DEMO_LIFT_SEC` (0.18 s) at the
start of a hold and back down before the next slide; the runner interpolates offset, scale and
alpha from it. Slides are always flat — the holds either side own the whole lift, and ramping again
on the slide drove it to 1 on the slide's first frame, which was the snap this was meant to remove.

### It ends on the summary screen, not on a practice run

The tutorial has **no doing steps at all**. After the animation it says what a whole round is, then
produces the real results screen with an invented session behind it.

The practice half is gone because it could not work. `_try_score` judges four durations *in a row*;
a coach that freezes the board between beats destroys the rhythm it is asking for, so the player
was being drilled on beats they could never join up. Asking instead for the whole pattern in one go
just moved the problem: a player whose timing is not good enough would sit in a step waiting on an
`unlocked` they might never produce. Neither version taught anything the animation had not already
shown.

`tutorial_show_summary()` synthesises a run: the preset breathed with a human amount of drift
(`randfn`, plus a 12% chance of a beat wandering far enough to miss), for three minutes, seeded so
the same picture appears every time. It fills `_key_poll` — the record the phase averages and the
graph are both computed from — so the screen the player sees is the real one, assembled by the real
code. A typical result reads *"Session: 3:00   Unlocks: 14   Score: 96/100"*.

It writes nothing: `game.tutorial_mode` guards every save in `generic_game_util.gd`, and main.gd's
`learned_*` write sits behind `not guided_mode`, which the tutorial has forced off. Verified by
byte-comparing every `user://` crack file across a full run.

`runner.never_dim` carries `tutorial_results_rect()`, which returns **null while the panel is
hidden** — a rect for a hidden panel would punch a bright hole in every earlier step. Without it
the summary would sit under the dim, unreadable.

### The lock announces itself

The safe changing state is the payoff of the four beats just performed, and it happens on the
board, which is under the dim while the coach talks. `demo_hand` therefore also returns a `badge`,
drawn by the overlay opposite the caption: **"Safe opened!"** / **"Safe closed!"**, held 1.8 s and
fading out.

It is keyed to the time since the *toggle*, not to time-into-the-current-beat. Keyed to the latter
it popped up again at the start of every beat — seven badges instead of three.

It is placed as near the center of the screen as it can get **without touching the gesture**: the
demo's own path is passed to the overlay as the obstacle, and the box starts just clear of it plus
the room the hand needs when it lifts (measured: x=340 against a line at x=258, versus x=517 when
it was simply pinned to the right edge), vertically centered.

There is **no tail** after the last beat. `_DEMO_TAIL_SEC` was 2.6 s, added so the animation's own
closing caption could be read — but the step that follows carries that message, so all it did was
hold a motionless picture between the animation ending and the next words appearing, which reads as
a freeze. The step that follows also no longer calls `tutorial_demo_end()`: the demo's last frame
stands, safe open and the row of what it did still on the HUD, instead of the payoff being thrown
away the instant it was earned.


---

## Default mode

`selected_mode` ships as `DEFAULT_MODE` (2) — **4-2-4-2**, not Active. Active records
whatever the player does but paces them through nothing, which is the wrong thing to hand
someone who has just arrived: with no pattern to follow there is nothing to do and nothing to
score. Only the shipped default changed; `load_settings()` still overrides it with whatever a
returning player last chose.

The preset list is shared by crack, udbr and mother:

| # | pattern | |
|---|---|---|
| 0 | 4-2-4-2 | the default |
| 1 | 4-7-8-1 | the 4-7-8 relaxation pattern |
| 2 | 4-4-4-4 | box breathing |
| 3 | 5-0-5-0 | no holds |
| 4 | 4-4-8-0 | long exhale |
| 5 | 4-0-8-0 | long exhale, no holds |
| 6 | 4-2-4-0 | |

Menu rows are the bare numbers — `Active`, then `4-2-4-2`, `4-7-8-1`, … The word "Guided" on all
seven said nothing the numbers did not, and ate the width the mono fit-shrinking then had to claw
back. `main_menu.gd` draws the list in the project mono face so the columns line up; that used to
require *every* row to start with a digit, which `Active` vetoed, and now takes a majority.

---

## Zero-length holds

Four of the presets have a `0` in a hold slot (`5-0-5-0`, `4-0-8-0`, `4-4-8-0`, `4-2-4-0`). None of
them could ever open the safe, for a reason that is not about the timing check at all: **the hold
was never recorded**, so there was nothing to compare against the target.

Two separate causes, both measured:

- **An instant reversal generates no hold.** `_process` polls up, then down, then neutral. A finger
  that turns straight around inside one frame goes `1 -> -1` without passing through `0`, so
  `_on_gesture_changed` never produces a hold action. `_seq_state` then sits at 0 waiting for a
  beat that cannot arrive, and the next swipe resets it.
- **A brief pause was thrown away.** `_on_action_completed` discarded anything under 80 ms as a
  flicker. A one-frame turnaround is 16 ms.

Fixes, in that order: a direct reversal now synthesises a zero-duration hold, and the 80 ms flicker
guard applies to **slides only**. The guard exists because the digitized-swipe flag can drop for a
frame mid-gesture — that is a slide problem. A hold is a beat of the pattern, and if it was short
the timing check is what should say so.

**Raising the target from 0 to 0.2 s internally would not have helped.** The hold never reached the
timing check, so its target was irrelevant; measured, both failure paths recorded `top=0 bottom=0`
holds. After the fix both score 3 of 3.

Verified across all seven presets: breathed correctly each scores every cycle, and mistimed by
2.5 s per beat each scores nothing — so nothing was loosened to buy this.

---

## Session progress bar

The top edge carries the same thin progress bar udbr and breathe use — same geometry
(`BAR_PAD_X` 24, `BAR_Y` 18, 7 px on mobile / 5 on desktop), same cyan, drawn first in `_do_draw()`
so everything else sits over it.

It replaced a digital `m:ss` countdown. A number counting down is something to read and do
arithmetic on, which is the opposite of what a breathing game wants the player doing; a bar is
glanceable and needs no attention at all. The `TimerLabel` node is removed from the scene, not just
hidden — a node left behind with nothing setting its visibility simply shows.

The bar itself lives in **`scripts/session_bar.gd`** (`SessionBar`), shared by udbr, breathe, crack
and mother. Geometry and the alpha policy are shared; **colors are the caller's**, because they are
not a detail — the cyan the three cool-background games use reads as a foreign object on mother's
dunes. `SessionBar.draw_cool()` is the cyan default; mother calls `SessionBar.draw()` with
`MOTHER_COL` and an alpha lift for its lighter background.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

**Crack previously saved nothing at all.** It called only `convert_ongoing_score_to_permanent()`, which is a no-op without an ongoing record, and nothing here ever wrote one. It now has `get_session_score()` and a real save. Each completed cycle records the signed error of all four phases, so rushing reads differently from dragging.
