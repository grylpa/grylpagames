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
| `demo_path` | `Callable` returning screen points; the overlay traces them with a drawn pointing hand, then walks a dot along the same route, to *show* a gesture instead of describing it |

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

**Show a gesture you cannot name.** `demo_path` animates a pointing hand over the board, then a dot
walking the same route — the gesture, then its effect, in that order. The hand is drawn as a
polygon (`_HAND_SHAPE`), not typeset from an emoji, so it does not depend on a font being installed
and cannot be rendered as a blank box. It was two stacked rectangles once, which at that size read
as a featureless blob — indistinguishable from the dot that follows it, so the sequence did not
come across at all. Drawn-path
movement (`wolves`, `storm`) exists nowhere else in the app, so "trace a route" is an instruction
players have never had to act on; the trail demonstrates it while the caption explains it. Words
like "flick" are worth expanding too — gorilla says "swipe quickly in the direction you want to
go", not "flick".

**Teach an alternative input as its own doing step, not as a parenthetical.** Dino has both
buttons and a swipe; mentioning the swipe in passing meant players never discovered it. The step
now waits on `answered_without_buttons`, so tapping a button does not satisfy it — which requires
the game to report *how* the answer was given, not just that it was.

### Caption placement — side captions

`caption_side` picks where the caption lives: `"auto"` (default, the full-width panel described
below), or `"right"` / `"left"` for a narrow column pinned to that edge and vertically centred. Set
it on the runner before `run()`, or per step with a `caption_side` key.

Use a side caption when the game's action runs down the **middle** of the screen. udbr's lane is
vertical and centred and the ball travels its whole height, so a full-width caption docked at the
bottom sits on exactly what the player is meant to be watching. The column is `0.32` of screen
width (min 150 px) — 218 px on a 680 px screen, against udbr's 180 px centred lane, so it clears
it — and it keeps below the Skip button in the top-right corner.

A narrow column wraps text much taller, so **side captions need short, imperative copy**. If a
caption needs a paragraph, it probably wants `auto`.

### Caption placement — auto

The caption goes wherever there is actually room around the spotlight: below it if the gap fits,
otherwise above it, otherwise flush against it in whichever gap is roomier. Flipping bottom→top
was not enough — a target near the middle of the screen (a gorilla held mid-lane on a vertical
run) clips *both* ends, and the old fallback then chose the bottom regardless and sat on the very
thing it was pointing at. Keep step text short for spotlighted steps: on a 748px screen a
230px caption leaves almost no gap to place it in.

### Caption sizing (two traps, both about container minimums)

The caption is a plain `Panel` and the three labels are positioned **by hand**, not by a
`VBoxContainer` — a Container clamps itself to its children's combined minimum, and an
auto-wrapping `Label` computes that minimum from whatever width it currently has. Early versions
hit this twice: once putting the caption at y = −1952 with height 2644, and once inflating the
label stack to 2223 px on the opening step.

Height comes from `_label_height()`, which rebuilds it from **whole font lines**
(`f.get_height(fs) + line_spacing` per line) rather than from
`Font.get_multiline_string_size().y`. That call returns the *text's* extent, while a Label reserves
a full line box per row — a couple of px per line, invisible in a wide caption, but it stacked up
in udbr's narrow column until "tap to continue" hung below the balloon.

One thing to know when checking this: labels are **top-aligned**, so `Control.size` on a label is
not where the text ends. Godot's minimum-size cache updates a frame late, so a label's rect is
often far taller than its text; the panel clips it and nothing shows. Measure
`position.y + _label_height(...)`, which is what the probe now asserts for every step of every
game.

### Caption sizing (historical)

The caption is a plain `Panel` whose height is computed with
`Font.get_multiline_string_size()` — deliberately **not** a `PanelContainer` sized by
`get_combined_minimum_size()`. A Container clamps its size to its combined minimum, and an
auto-wrapping `Label` reports a nonsense minimum height until it has been given a width: the first
version put the caption at y = −1952 with height 2644, entirely off-screen, so all the player saw
was the dim layer and a tap that seemed to do nothing. Measuring from the font also means the
caption is correctly placed on the very first frame, with no layout pass to wait for.

---

## Games covered

