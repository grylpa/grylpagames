# Tutorial mode

A tutorial plays the **real game**, with the real rules, while a coach bubble speaks over it —
freezing the board while it talks, spotlighting what it is talking about, and waiting for the
player to actually perform each action. Nothing done in a tutorial reaches the scores.

It exists because the written instructions were not working: every game teaches itself with one
wall of text (`game.set_instructions`), shown once, never demonstrated and never practiced. The
player's first action in a game was also their first scored action.

---

## The non-scoring guarantee

This is the load-bearing part. All of it lives in `scripts/generic_game_util.gd`.

`GenericGameUtil.tutorial_mode` guards **every** write in that file:

| Guarded | Why it needs guarding |
|---|---|
| `save_score` | the end-of-level write, and its `BE.upload_game_score` |
| `save_ongoing_score` | the 60 s autosave, polled by all 33 games' `_on_game_tick_timeout` |
| `clear_ongoing_score` | writes `[]` — would **erase** a real session still in progress |
| `convert_ongoing_score_to_permanent` | promotes a *pre-existing* ongoing row, so it would commit and upload the player's last unfinished real session |
| `_write_new_best_flag` | the "unviewed new best" marker |
| `save_settings` | carries `times_run` and `shown_instructions` |
| `times_run += 1` in `reset(true)` | stamped into every future score row |

Guarding at this single choke point is what makes the guarantee cheap: **no game's `main.gd` has
to know about it.** Backend uploads need no separate handling either — `BE.upload_game_score` is
only ever called from inside `save_score` and `convert_ongoing_score_to_permanent`, and the
login-time bulk upload only reads `scores_v5_*`, which is never written.

`begin_tutorial()` / `end_tutorial()` snapshot and restore the in-memory session state a tutorial
mutates (`_TUTORIAL_SAVED_VARS`), so a player who takes a tutorial half-way through a real session
gets that session back untouched. **Anything a game keeps outside the `GenericGameUtil` instance
is not covered** — e.g. `DinoG.starting_level_id` — and must be saved and restored by hand in the
game's `start_tutorial` / `_on_tutorial_done`.

`TutorialRunner` owns this lifecycle: `run()` calls `begin_tutorial()` if needed, and `_finish()`
*and* `_exit_tree()` call `end_tutorial()`. Tearing the overlay down some other way (scene change,
chooser back-out) therefore cannot leave `tutorial_mode` stuck true — which would silently
suppress the player's real scores from then on.

---

## The freeze

One line does the work:

```gdscript
MainGlobals.set_visible("tutorial", true)   # -> game.paused() == true
```

Every game's `_can_play()` already checks `game.paused()`, and so does the HUD countdown
(`scripts/generic_game_hud.gd`), so this freezes the board **and** the level clock in any of the
37 games without touching them. `paused()` accumulates `_total_paused_ms`, so `game_time`-based
deadlines resume without jumping.

The runner registers this only while the coach is **talking**, and clears it while the player is
**acting**.

---

## Step schema

`{game}/scripts/tutorial.gd` exposes:

```gdscript
static func tutorial_level_id() -> int
static func steps(level: Node, game) -> Array
```

Each step is a Dictionary:

| Key | Meaning |
|---|---|
| `text` | the caption (required). A String, **or a Callable returning one**, evaluated when the step opens |
| `title` | optional heading; also accepts a Callable |
| `spot` | `Rect2`, `Vector2`, a `Control`, a `Node2D`, or a **`Callable` returning one**. Use a Callable for anything that moves or is recreated — it is re-evaluated every frame |
| `spot_radius` | radius used when `spot` resolves to a point (default 60) |
| `spot_pad` | how much to inflate the box (default 10) |
| `await` | omitted = **talking**: frozen, tap to continue. `"event"` = **doing**: the game runs until `game.tutorial_notify("event")`. `{"event": "x", "timeout": 12.0}` adds an escape hatch |
| `hint_after` | seconds of no progress before `hint` is appended to the caption |
| `hint` | the nudge line |
| `setup` | `Callable` run before the step, to stage the situation the step needs to teach. It may cause the very event the step waits for — that is recognized, not lost |
| `demo_path` | `Callable` returning screen points; the overlay traces them with a moving dot, to *show* a gesture instead of describing it |

Steps with no `await` freeze the game and dim everything but the spotlight. Steps with an `await`
let the player play: no dim, just a pulsing outline, and input passes straight through.

**Always give a `timeout` to a doing step that waits on the game rather than the player** (e.g.
"a card appeared"). Without one, a missed notify strands the player forever.

