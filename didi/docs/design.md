# DIDI — design

Two things flash in quick succession and you need both of them. A **shape** appears at the center
for `center_ms`, and 150 ms later a **dot** flashes off to one side for `periph_ms`. Both vanish.
Then eight clusters of shapes appear, one per compass direction, and you must tap the shape that
matches the center one **in the direction the dot flashed**.

The trap is deliberate: several other directions also contain the correct shape
(`num_same`), and the dot's own shape and colour are random. So remembering only the shape puts you
in the wrong place, and remembering only the place leaves you picking between shapes.

## Files

```
didi/scripts/
├── globals.gd        DidiG autoload: starting_level, save/load settings
├── level_config.gd   DidiLevelConfig.LEVELS — 8 levels, all the timing lives here
├── main.gd           orchestrator: menu, HUD, instructions
├── level.gd          the round machine: model, peripheral flash, answer clusters, scoring
├── agent.gd          one shape: texture, one or two colours, self-hides after time_to_hide_ms
```

## A round

1. `_spawn_model()` — a random shape at board (3,3), shown for `center_ms`, its texture index and
   colours kept in `_round_model_texture_idx` / `_round_model_color`. Schedules the flash 150 ms out.
2. `_spawn_periph_flash()` — picks `_periph_dir_idx` (0-7), places a small agent 80-100% of the way
   towards that edge, with a **random** texture and colour: it carries position only.
3. When both have hidden, `_dispatch_answer_stage()` builds eight clusters of `num_options` shapes.
   `num_same` clusters contain the model's shape — always including the flash direction. Exactly one
   agent has `is_correct` (right shape AND right direction).
4. `_on_answer_agent_pressed()` scores: full marks for `is_correct`; +1 partial for right direction
   with the wrong shape, or the right shape in the wrong direction; a miss otherwise.
   `_time_to_consider_fail_ms` auto-fails the round if nothing is tapped.

Levels tighten everything at once: `center_ms` 700→200, `periph_ms` 200→50, `num_options` 2→4,
`num_same` 3→4, and two-coloured shapes arrive at level 5.

## Timing and pause

Both the level's scheduler and `agent.gd` measure against `game.game_time`, which excludes paused
time. So while anything pauses the game — including a tutorial caption — a flash that is on screen
STAYS on screen, and the round clock does not advance. That is what makes this game teachable at
all: the coach can freeze the moment the shape appears and talk about something the player can
still see.

## Tutorial

`didi/scripts/tutorial.gd`, entry `didi/scripts/main.gd::start_tutorial()`.

You cannot learn this by watching, because by the time you know to look, both cues are gone. So the
tutorial freezes ON each cue in turn — the shape while it is still lit, then the dot while it is
still lit — and only then lets the answer stage arrive. The decoys are named explicitly, because
"the same shape appears in other directions too" is the rule that makes the game hard and the one a
player is least likely to work out before losing several rounds to it.

Specific to this game:

- **The round is held at the gate** (`tutorial_hold_round`) until the player dismisses the "watch
  the center" caption. The shape spawns half a second into a round, so waiting on `model_shown`
  alone meant that caption flashed past before it could be read, let alone acted on. Held, the
  round starts on their tap and the flash is the next thing they see.
- **The level popup is skipped** in tutorial mode (`create_board` calls `_on_game_popup_closed()`
  directly): a panel of level timings in front of the coach is the first thing a player would have
  to dismiss.
- **The final step ignores every tap but the right one** (`tutorial_only_correct_taps`): no score,
  no partial credit, no round ending. It also FRAMES the correct shape, because that step is a
  demonstration of what "right shape, right direction" looks like rather than a test — the closing
  step then says that in play nothing is framed and near misses do score.
- `_time_to_consider_fail_ms` is pushed out of reach for the tutorial and restored afterwards: a
  6 s answer clock is fine for play and absurd for someone reading a caption.
- Events reported to the coach: `model_shown`, `periph_shown`, `answer_ready`, `answered_right` —
  all `game.tutorial_notify`, no-ops outside tutorial mode.