**taxi** (8 steps). The longest instruction text in the app — eight numbered rules, almost none of
them observable. Teaches money-as-score first, then select-then-send on a real fare, then fuel with
a tank staged low by `level.tutorial_drain_taxi()`.

Three things are specific to taxi and worth copying when a game keeps state of its own:

- **Its saved game is outside `GenericGameUtil`.** `main.gd::save_game_state()` writes a whole
  board through `SaveManager` every 30 s, so none of the tutorial write-guards cover it; it now
  returns early in `tutorial_mode`. Verified by planting a saved game and running a tutorial with
  the save interval forced to 100 ms: without the guard the player's level-5 board is replaced by
  the tutorial's level-1 city, with it the file is byte-identical afterwards.
- **Rules that would bite a slow reader are suspended, not hidden.** A parked taxi empties its tank
  in 60 s and a customer gives up after 30 s; both are stashed and restored around the tutorial, so
  a player reading at their own pace does not have the fleet strand itself or the fare walk off
  mid-lesson. The final step still tells them both rules exist.
- **Customers arrive on demand** (`tutorial_hold_dispatch` + `tutorial_request_customer()`), rather
  than every 5 s on the level-1 timer.

`_restore_tutorial_globals()` is called from `_on_tutorial_done` AND `_exit_tree`, and it puts the
player's own saved state back into the level so Continue still resumes their game.

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

**Don't number the steps.** The footer used to show "3/12" and the numbers skipped. Several steps
exist only to unfreeze the game and wait for it to produce something ("here comes the first card",
"here comes another pile"); they are satisfied within a frame or two and are never really seen, so
the sequence ran 1, 3, 4, 6 … Counting frames-per-step cannot tell those apart from a genuine bug
either. A numbering that skips is worse than none; if position ever needs showing, use a continuous
progress bar.

**A `setup` that satisfies its own `await` makes the step invisible.** It advances from inside
`_enter_step`, so it is never current at a frame boundary. Gorilla had one: its setup spawned the
gorilla and the step waited for `gorilla_appeared`. Fold such a step into the one that talks about
the result — the wait is pointless when the setup is synchronous.

**Wait on the event that means what the caption says.** udbr's tutorial asked for an inhale but
waited on the direction *latch*, which trips a frame or two into the drag. The step therefore ended
before the ball had moved, and the next talking step froze the board — 24 of 25 frames paused
during a swipe, against 0 in normal play, which reads to the player as "the swipe does nothing".
If the game only reports the *start* of an action, add a hook for its completion rather than
pretending the start is the whole thing.

**Force the tutorial's own level/mode, and check the override actually took.** A tutorial must not
inherit whatever the player left the menu on. Every game overrides its starting level in
`start_tutorial` and restores it in `_on_tutorial_done` — but udbr's override was
`UdbrG.guided_mode = false`, and `guided_mode` is a **getter-only** computed property
(`return selected_mode != 0`). The assignment silently did nothing and the tutorial ran in whatever
Mode was selected. Set the underlying field (`selected_mode`), and assert the result rather than
the assignment. Watch for anything else the menu controls that the tutorial can outlast, too:
udbr's default session is 1 minute, short enough for the results panel to appear over the coach
mid-lesson, so the tutorial raises `duration_min` and puts it back.

**Trust the game's own instructions screen over a model you derive.** udbr took three wrong
tutorials because I read `scripts/main.gd`'s hysteresis block but not `_process_vertical_steps`,
which wraps `swipe_accum` every 50 px — so I invented an "anchor" model that does not exist, while
the game's own "I" text ("swipe UP while inhaling") was correct all along. Read the input code to
*understand* the text, not to replace it; where they disagree, find out why before writing a word.
**Do not describe something the player cannot touch.** The coach FREEZES the board while it
talks, so a talking step that says "drag the top coins aside to find the rest" is asking for
something that is impossible until it stops talking. If a step tells the player to do something,
it needs an `await` so the game is actually running. Change showed a piled board across two frozen
steps and then moved on; it now hands that board over as a real exercise.

**Check the facts a caption asserts about the level.** Where a caption states an amount, a count or
a relationship ("pay 60 cents", "there are more coins than you can see"), the probe checks it
against the board: that the target is a reachable subset of the coins present, and that the pile
really does bury one. Prose is where tutorials go stale.

