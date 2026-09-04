# Friends — Game Design & Implementation Document

## Overview

A recognition-memory game. The player is shown a small group of **friends** — face cards, each
with a first name under it — and told to memorize them. The group then disappears and strangers
start arriving one at a time. For each arrival the player answers one question: *is this one of my
friends?* — **Say Hi** if yes, **Ignore** if no.

The pressure is the arrival itself. A newly shown person starts tiny and grows to full size over
`dtime_to_ignore_when_no_answer_ms` (4 s); when it reaches full size, an unanswered person counts as
"Ignore" automatically. Answering early is worth more points than answering late.

Faces and card backs come from the shared `res://art/people/` and `res://art/cards/` sets, the same
pool dino and couples draw on.

## File Structure

```
friends/
├── art/
│   ├── game_screen_200.png     chooser thumbnail
│   ├── grass.png               level background
│   └── zig1.png
├── docs/design.md              this file
├── scenes/
│   ├── main.tscn               Main (Node) — Level, HUD, GameTick, Help
│   └── level.tscn              Level (CanvasLayer) — board, buttons, captions
└── scripts/
    ├── globals.gd              autoloaded as FriendsG
    ├── level_config.gd         FriendsLevelConfig — LEVELS
    ├── level.gd                the game
    └── main.gd                 orchestrator: menu, HUD, scores, save
```

The cards themselves are the SHARED card: `res://shared/scripts/card.gd`, preloaded as
`CARD_SCRIPT`. It is pixel-sized (`set_width()`, `scale` 1.0 = full size), which is why the growth
animation sets `new_person_card.scale` directly.

## Scene Structure

`level.tscn` (CanvasLayer):

| Node | Role |
|------|------|
| `TextureRect` | grass background |
| `ReadyButton` | "I have memorized them" — ends the study phase early |
| `HBoxContainer` | the two answer buttons: `SayHiButton`, `IgnoreButton` |
| `Instructions` | the line above the board; changes with the mode |
| `CorrectText` / `WrongText` | the reaction caption ("Ann also says Hi" / "Ann looks puzzled") |

The friend cards and the arriving person's card are created in code and added to the Level, not
placed in the scene.

## Globals (`FriendsG`)

`GenericGameUtil.new("Friends", "friends", 0, 5, 0)` — a 5-minute session clock.

- `_people_file_names` — the 49 faces used, by filename in `res://art/people/`.
  `load_people()` loads each texture once and derives the display name from the filename
  (underscores → spaces, capitalized). `first_name()` / `last_name()` split it.
- `_people_idx` is a shuffled index. `get_person_image(idx)` / `get_person_name(idx)` go through it,
  so a card id is stable within a game but maps to a different face after `shuffle_people()`.
- `board_to_px()` / `px_to_board()` place cards on a `p_scale`-sized grid measured from `board_top`,
  which `_ready()` sets to just under the Instructions label.
- Settings array: `[starting_level]`.

## Gameplay Flow

Two modes, `modes.DISPLAY_ALL_FRIENDS` and `modes.DISPLAY_SOMEONE`.

1. **Study.** `create_board()` lays the friends out in up to two rows (`num_friends` is per row),
   each card showing its face and first name, with the Ready button under them. The phase ends when
   the player presses Ready or after `dtime_to_show_all_friends_ms` (60 s).
2. **Recognition.** The friend cards hide, the answer buttons appear, and `display_new_person()`
   shows one person — sometimes a friend, sometimes a stranger — at `scale` 0, growing to 1.
   `get_rand_person_id()` draws from `max_id_used * 2` ids, so roughly half the arrivals are friends.
3. The player presses **Say Hi** or **Ignore**, presses the right or left arrow key, or swipes
   right or left; not answering counts as Ignore once the card is full size. The caption names the
   person and says what they did, then the next person arrives after 2 s.
4. After `num_corrects_for_next_level` correct answers the level ends (`level_is_done(true)`).

Card sizing is measured, not assumed: `create_board()` instantiates one throwaway card, sets its
width, waits a frame and reads `scaled_size()` — once with a label and once without — so the row
geometry and the double-size arrival card both follow whatever the shared card actually renders at.

## Difficulty Scaling

`increase_difficulty()` matches on `level` (1..`max_difficulty` = 6):

| level | friends (per row) | corrects to advance |
|-------|-------------------|---------------------|
| 1 | 2 | 5 |
| 2 | 3 | 10 |
| 3 | 4 | 5 |
| 4 | 3 + 2 | 20 |
| 5 | 3 + 3 | 20 |
| 6 | 4 + 3 | 20 |

**Known gap:** `FriendsLevelConfig.LEVELS` states the same `rounds` numbers and is read only for the
menu's level slider range — the values that actually drive the game are the hardcoded `match` above.
The two can drift. Moving the per-level attributes into `level_config.gd` is the same cleanup
deliverem and delemfp need.

## Scoring

`initial_score = 100`, `game_over_on_zero_score = true` — the score can be played down to zero, and
that ends the session.

| event | score | time |
|-------|-------|------|
| correct | `max(1, 10 - ms_since_shown / 200)` | +15 s |
| wrong | −1 | −5 s |

So a correct answer within 200 ms is worth the full 10 and the value decays to 1 by 1.8 s. Answer
times feed `times_to_answer` (a rolling window of the last 10), whose mean goes on the level card and
into the score row.