**Quote the game's own state rather than paraphrasing it.** This is what the Callable form of
`text` is for. Aliens once announced "this one matches the pass" over a blue alien while the gate
plainly said GREEN: a NOT pass was in play, and `_gate_wants()` returns `matches != deny`, so the
gate *wanted* an alien that did not match. The captions now read the live pass out of the level
(`_pass_label`) and quote it in every line that talks about matching, so caption and screen cannot
disagree. If a caption asserts something about the game state, prefer reading that state.

**Show a gesture you cannot name.** `demo_path` animates a finger-trail over the board. Drawn-path
movement (`wolves`, `storm`) exists nowhere else in the app, so "trace a route" is an instruction
players have never had to act on; the trail demonstrates it while the caption explains it. Words
like "flick" are worth expanding too — gorilla says "swipe quickly in the direction you want to
go", not "flick".

**Teach an alternative input as its own doing step, not as a parenthetical.** Dino has both
buttons and a swipe; mentioning the swipe in passing meant players never discovered it. The step
now waits on `answered_without_buttons`, so tapping a button does not satisfy it — which requires
the game to report *how* the answer was given, not just that it was.

### Caption placement

The caption goes wherever there is actually room around the spotlight: below it if the gap fits,
otherwise above it, otherwise flush against it in whichever gap is roomier. Flipping bottom→top
was not enough — a target near the middle of the screen (a gorilla held mid-lane on a vertical
run) clips *both* ends, and the old fallback then chose the bottom regardless and sat on the very
thing it was pointing at. Keep step text short for spotlighted steps: on a 748px screen a
230px caption leaves almost no gap to place it in.

### Caption sizing (a trap worth knowing about)

The caption is a plain `Panel` whose height is computed with
`Font.get_multiline_string_size()` — deliberately **not** a `PanelContainer` sized by
`get_combined_minimum_size()`. A Container clamps its size to its combined minimum, and an
auto-wrapping `Label` reports a nonsense minimum height until it has been given a width: the first
version put the caption at y = −1952 with height 2644, entirely off-screen, so all the player saw
was the dim layer and a tap that seemed to do nothing. Measuring from the font also means the
caption is correctly placed on the very first frame, with no layout pass to wait for.

---

## Games covered

| Game | Input family | The thing it exists to fix |
|---|---|---|
| `dino` | discrete swipe / two buttons | "seen" means *this round*; the drain bar is a deadline |
| `change` | drag into a container | no running total is shown; coins hide under each other |
| `aliens` | drag within a simulation | outer ring vs inner ring; evicting is a correct call too |
| `gorilla` | flick to set a direction | you are counting AND collecting; gorillas only appear at the edges |
| `wolves` | **drawn path** | you can draw a route; you startle sheep, never push them |
| `storm` | drawn path + tap-tile | you must be standing NEXT to a leak; the score counts down from 100 |
| `guidem` | tap junction doors | the walkers never stop, so you set the road up ahead of them |
| `udbr` | held drag (breathing) | it is not a swipe — the finger stays down; there is no fail state |

Between them these cover every input family in the app, so a new tutorial almost always has a
worked example to copy. Two things worth knowing before writing the next one:

**Check what the movement actually is.** `MainGlobals.draw_path_mode` is set in exactly two games,
`wolves` and `storm` — there only, a finger drag traces a route the character walks. Everywhere
else a drag is a flick that sets a direction (`gorilla`), a swipe answer (`dino`), or a drag of an
object (`change`, `aliens`). Telling a player to "draw a path" in a game that has no drawn paths is
the same class of error the tutorials exist to fix. Grep before you write the sentence.

**Run per-game setup before the level is built, not after.** Aliens' `_tutorial_setup()` (one
gate, no NOT passes, no compound passes) originally ran at the end of `new_game`, long after
`_load_level()` and `_pick_rules()` had already baked those choices in — so it silently did
nothing and the tutorial ran on a level it thought it had simplified. It now runs immediately
after `_load_level()`.

**"This one" means one.** If a caption names a specific thing, capture it at step entry — do not
re-read "the most recent X" every frame. Aliens' spotlight followed `_tutorial_last_parked`, which
every later arrival overwrote, so the box hopped between aliens while the caption still described
the first, landing on ones that plainly did match during a "this one does not match" step. Lock
the reference, and where the game can keep changing the board underneath, hold that too (aliens
sets `tutorial_hold_arrivals`, which stops new gate entries until the player has acted).