**Do not describe a thing before the player can see it.** A step that waits for something should
say only that it is waiting; the description belongs on the step where the thing is on screen and
marked. Aliens announced "now one the pass does not accept" and then left that sentence up for
however long it took such an alien to walk in.

**A promised arrival has to be guaranteed, not likely.** If a step says "this one matches, drag it
in", something must actually be there. Aliens reserves the slot, holds off other arrivals, makes
room if the ring is full, and reports the arrival itself if one of the required kind is already
parked — otherwise the event fired before the step opened and the step waits out its timeout.

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
- **The level clock is held at 30 minutes** for the duration of a tutorial
  (`TutorialRunner.TUTORIAL_MINUTES`). A tutorial runs on the real level, so it inherits that
  level's clock — 40-120 s in most games — and reading the captions easily outlasts it, dropping a
  "level complete" popup over the coach. It is re-applied each frame rather than set once: wolves'
  and storm's `new_game()` await a frame, so the level applies its own level time *after* `run()`
  has already set ours, and they were left on 120 s.

  It cannot leak into real play. `time_left_sec` and `_reset_time_left_sec` are both in the
  `begin_tutorial()` snapshot, and a real game re-derives its clock from its level config on the
  next `new_game()` anyway. Verified per game by comparing a normal `new_game()` clock against one
  started right after a tutorial in the same session — identical for all eight.
- **A step may carry a `tick` Callable**, run every frame while it is current. It exists so a game
  can repair a situation the player has broken out from under a step. The player can always do the
  opposite of what they are told: aliens says "this one matches — drag it into the inner circle",
  and they drag it OUT. The step then waits on a `promoted` that can never come, its mark follows
  the alien as it wanders the field, and because arrivals are held for the duration of the step
  nothing can reach the ring either — a dead tutorial with a marker chasing an alien around.

  aliens' two drag steps tick a `relock`: if the alien the step is about is no longer waiting at
  the gate, lock onto another of the same kind, and if there is none, send one. Its two wait steps
  tick a `nudge` that re-requests an arrival that never turned up (rate-limited to one request per
  4 s, since requesting spawns or re-routes an alien).
- **`take_pending_tutorial()` belongs at the END of `_ready`, after `show_instructions`.** The
  suppression guard in `show_instructions()` asks "is a tutorial pending for me?", so consuming the
  flag earlier empties it and the text wall appears anyway — the player asked for the tutorial and
  got the instructions screen. dino had the call inside `show_main_menu()`, which `_ready` invokes
  early, so it broke exactly this way. Checking line numbers is not enough; check the enclosing
  FUNCTION.
- **A delayed call outlives the tutorial.** Anything scheduled with `do_after`, a Timer or a tween
  fires on its own clock, and a second later the player may have finished the tutorial — so a guard
  that reads `tutorial_mode` at fire time sees false and lets the thing through. Decide at SCHEDULE
  time and capture the answer. mmm's "Round 1 of Level 1 completed" reached the player twice this
  way. The harness now waits after every tutorial and fails if any panel (a visible node with
  `set_title`/`set_text`) has appeared.
- **Never let the game free-run when it matters to the step.** If a caption is talking about
  something, that something must not be moving, expiring, or about to be replaced while it is read.
  Every game needs its own version of this: taxi freezes fuel and the customer's patience, didi
  holds the round until the player taps, Sorting Robots stops both belts once the framed item is in
  view, Mind Palace halts the player before talking about the floor they are standing on. Timeouts
  and clocks get pushed out of reach and restored afterwards.

  A related trap: an object that ENTERS from off-screen is usually behind something else for its
  first moments. Sorting Robots frames an item while it is still above the belt, so the frame sat
  on the rule label and read as though the RULE were being framed. Wait for the thing to reach its
  place before pointing at it — the level runs the belts on until the item clears the label, then
  stops them and reports `window_settled`.
- **A step with no title and no text shows no caption.** Some steps exist only to wait for the game
  to reach a state — didi holds its round until the player taps, then needs a step that simply waits
  for the flash — and a filler line ("here it comes") appears for a moment and reads as a glitch.
  Give such a step no words and the panel stays hidden.
