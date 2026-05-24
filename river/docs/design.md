# River — Design Document

## Overview

A tranquil side-scrolling breathing guide. The river banks scroll right-to-left, shaped to guide the player's character up/down in sync with a selected breathing pattern. No score, no punishment — pure calm.

## File Structure

```
river/
├── docs/design.md
├── scenes/
│   ├── main.tscn      — root Node with Level child
│   └── level.tscn     — CanvasLayer with RiverCanvas + overlays
└── scripts/
    ├── globals.gd      — RiverG autoload; presets, settings, GenericGameUtil
    ├── main.gd         — orchestrator; main menu wiring, show_level/show_main_menu
    ├── level.gd        — game logic + _do_draw()
    └── river_canvas.gd — thin Control whose _draw() calls level._do_draw(self)
```

## Gameplay

- **Character** stays at a fixed x position (25% from left). Player moves it up/down with arrow keys (desktop) or drag (mobile).
- **River banks** scroll left at a speed computed so 1.2 cycles are visible ahead of the character.
- **Channel** (space between banks) moves up during inhale, holds at top, moves down during exhale, holds at bottom — driven by the selected guided preset.
- **Walking**: if the character touches a bank it is clamped there and changes color (gold → brown) until the channel returns.
- **Session ends** when the timer expires; a "Session Complete" overlay appears with a Done button.

## River Rendering (_do_draw)

Called each frame from `RiverCanvas._draw()`. Uses `CanvasItem.draw_polygon` and `draw_polyline`.

At each x pixel:
```
t_ms = elapsed_ms + (x - char_x) / scroll_px_per_ms
channel_center_y = top_y + channel_y_norm_at(t_ms) * (bot_y - top_y)
upper_bank_y = channel_center_y - CHANNEL_HALF
lower_bank_y = channel_center_y + CHANNEL_HALF
```

Upper land polygon: `[TL, ...upper_bank_pts..., TR]` (fills from screen top down to bank).
Lower land polygon: `[BL, ...lower_bank_pts..., BR]` (fills from screen bottom up to bank).

## Channel Shape Formula (WAVE_BIAS = 0.0)

The channel slides as a unit — both banks maintain constant CHANNEL_HALF distance from the character's target y. Banks move exactly during inhale/exhale phases, flat during holds:

```
upper_bank_y(t):
  t = t mod cycle_ms
  if t < inhale_ms:  return lerp(bot_pos, top_pos, t/inhale_ms)
  t -= inhale_ms
  if t < hold_top:   return top_pos
  t -= hold_top
  if t < exhale_ms:  return lerp(top_pos, bot_pos, t/exhale_ms)
  return bot_pos  # hold_bot flat
```

`top_pos = _top_y - CHANNEL_HALF`, `bot_pos = _bot_y - CHANNEL_HALF`.
Lower bank uses same formula with `top_pos = _top_y + CHANNEL_HALF`, `bot_pos = _bot_y + CHANNEL_HALF`.

WAVE_BIAS=0 is critical: any other value shifts bank transitions across phase boundaries, breaking the match between bank slope and keyboard adaptive speed.

## Head Rotation

Character head sprite rotates to match movement direction: `rotation = atan2(_char_vel_y, scroll_px_per_ms * 1000.0)`. Velocity is smoothed with `lerpf(..., delta * 8.0)` to avoid jitter.

## Scroll Speed

Computed at session start so 1.2 cycles are visible in the future portion of the screen:
```
scroll_px_per_ms = (screen_width - char_x) / (1.2 * cycle_ms)
```

## Presets (GUIDED_PRESETS in globals.gd)

Each row: `[inhale_s, hold_top_s, exhale_s, hold_bottom_s]`

| Label | Values |
|-------|--------|
| 4-1-4-1 | standard relaxing |
| 6-1-6-1 | slow deep |
| 4-4-4-4 | box breathing |
| 2-1-2-1 | faster |

## Settings (saved in save_settings)

Index 0: `duration_min` (1–30)
Index 1: `selected_preset` (index into GUIDED_PRESETS)

## Character

Head + body sprites from `wolves/art/player_head{1-3}.png` and `wolves/art/player_body{1-3}.png`, both at `CHAR_SCALE = 1.6`. Body is centered slightly below `_char_y`, head slightly above. When walking on a bank the body cycles through all 3 frames at 6fps. In the river the body is static (frame 0) and the head blinks slowly via a 4-frame cycle.

## Visual Effects

- **Dynamic channel width**: `_channel_half_at(t_ms)` interpolates between `CHANNEL_HOLD=62` and `CHANNEL_MOVE=95` based on the instantaneous normalized transition speed (`cos` of ease phase angle). Widest at the midpoint of inhale/exhale, narrowest during holds.
- **River ripples**: 28 procedural seeds (fixed RNG, seed=7331) with world-space x positions; scroll by subtracting `elapsed_ms * scroll_px_per_ms`. Only drawn if within channel bounds.
- **Bank tufts**: 40 seeds alternating upper/lower banks; two overlapping circles per tuft give a bush/grass look.
- **Depth strips**: A darker inner polygon strip (`land_dark`) hugs each bank edge, giving visual depth to the land.
- **Background**: Sky gradient (blue-grey top half) bleeds in behind the land polygons before they are drawn.

## Key Constants (level.gd)

| Constant | Value | Meaning |
|----------|-------|---------|
| CHAR_X_FRAC | 0.25 | Character x as fraction of screen width |
| CHANNEL_HALF | 58.0 | Half-height of the river channel in px |
| TOP_Y_FRAC | 0.15 | Top of channel travel range |
| BOT_Y_FRAC | 0.85 | Bottom of channel travel range |
| _char_speed | 320 px/s | Player character movement speed |