**A `setup` may satisfy its own step.** The runner works out what a step waits for *before*
running its setup, and parks any event that arrives during setup (`_entering` / `_pending_event`)
rather than dropping it. Gorilla's setup spawns the gorilla the step then waits to be told about;
with setup running first, that notification landed while `_await_event` was still empty and the
step sat out its full 30s timeout while the gorilla it had just created ran past and off screen.

**Not every game can be a doing tutorial, and forcing it is worse than not.** Udbr is all talking
steps. It has no discrete action to wait for, and the events it does emit fire on a single pixel of
drag — so waiting on one and then saying "that is one inhale" told players they had done something
they had not. Where a game cannot report an action *reliably*, explain and hand over rather than
inventing a gate. The hooks stay in `level.gd` so it can become a doing tutorial if the input is
ever reworked.

**Describe the input from the code that reads it, not from the game's own instructions.** Udbr's
own text says "swipe up while inhaling", which produced three wrong tutorials in a row. What the
code does is: touching down sets an anchor, direction comes from where the finger *is* relative to
that anchor (30px hysteresis), and the flags update only on drag events — so stopping keeps the
ball moving. Read `scripts/main.gd`'s input translation before writing a sentence about gestures.

**Do not describe something the player cannot touch.** The coach FREEZES the board while it
talks, so a talking step that says "drag the top coins aside to find the rest" is asking for
something that is impossible until it stops talking. If a step tells the player to do something,
it needs an `await` so the game is actually running. Change showed a piled board across two frozen
steps and then moved on; it now hands that board over as a real exercise.

**Check the facts a caption asserts about the level.** Where a caption states an amount, a count or
a relationship ("pay 60 cents", "there are more coins than you can see"), the probe checks it
against the board: that the target is a reachable subset of the coins present, and that the pile
really does bury one. Prose is where tutorials go stale.

**Validate the thing you name — do not just remember it.** Locking a reference is not enough if
the game can change what that reference *is*. Aliens locked the alien that had just parked, but by
the time the player acted it could have wandered off on park patience, or been reused by `_recycle`
with fresh traits, or the wait step could simply have timed out and locked whatever was lying
around. The coach then marked a non-matching alien out in the field and asked for a drag the rules
refuse. The lock now goes through `tutorial_parked_alien(want, prefer)`, which re-checks both the
state and the claim. Where the game reports an event, make sure the state it implies is already
true: aliens reported "parked" at the *start* of the snap animation, when the alien was still
`SNAPPING` and no drag was legal yet.

**Check that the thing you point at survives the caption.** A player reads for several seconds.
Anything animating on its own `_process` without consulting `game.paused()` keeps moving through
the freeze: gorilla's peripheral figures walked off screen mid-caption and deleted themselves. The
freeze only stops what checks it — if a tutorial points at something, make sure that something is
actually paused.

**A frozen game produces nothing.** The coach freezes the board while it talks, so at the moment a
step opens, anything the game had not already created does not exist — no walker has been
dispatched, no card dealt, no gorilla spawned. A step that spotlights such a thing points at bare
ground. Wait for it with an `await` first, then spotlight it on the *next* step, where the freeze
holds it still while the coach talks about it.

## Adding a tutorial to a game

1. **Hook the game's existing decision points.** Add `game.tutorial_notify("...")` where the level
   already knows something happened — no new state machine. It is a no-op outside tutorial mode,
   so it is safe in the normal gameplay path. Dino does this in `_show_next_card` (`card_shown`)
   and `_register_answer` (`answered`, `answered_correct`, `answered_wrong`).
2. **Stage what the lesson needs.** A tutorial usually needs a specific situation the game would
   only reach by luck. Prefer a small, additive, normally-empty override: dino's `_forced_picks`
   scripts the opening cards as new, new, repeat, and does nothing in normal play.
3. **Skip the level's own intro popup** when `game.tutorial_mode` — the tutorial *is* the intro,
   and showing both makes the player dismiss a wall of text before being taught it.
4. **Write `{game}/scripts/tutorial.gd`.** Lead with a comment listing what first-timers actually
   get wrong, in order of damage, and teach in that order.
5. **Wire `main.gd`:**
   ```gdscript
   if MainGlobals.take_pending_tutorial("<folder>"):
       call_deferred("start_tutorial")
   ```
   In `start_tutorial`, call `game.begin_tutorial()` **before** `new_game()` — `new_game()` runs
   `game.reset(true)`, which calls `convert_ongoing_score_to_permanent()` and would commit the
   player's pending real session. Save any state that lives outside the `GenericGameUtil`
   instance, and restore it in `_on_tutorial_done`.