- **The step that has just opened ignores taps for `STEP_SETTLE_MS`.** The tap that completes a
  doing step arrives twice (touch plus the synthesized mouse event): the first goes to the game and
  satisfies the step, the second lands on the dim of the step that just opened and dismisses it.
  `TAP_DEBOUNCE_MS` cannot catch that pair, because the first half never went through the overlay.
  In Mind Palace this took the player from answering a color straight to the main menu, on mobile
  only — where the synthesized event actually reaches the overlay.
- **A step that asks for an action must BE a doing step.** A talking step freezes the board and
  swallows the next press, so an instruction in its text cannot be obeyed — and the press that
  begins the attempt dismisses the step instead. Obeying the coach is what skips it. change's
  "look underneath" step said "drag the top ones aside" while frozen; it now waits on `coin_moved`
  (fired by `_drop_coin` wherever the coin lands, so shifting the heap counts as much as dropping
  into the tray). storm's bucket step was teaching a rule about a situation not on screen, so it
  describes the action rather than commanding it.

  The harness fails any talking step whose text opens a clause with a board verb (drag, tap, press,
  swipe, draw, trace, walk, put, pay). Two things that check has to get right, both learned by
  seeding the bug back in: it splits on em-dashes and semicolons, not just sentence ends (the
  original instruction hung off an em-dash and a first-word-of-sentence test sailed past it), and
  it exempts steps with a `demo_path` (those show a gesture rather than ask for one) and the
  opening step (no board exists yet, so "Pay it exactly" is the goal, not an instruction). "Lift"
  is deliberately not a board verb — releasing a finger works fine while the board is frozen.
- **A `tick` must keep its hands off while the player is mid-gesture.** An alien being dragged is
  in `DRAGGED` state, not `PARKED_OUTER`, which reads exactly like "it left the gate" — so aliens'
  `relock` handed the frame to a different alien while the player was still carrying the one it
  had marked. `relock` now returns immediately while `level._drag_alien` is set, and `locked_spot`
  keeps resolving to an alien that is in the player's hand (only a *wandering* one is refused).
  Whatever they do with it resolves the moment they let go, and the tick runs again then.
- **The spotlight pulses.** A caption naming something ("this is your money") is usually at the
  other end of the screen from the thing it names, and a steady outline does not read as "look
  here" — players read the words without ever finding the target. The frame breathes between 0.30
  and 1.00 opacity over `SPOT_PULSE_SEC` (1.6 s), thickening 3→5 px as it brightens, and throws a
  second ring that expands `SPOT_HALO_PX` and fades. Slow on purpose: a fast blink beside text you
  are trying to read is worse than none.
- **A spotlight that stops resolving must erase its frame.** The per-frame redraw was requested
  only while there WAS a spotlight, so when one resolved to nothing the last frame drawn stayed on
  the canvas — dragging the marked alien out of the ring left its marker hanging in empty space.
  The redraw is now also requested on the has-spot transition.
- **The caption does not chase a moving spotlight.** It is repositioned only when the spotlight has
  actually come to sit under it, and then not again for `SPOT_FOLLOW_COOLDOWN_MS` (700 ms).
  Re-laying out on every change made the bubble jump across the screen frame by frame behind a
  moving target. `locked_spot` in aliens also refuses to resolve to an alien that is not parked at
  the gate, so the mark is never left on something walking away.
- **A step must wait for the outcome it names, not for the button press.** change's payment steps
  waited on `paid`, which `_resolve` fires for a wrong payment as well — so pressing PAY with any
  coins in the tray completed the step, and the coach moved on to the next pile having never had
  the amount it just named paid. They now wait on `paid_correct`, and `change/level.gd` re-queues a
  missed board while `tutorial_mode` is on, so the same pile comes back and the lesson can actually
  be completed rather than the caption being left naming an amount nothing on screen is asking for.
- **State a lesson leaves behind must not break the next one.** change's step 4 says "drag *a* coin
  into the tray". A player who dragged the 5c still had it there when step 6 said "put in exactly
  35 cents" — they added 25+10, the tray held 40c, and they were marked wrong for following the
  instruction exactly. The tray is now emptied by step 6's `setup`, and step 5 teaches dragging a
  coin back out — a mechanic the tutorial never mentioned, without which a player who mis-adds has
  no way to correct it.