## Score Row Format

`get_game_score()` → `[didwin, wasaborted, last_level, mean_time_to_answer_ms]`, with
`POS_SCORE_DIFFICULTY = 6` and `POS_SCORE_MEAN_TIME_MS = 7` naming the columns the stats screen
plots. `last_level` is walked back by one when the level ended with no corrects in it, so an
abandoned level is not recorded as reached.

## Key Signals

| Signal | Direction | Purpose |
|--------|-----------|---------|
| `Level.started_playing` | level → main | `game.playing = true`, start the session clock |
| `Level.sig_level_is_done(didwin)` | level → main | Continue was pressed → `new_game(false)` |
| `game.sig_level_is_done(didwin)` | level → main | the level ended → save the score row |
| `MainGlobals.sig_level_done_popup_closed` | popup → level | Continue on the summary card |


## Passing a level

Finishing a level's rounds is not the same as passing it. `Level.level_is_done()` measures the accuracy of
the level just played — `game.session_pct_correct()` over that level's own `corrects`/`mistakes` —
against a bar that rises with the level:

```
need = mini(60 + 5 * (level - 1), 80)
```

Below it the SAME level comes round again; at or above it, the next one. The gate's result is
`game.need_to_increase_level`, which `new_game()` feeds to `increase_difficulty(game.need_to_increase_level)`.

Before this, `need_to_increase_level` was set to `true` unconditionally — finishing the rounds WAS
passing, so a player could get every single answer wrong and still be moved up, which made the
accuracy on the summary card decorative.

The bar is stated to the player as "at least NN%", so the test is `>=`. The last level
(`max_difficulty`) is exempt: there is nothing to be promoted to, so it ends as it always did.

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
`new_game()` clears `game.corrects`, `game.mistakes` and `times_to_answer` on **every** level start, not
just `if from_scratch`.

The counters matter twice over. The visible half is the HUD still showing the failed attempt's
tally. The half that decides the game is that the GATE reads them — a replay which inherited the
misses that failed the level could not pass it even played perfectly. `times_to_answer` was never cleared at all — a rolling window of the last 10 answers that spanned levels — so the card's "Average time" row and the saved score row described a mixture of the level just played and the one before it.

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
  of `Level.level_is_done()`, before anything is emitted.
- The VISIBLE score keeps showing what the player played with while the summary card is up:
  watching the number drop out from under a summary you are still reading is alarming. The visible
  rollback lands in `new_game()`, behind `_rollback_score_on_next_level`, when Continue is pressed.

Only the failed level's points go back; everything earned in levels already passed is untouched.


## Answering: right is Hi, left is Ignore

Three ways in, all saying the same thing: the two buttons, the left/right arrow keys, and a
horizontal swipe over 60px (`_input`, the same shape sortingrobots uses).

**Say Hi is on the RIGHT.** It used to be the left-hand button, which is a trap the moment a right
swipe means the same thing — `_apply_look()` moves it with `move_child` and labels the pair
`← Ignore` and `Say Hi →` so the buttons, the arrows and the gestures all agree. Keeping those
three in sync is a standing rule in this project.

`_input` returns early on `answered_current_person`, not just on the row's visibility: the row is
hidden inside `answered()`, but two events can arrive in the same frame before that happens.

## The round that stopped dead

`display_new_person()` is reached from a 2-second `do_after` after every answer. It used to open
with:

```gdscript
if !_can_play() or mode != modes.DISPLAY_SOMEONE:
    return
```

and nothing ever called it again. `_can_play()` is false while ANY screen is up (help, the level
card, the pause), while the app is out of focus, and before `game.playing` is set — so any of those
landing inside that two-second window killed the round: the last person's reaction ("Ann says Hi")
stayed on screen with no way forward but a new game.

It now waits instead of giving up — `MainGlobals.do_after(0.5, display_new_person)` — and only
returns for good when the mode has changed or the level is over.

## The look

`_apply_look()`, called from `_ready()`. The board's ground is the drawn backdrop the rest of the
app uses (`scripts/screen_backdrop.gd`) in this game's own green, in place of the tiled
`friends/art/grass.png`; the answer buttons and the Ready button are `GameButton` (Say Hi filled,
Ignore a ghost — the same weight relationship the confirmation dialog uses); the instruction and
reaction labels take the app's prose font.

## What this game measures

Session records are the v6 named-dictionary format (see `scripts/generic_game_util.gd`
and `scripts/session_stats.gd`). Metrics reset centrally in `reset(from_scratch)`.

Response times are handed to the shared session record as a whole distribution, not just a mean: `game.record_times()` in `main.gd::get_game_score()` stores spread, median, within-session slope and lapse count beside the mean. The spread is the point — it moves before the mean does.

Accuracy is stored as four counts, not a percentage: `game.record_answer(said_yes, was_yes)` at the decision point. A percentage cannot separate how well the player tells the cases apart from how willing they are to say yes, and someone compensating for a slip by guessing more holds the percentage steady while both hits and false alarms rise. Unanswered trials go to `record_no_answer()` and never into the four counts — no decision was made, so calling it a "no" would invent one.

Say Hi is the yes. The auto-Ignore that fires when a card reaches full size sets `_auto_ignoring` first, so an unanswered arrival is recorded as a non-answer rather than as a deliberate Ignore — it would otherwise inflate the miss count with decisions the player never made.
