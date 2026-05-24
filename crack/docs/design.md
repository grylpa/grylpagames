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
- Live current gesture duration + direction indicator
- Goal durations line (from preset)
- Phase label in `_phase_label` Label node

**Flash**: green overlay + "OPEN!" or "LOCKED!" text for 0.8s on each score event.

## Statistics Screen

At session end, `_on_session_complete()` shows:
- Session duration + unlock count
- Average swipe-up / hold-top / swipe-down / hold-bot durations vs targets
- Graph: gesture state over time (y_norm: swipe_up=0.05, hold_top=0.25, neutral=0.5, hold_bot=0.75, swipe_down=0.95), sampled every 200ms, rendered via `udbr/scripts/graph.gd`.