6. **Register it** in `MainCfg.tutorials` (`scripts/config.gd`). That single list drives the
   chooser's "How to play" picker and the `?` badges on the game rows.
7. **Document it** in `{game}/docs/design.md`.

---

## Entry points

- **First run after install** — `scripts/main.gd::_offer_tutorials_when_idle()` opens the picker
  once the opening flow (guest name, login) is done. Gated on `MainGlobals.shown_tutorial_offer`,
  persisted in the app-level settings (slot 14) — *not* in the per-game settings file, which
  tutorial mode cannot write.
- **"How to play" pill** on the game chooser, beside About.
- **A way OUT, on every step.** The overlay carries a "Skip tutorial" button (top right) and ESC
  does the same. Without one, a tutorial opened by accident could only be escaped by backing out
  to the game chooser. Skipping goes through the ordinary abort path, so the player's session is
  restored exactly as a completed tutorial restores it — and a skipped tutorial is *not* recorded
  as done. The button is parented to the CanvasLayer rather than to the dim layer, because on a
  doing step the dim ignores input entirely and a button inside it would be dead exactly when it
  is most wanted.
- **The first-run instructions popup is suppressed** while a tutorial is pending or running
  (`GenericGameUtil.show_instructions`). Every game shows that text wall from `_ready`, which runs
  *before* the deferred `start_tutorial` — so a first-time player got the wall and the coach at
  once, with the tutorial advancing underneath the popup. The `shown_instructions` flag is
  deliberately left alone, so a player who skips the tutorial is still shown the text next time.
- **"How to play" on the game's own main menu**, for a player who is already inside the game. It
  is safe to use mid-session: `begin_tutorial()` snapshots the score, level and ongoing row, every
  write is suppressed while it runs, and `end_tutorial()` puts it all back — the player lands back
  on the menu with their game exactly as they left it.

  No game opts in. `main_menu._maybe_add_tutorial_button()` shows the button when the host scene
  defines `start_tutorial()`, so a game that gains a tutorial later gets the button for free.

The picker orders games the **reverse** of the chooser: tutorials you have not done come first,
and ones you have finished sink to the bottom (most recently finished last), since the point of
that list is what you have yet to learn. Completion is recorded by `TutorialRunner` through
`MainGlobals.tutorials_done`, and works from either entry point — the chooser sets the folder via
`take_pending_tutorial`, the in-game button via `note_tutorial_started`.

The picker lists only games in `MainCfg.tutorials`, so a player can see which games will teach
them without entering each one to find out. The chooser hands the request over through
`MainGlobals.pending_tutorial`, because it instantiates game scenes generically and has nowhere to
pass arguments.

---

## Verifying a tutorial

There is no CLI test pipeline; use throwaway headless probes and delete them afterwards. The three
that mattered while building this (all seeded with deliberate faults first, to prove they could
fail):

1. **Persistence** — snapshot the bytes of every `user://` file for the game, run the whole
   tutorial, assert every file is byte-identical and `times_run` did not move **during** the run.
   Checking `times_run` only afterwards proves nothing, because the restore papers over a missing
   guard. Run it three ways: no prior data, completed scores present, and a **dirty ongoing
   session** present.
2. **Freeze** — on a talking step, hold for ~40 frames and assert the phase, the card, and the
   per-card deadline are all unchanged.
3. **No timeout fallbacks** — assert no doing step ended by hitting its own `timeout`. Without
   this, a broken `tutorial_notify` looks like success: the tutorial still limps forward, just
   several seconds late on every step.
4. **Captions match reality** — where a caption asserts something checkable ("this one matches
   the pass"), assert it against the game's own judgment. This is the check that would have caught
   the aliens bug, and no amount of structural testing would have.
5. **Spotlights resolve** — assert that a step declaring `spot` actually produced one. This is
   what catches "the game was frozen so the thing does not exist yet"; it found a real bug in
   gorilla the first time it ran.
6. **Caption placement, every step** — assert the panel is fully on screen, clears the app bottom
   bar, is tall enough to hold its text, and never intersects its own spotlight. None of this is
   visible to a headless run any other way, and it is where the first real bug was.

Also count only the answers that actually *registered*. Dino ignores any answer within 150 ms of a
card appearing, so a probe that answers as fast as it can inflates its own counters with attempts
that never landed — 67 button presses reported where 3 had happened.

Use a throwaway `file_names_prefix` in any probe that writes, so it can never touch a real game's
save files.