- **The board must not lag the caption.** A tutorial announces the next card or pile the instant
  the previous answer lands, while the board is still showing its feedback banner and then waiting
  out the inter-round gap — so the thing the caption is talking about turns up a second later and
  the tutorial reads as hung. dino's tutorial cuts `gap_ms` 800 -> 150 and `feedback_ms` 700 ->
  250 (measured 1.57 s -> 0.58 s from caption to card); change cuts 1000 -> 200 and 1200 -> 500.
  `feedback_ms` is a var only for this, and `_load_level` restores `FEEDBACK_DEFAULT_MS`, so real
  play never inherits the tutorial's pacing — verified per game by comparing a normal `new_game()`
  against one started right after a tutorial in the same session.
- **The caption must not cover the controls the step tells you to use.** `TutorialRunner.keep_clear`
  is a per-game list of Callables returning a Rect2, a Control, or null; set it before `run()`.
  Those rects are treated as obstacles when the caption is placed — together with the spotlight,
  which always counts, because pointing at something and then covering it is the one thing a coach
  must never do.

  Honored on **player-action steps only**. On a talking step the game is frozen, nothing underneath
  can be used, and the caption reads better docked low.

  Placement (`_best_y`) tries the natural bottom dock plus flush-above and flush-below each
  obstacle, and takes whichever overlaps least, ties going to the lowest. The panel is never shrunk
  to fit: a clipped instruction is worse than an overlapping one. This replaced a spotlight-only
  rule that could only flip bottom->top, and so could not express "clear of the spotlight AND clear
  of the tray" — change's caption sat on 94%% of the tray on the step telling the player to put
  coins in it, and dino's sat on the New/Seen buttons on every step telling them to press one.

  Currently set by change (pile, tray, PAY) and dino (both answer buttons). Measured clear on both
  desktop and mobile metrics; the harness fails any player-action step whose caption overlaps a
  keep-clear zone.
- **One tap must advance exactly one step.** Godot delivers a single tap as *two* events: the
  Input layer synthesizes a mouse button from a screen touch
  (`input_devices/pointing/emulate_mouse_from_touch`, on by default) and a screen touch from a
  mouse button (`pointing/emulate_touch_from_mouse=true` in `project.godot`). `_on_dim_input`
  accepts both, so every tap fired it twice, and `accept_event()` does not help — it ends
  propagation of the event it is called on, not of the twin that follows.

  The cost was a lost step wherever two talking steps sat next to each other: the tap dismissing
  the first also dismissed the second. gorilla showed 4 of its 7 steps and never reached its
  ending; wolves showed 5 of 8. Steps followed by a player-action step were spared, because
  `_blocking` goes false and the twin is dropped — which is why the loss looked random rather than
  systematic, and why it surfaced as "the last step isn't shown".

  Fixed by `_tap_advance()`, which debounces input-driven advances by `TAP_DEBOUNCE_MS` (350 ms).
  Debounced rather than filtered by event type: dropping `InputEventScreenTouch` outright would
  leave the tutorial undismissable wherever mouse emulation is off.
- **Returning to the game's own menu ends the tutorial.** `main_menu._on_visibility_changed()`
  calls `game.abort_tutorial()` when the menu becomes visible — the one place every game passes
  through on its way back, so no game has to remember it. The coach lives on a `CanvasLayer` owned
  by the game's main scene and does **not** hide with the level, so without this, pressing M
  mid-tutorial left the balloon sitting on top of the menu.

  The call is **deferred** on purpose: a game's back-to-menu handler usually calls
  `show_main_menu()` and *then* runs its save path (dino: `_save_ongoing_score()` +
  `convert_ongoing_score_to_permanent()`). Ending the tutorial synchronously would clear
  `tutorial_mode` first and let those writes through, so quitting a tutorial could commit the
  player's pending real session. Deferring keeps every write suppressed for the rest of that
  handler.
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

## Running long

**The level clock cannot run out.** `_hold_clock()` re-applies `TUTORIAL_MINUTES` every frame it
falls more than 5s short, so the clock sits pinned at 30:00 rather than counting down from it —
"30 minutes" is a floor, not a budget. Verified by forcing `time_left_sec` to 3 and then to 0
mid-tutorial: both were back at 1800 within a frame, the tutorial ran on, and `level_is_done`
stayed false.

