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
- Phase label in `_phase_label` Label node (visible when `show_instructions` is on) — live guide-phase cue (`Inhale ▲` / `Hold ■` / `Exhale ▼`, filled glyphs matching the "Now:" indicator) driven by the cycle clock in guided modes; in active/free mode it shows the static hint `Set your breathing pattern`

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

The demo path is **vertical**, because the gesture is vertical. What is angled is the *hand*
(`_HAND_TILT_DEG` in `scripts/tutorial.gd`): drawn bolt upright, its body lies along a vertical
path and hides the line it is tracing, so it is tilted 45° to sit beside the line instead, with
the fingertip still landing on it. Every demo here also sets `demo_hand_only` — the traveling dot
means *something then follows this route*, and in crack nothing does. The opening step carries no spotlight — the safe fills the screen, so a
box around the dial says nothing and leaves the caption nowhere to sit that is not on top of it.

### Stale notes corrected

The Settings section above describes index 1 as `selected_preset`; it is `selected_mode`, where
0 = Active (free, no scoring), 1 = the player's own learned pattern, and 2+ index into
`GUIDED_PRESETS`. The statistics graph is crack's own, not `udbr/scripts/graph.gd` — nothing in
`crack/` references another game.
