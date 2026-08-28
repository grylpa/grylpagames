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

## Passing a level

Finishing a level's rounds is not the same as passing it. `Level._level_done()` measures the accuracy of
the level just played — `game.session_pct_correct()` over that level's own `corrects`/`mistakes` —
against a bar that rises with the level:

```
need = mini(60 + 5 * (level - 1), 80)
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

## The background

This game has no world in it — a shape flashes and you answer — so there is no ground to draw. What
sits behind the board is `scripts/study_backdrop.gd`, shared with Witness (`ddooo`), Lineup (`ooo`) and Glimpse (`pop`), the other three games
with nothing standing on anything. It used to show a lawn, for no reason at all.

```gdscript
StudyBackdrop.fit(self, get_node_or_null("TextureRect") as CanvasItem, game,
    StudyBackdrop.PINPOINT, 34)
```

`_fit_ground_to_board()` is called at the end of `_ready()` and from `_load_cfg()` (this game has no `create_board` — the board is a fixed 7x7 at every
level, so `_load_cfg` is the only place its size could change). `fit()` hides the tiled
`TextureRect` it replaces, attaches a control as the Level layer's first child so it draws behind
the board, sizes it to the board plus a four-tile margin merged with the full canvas, and populates
it — rebuilding only when that rect actually changed.

**It is deliberately featureless, and that is a gameplay constraint, not a shortcut.** This game asks which of EIGHT directions a dot flashed in. If the background were brighter in
some directions than others, the dot would be easier to catch in some directions than others, and
the game would no longer be measuring what it claims to. That is why the only variation is radially
symmetric: identical whichever way the dot went.
So there is no vignette, no gradient with a direction to it, no pattern and no motion. The surface
is a deep base (`StudyBackdrop.PINPOINT`, a low-chroma slate blue), a radially symmetric lift toward
the centre at 5% alpha, and a fine untiled dust of specks in two tones at 4-9% alpha — enough that
the screen reads as a matte surface rather than as a missing asset, and far too little to compete
with a coloured shape.

`probe_lawn.gd` checks this game with the other three: backdrop present and first in its layer,
populated before any board is built, covering board and canvas, the tiled ground retired only once
it has something in it, and the centre lift both small and direction-free.
