# Sorting Robots — design

Two conveyor belts run down the screen, each with its **own rule** written at its head. Items scroll
past on both. Every so often a frame closes around one item, and you judge that item against the
rule of **the belt it is on**: swipe right to pick it up (yes, it matches), left to leave it (no).
A correct pick-up sends a robot claw out to yank the item off that side.

Then the thing the game is really about: **after a few rounds the rule labels fade away** and you
have to keep both rules in your head.

## Files

```
sortingrobots/scripts/
├── globals.gd        SortingRobotsG autoload: starting_level, save/load settings
├── level_config.gd   levels: the RULE POOL, hide_after, rounds, window_dur, belt_spd
├── main.gd           orchestrator: menu, HUD, instructions
├── level.gd          belts, item generation per rule, the judging window, claw, scoring
├── claw.gd           the arm that pulls a correctly picked item off its side
├── belt_edge.gd      belt trim
```

## Rules and pairing

`level_config.gd` lists a **pool** per level; the two rules actually shown are drawn from it at
random each time the level loads, so which rules appear and which belt each lands on varies between
plays. Rule keys: `digit`, `square`, `even_odd`, `vowel`, `prime`, `filled`, `hollow`, `stroop`,
`color_shape`, `lines`.

`_are_confusable()` keeps overlapping rules apart — a filled square satisfies both "is it a square?"
and "is it filled?", so those two are never shown together. A pool may safely contain both.

## A round

1. `_open_window()` picks a belt at random and frames an item that is still entering from the top,
   preferring one whose truth balances the yes/no spread so far. `window_target_truth` is whether
   that item satisfies THAT belt's rule.
2. The player swipes (or uses arrow keys) — `_input` → `_evaluate_answer(user_picks_up)`.
3. `_score_answer()` scores it: a speed bonus on top of 10 for a right call, a small penalty for a
   wrong one or a timeout at `window_duration`.
4. After `rounds_before_hide` judgments, `_hide_labels()` fades both rule labels to alpha 0.

## Tutorial

`sortingrobots/scripts/tutorial.gd`, entry `sortingrobots/scripts/main.gd::start_tutorial()`.

Two things make this game confusing on first contact, and neither survives being written in a
paragraph:

- **The framed item is judged against its OWN belt's rule**, not against whichever rule you happen
  to be reading. With two rules on screen it is natural to check the wrong one.
- **The rules disappear.** It happens six rounds in, just as the player has settled, and reads as
  the game breaking rather than as the point of it.

So the tutorial names the belt and its rule at the moment the frame appears (the caption is built
from the live label text), and then makes the labels vanish deliberately, with the coach present to
say what just happened.

Specific to this game:

- Level 1's pool is `digit` / `square` — two rules a first-timer can hold without effort.
- `window_duration` is pushed out of reach for the tutorial and restored: judging under a 3 s clock
  while reading a caption is not a fair introduction.
- `rounds_before_hide` is pushed out too, so the labels vanish exactly when the coach says so
  rather than mid-explanation.
- **The belts stop for the tutorial.** `_open_window()` deliberately frames an item that is still
  ABOVE the belt so the frame slides in with it — which during a tutorial puts the frame over the
  rule label, reading as though the RULE were framed. In tutorial mode the belts run on until the
  framed item clears the label, then `tutorial_hold_belts` stops everything and `window_settled` is
  reported; the hold lifts when the judgment is made.
- **The staging is never announced.** The second judgment is forced to be a non-match, but the
  caption does not say so: it is written before the item has even been chosen, so a promise made
  there is one the tutorial cannot keep by itself. The player judges for themselves; the staging
  only guarantees they meet both answers.
- **The player meets both answers.** `_open_window()` only PREFERS a truth that balances the yes/no
  spread, so two "leave it" rounds in a row are perfectly possible and a player could finish having
  never picked anything up. `tutorial_want_truth` makes the first judgment a match and the second a
  non-match, and while it is set the picker waits for an item of that kind rather than settling for
  whatever is closest.
- Events reported to the coach: `window_opened`, `window_settled`, `judged`, `labels_hidden` — all
  `game.tutorial_notify`, no-ops outside tutorial mode.