**A step's own `await` timeout is the thing that actually fires.** When it expires the runner just
advances (verified: dino's 40s drag step moved on to the next step and the tutorial continued). A
step whose `await` omits `timeout` waits indefinitely — dino's three "tap New/Seen" steps are the
only ones like that, and they are safe because the game keeps dealing cards, so the player can
always satisfy them. Skip and ESC are the way out regardless.

**udbr is the exception, because its session length is its own.** The game clock is a 16-hour
dummy, and the session ends after `duration_min` — 30 real minutes during a tutorial. A player who
works through it slowly can genuinely reach the end of one, and `_on_level_session_done` writes
`UdbrG.learned_*` and `has_user_session`, which the "User" mode preset is built from. `save_score`
and `UdbrG.save_settings` are suppressed in tutorial mode, so nothing reached disk at that moment
— but those two are plain in-memory globals, and the next legitimate save persisted the tutorial's
breathing as the player's own pattern. Measured: `has_user_session false -> true`, learned pattern
`[4000, 4000] -> [3210, 4300]`. The handler now returns early in tutorial mode.

## A global flag that kills breathing games

Not a tutorial bug, but found while auditing one, and worth recording here because the audit is
what surfaced it. `MainGlobals.popup_open` is global and sticky, and while it is set
`scripts/main.gd::_process` blanks the digitized-swipe flags every frame — which silently kills
exactly the games driven by them (udbr, mother, crack; river is commented out of the game list)
and no others. Two owners set it: `ReauthPopup`, shown when the session expires after the app has
been sitting idle, and storm's action panel. `ReauthPopup` cleared it only from its two buttons, so
any other way of that popup going away left every breathing game dead until the app was restarted;
it now clears on `_exit_tree`.

storm's panel was NOT implicated and is deliberately left alone. It clears the flag via
`popup_hide` plus two explicit calls. A `tree_exiting` guard was tried there and reverted: the
replace-an-open-panel path calls `queue_free()` on the old popup and then sets the flag for the new
one, and since `queue_free` defers deletion to the end of the frame, the old node's `tree_exiting`
would fire afterwards and clear the flag while a panel was genuinely open.

Measured: with the popup up, a swipe gives 0/15 frames flagged and a frozen ball; after it is
freed, 15/15 and the ball moves.

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

**The caption weighs its own spotlight above everything else.** `_best_y` scores candidate
positions by how much they overlap; the spotlight's overlap is multiplied by `SPOT_COST_WEIGHT`
(8x) and `keep_clear` zones count 1x. Equal weighting is wrong because the spotlight is usually
*also* one of the keep-clear zones — the thing being pointed at is normally the thing to be used —
so the same pixels get counted twice and the placer will sit on the subject of its own caption to
spare some other zone. Delem FP hit exactly that.

**`keep_clear` is for what the player must READ or PRESS, not for everything on screen.** Listing
scenery there just gives the placer contradictory demands, and it will satisfy them by covering
something that matters. If a thing is only meant to be *seen*, make it the step's `spot` instead.

**`keep_clear` applies on talking steps too, not only when the player has the controls.** It began
as "what must stay reachable", but a caption that buries the thing the coach is describing is just
as broken when the board is frozen — Delem FP's caption sat squarely on the truck while telling the
player to work a route out from it. The spotlight weighting above is what stops this from pushing a
caption onto its own spotlight instead.

**Teach the state the game actually has.** Delem FP's first tutorial taught steering on the open
board because it read better — but zoomed out the game freezes the truck by design, and its printed
instructions say "You cannot move while zoomed out". The lesson demonstrated a state that does not
exist. If a sequence feels awkward to teach, walk the real one more slowly; do not invent a
friendlier one.

**An unexplained freeze reads as a broken game.** Delem FP's five-second countdown was originally
skipped, which left a gap between the map and the zoom with no reason given. Show the mechanism and
name it. A pause-aware countdown can even be frozen *on screen* while the coach points at it —
`game.paused()` stops the HUD timer — so the explanation and the thing explained are visible
together.

**When a frame "does not appear", check whether the thing it is looked up FROM is still alive.**
Parkem's spot and hatch accessors both start from the creature, and the creature's give-up timer
ran on the WALL clock — so it expired while the player read a caption, vanished, and every frame
derived from it silently resolved to nothing. Three separate-looking complaints ("it disappears
while I read", "which door is open?", "no frame") were one bug. Fix the clock, not the accessors.

**A frame can be correctly placed and still show the player nothing.** Nearly every hatch in
parkem starts OPEN, and an open one is flat tube furniture — so the frame was right and the player
saw an empty rectangle. Where the thing being pointed at is not visually obvious, the caption has
to name what is inside the frame. (The door counts in the level data were enough to work this out;
no need to look at the art.)

**When picking "one of these" to point at, pick one that is wholly on screen.** Monkey C's item
spotlight took the item furthest down the belt, which is usually half off its end — the spotlight
landed at y=792 on a 788px overlay. Choose from the middle of the region and require the candidate
to be fully inside it.

**Anything the player must read off the HUD needs `never_dim`.** A game's HUD sits on a low
CanvasLayer and the overlay dims from 120, so HUD text is unreadable on every talking step except
the one whose spotlight lands on it. Deliverem's dispatcher line ("Deliver to 2,3") was invisible
for the whole tutorial that way. Registering it in `runner.never_dim` keeps it at full brightness
throughout — which also teaches WHERE that information lives, part of learning the game.

**A zone can appear after the caption has been placed.** The opening caption is laid out before
the game has finished building its board, so at that instant there is nothing to avoid — and the
board then materializes underneath it. mmm's intro caption sat squarely on the coin this way while
sixteen clean positions were available. `_follow_keep_clear()` re-places the caption when a zone
comes to sit under it, using the same discipline as the spotlight follow: only when properly buried
(>50%, since a clipped corner is not worth a jump) and never more often than
`SPOT_FOLLOW_COOLDOWN_MS`, or the caption chases the board around the screen.

**The overlay must keep swallowing input for the settle window after a step change, not only
while a caption is up.** One physical tap is two events (a touch plus the mouse event synthesized
from it). The first half dismisses the caption; the step advances to a doing step; the overlay
drops to MOUSE_FILTER_IGNORE — and the second half lands on the board. In Couples, dismissing the
"Picked up" caption with a tap that happened to sit over a card registered as choosing that card.
`_apply_dim_filter()` keeps the overlay at STOP while `Time.get_ticks_msec() - _step_opened_ms <
STEP_SETTLE_MS`, and it must be called AFTER `_step_opened_ms` is updated — applying it first
measures the window against the step that just ended, which is always long past, so the guard
never engages.

**A game that has a tutorial never shows its instruction text automatically.** The tutorial IS
the instructions, delivered one beat at a time — so the wall of text is suppressed on the first run
(where the tutorial runs instead) and on every run after (where it would just be a repeat of what
the tutorial already taught). It stays reachable on demand: pressing I, or the help menu, calls
`show_instructions(parent, false)` and always gets the text. Games with no tutorial are unchanged —
the wall shows once, on first run, as it always did.

**A step must never be a dead end, and a step that depends on a control outside the game's own
scene is the one most likely to become one.** The app's bottom bar belongs to the root scene, not
to the game, so a game's tutorial cannot fully account for it. Where a step waits on one of those,
give it a `tick` that performs the action itself after ~20s: the player still sees what the control
does, and a press that never lands cannot strand them. Steps that wait on the game's own board do
not need this — the harness covers those.

**An instruction must appear on a step where the game accepts it RIGHT NOW — not one step early.**
Three separate things can refuse an action: the caption's own freeze (a talking step), a
game-specific hold the tutorial itself applied, and a game state that forbids it by design. Delem FP
hit all three: the steering instruction sat on the talking step that parked the truck, and later the
delivery step could open during zoom_unzoom()'s 4-second look, when movement is refused anyway. A
player who follows an instruction and gets nothing concludes the controls are broken — and keeps
trying, so they do not tap to continue either. Worth an explicit harness check per game: find the
captions that name a control, and assert the game would honor it at that moment.

**Never ask for an action the game will not accept yet.** Delem FP told the player to "go — find
the way to dock 4" while the truck was still frozen for the countdown. If a step is a look-and-
remember beat, word it as one, and say plainly why they cannot move.

**A global signal may have more than one sender, and the other one may not be paused.** The app
root carries its own spare `GenericGameHUD` alongside the game's. Its `game` is null, so every
`if game and game.paused()` guard inside it is dead and it keeps running under a tutorial caption.
Delem FP's countdown froze on screen while that hidden twin counted to zero in real time and fired
`sig_global_countdown_finished`, zooming the camera in with a 5 still showing. When a step depends
on something reaching a state, watch the thing the PLAYER can see, not a signal that anyone may
emit.

**A spotlight derived from a moving thing's position will chase it.** Deliverem framed "the next
door ahead of the truck", recomputed every frame — so as the truck drove, the frame hopped from
door to door while the player was trying to tap it. The fix is almost always to stop the moving
thing for that step rather than to chase it with the frame; pinning the target is a weaker
second-best, and is redundant once the motion is held.

**A tutorial has to survive the player getting it WRONG — that is when they most need it to keep
going.** Three separate dead ends in Lineup, Glimpse and Witness all came from protecting the
correct path and leaving the wrong one stranded: a wrong pick clears the board (so a static freeze
means no next round ever arrives), and a wrong direction dot ends the question and clears every
button (so a step waiting for "the right answer" waits on things that no longer exist). Wait on an
event that fires on ANY answer, and say what happened in a reactive caption.

**Hand the caption placer several small obstacles, not one merged box.** Glimpse's candidates ring
the board, so their bounding box is most of the screen: as one rect the constraint is unsatisfiable
and the caption lands straight on them. Listed individually, the empty middle of the board becomes
obvious and the caption goes there. Measured: 2 of 2 candidates covered before, 0 of 2 after.

**"The timer runs on game_time, which excludes paused time" protects the TALKING steps only.**
An action step is unpaused by design — that is what makes it an action step — so anything with a
deadline still expires while the player decides. Lineup, Glimpse and Witness all needed an explicit
`tutorial_freeze_board()` on top of their game_time timers, and I skipped it on all three because
the game_time detail made the problem look solved.

**But do not freeze through a step that is WAITING for the board to advance.** Lineup's lineup only
appears once the model times out; freezing across that await deadlocked the tutorial until the
step's own 60s timeout fired, and then it carried on with an empty board. Freeze the talking steps
and the decision steps; release for the awaits that need the game to progress.

**A frame around SEVERAL things needs more clear space than one around a single thing.** Building a
multi-option rect from one bare tile per option, while every single-option frame is 1.5 tiles, made
it hug their outlines. Give each enclosed item ~1.4x the single-option box; measured, that moves an
option's center-to-frame-edge from 0.5 to 1.15 tiles.

**A per-round deadline has to be held for the whole tutorial, not just the talking steps.** A
caption freezes `game.game_time` and with it any deadline measured against it — but the doing
steps run unpaused, and that is exactly where a first-timer is slow, because they are being asked
to do something for the first time. Couples gives 6s per board; being told to find the pair and
then losing the board to the clock teaches nothing. Keep the timer bar visible but held, so the
step that explains it still has something to point at.

**Unpause means the whole game is running, including whatever moves by itself.** A step that waits
on a button press is not a talking step: the board is live. Delem FP's truck drove off during the
Zoom and Clue lessons and could deliver a packet no step was waiting for — and since the runner
holds exactly one pending event, that spent delivery left the final step waiting forever. Park the
self-moving parts for any step that is not about them.

**Read counts from a source that has already settled.** A value mid-animation is not the value.
Delem FP's packet list shrinks from a tween callback ~0.5s after delivery, so the coach read the
old count and said "one down, 2 to go" with two packets total.

**A game whose actor moves on a hand-rolled interpolation does not stop when the game pauses.**
Tweens and timers do; a `_process` that lerps between two points does not. Delem FP's truck drove
on under captions until `agent._process` learned to push its move's start time forward by the
paused duration — which suspends it mid-tile and resumes it without a jump.

**Anything gated on `not game.paused()` will never fire during a talking step.** Delem FP's truck
is dispatched by a timer with that guard, so it simply never arrived while the coach was talking
about it. If a tutorial needs something a paused-gated timer produces, produce it directly.
