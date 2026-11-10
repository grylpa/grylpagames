# Pickpocket: design

## Concept

A street shell game at dusk. Each round the hustler shows the ball under one of his copper cups and
shuffles them. While he does, somewhere around the table a pickpocket lifts someone's wallet. When
the cups stop the whole street **freezes**. The player taps the cup with the ball, then the person
who was robbed. On later levels they may be asked for the pickpocket instead, or the answer may be
"No one". **A round counts only when both answers are right.**

That is the whole point of the game. Following the cups needs the eyes on the table: look away
during a swap and the ball is lost. The theft happens away from the table, so it can only be caught
out of the corner of the eye. It belongs in Attention & Speed, as a dual-attention game.

## Files

```
pickpocket/
├── scripts/
│   ├── globals.gd       # PickpocketG: game util ("Pickpocket", "pickpocket"), settings [level]
│   ├── level_config.gd  # PickpocketLevelConfig: LEVELS (see below)
│   ├── main.gd          # orchestrator (copied from Change): menu, HUD, help, scores
│   ├── level.gd         # rounds, the crowd, the theft choreography, answers, scoring
│   ├── street.gd        # the backdrop, drawn once: shops, road, sidewalk, lamps
│   ├── passerby.gd      # one person, drawn in code, walking or standing
│   └── shell_table.gd   # the table, lantern, cups, ball and the hustler with his hands
├── scenes/ main.tscn, level.tscn
├── art/game_screen_200.png   # devtools/probe_pickpocket_tile.gd, option B: a wallet pinched out of
│                             #   a jeans back pocket (the hand is Noto Emoji, Apache 2.0, credited
│                             #   on the About screen)
└── docs/design.md
```

Everything is drawn in code; there are no images.

## The scene, and why it is laid out this way

From the top: the shopfronts across the road (four shops, lit windows, awnings, signs) with the
**far lane** of people on their sidewalk; the road; the **near lane** on the near sidewalk, walking
just behind the hustler; the hustler behind his table; and the **onlookers**, two at each of the
table's front corners (one each with five cups), facing the cups.

**Everyone is at the scale of their distance.** The far lane is small, the near lane larger, the
hustler larger still, and the onlookers are the largest because they are nearest. An earlier layout
had a lane walking in front of the table at a smaller size than the hustler behind it, which made
the whole scene read wrong. The onlookers answer "who is he playing for?". They stand at the very
edges (`_place_crowd`) because the outermost cup must never be behind one of them.

Light: two street lamps (`street.lamp_xs`) and the hustler's hurricane lantern. Each person is lit by
BOTH lamps, each weighted by how strongly it reaches them, and the side the light comes from is their
blend (`_light_people` sets `light_dir` / `light_amt` every frame). Every one-sided effect on a person
-- the form shadow down the far side, the warm rim, the sleeve's and head's highlights -- is scaled by
how one-sided the light is (`|light_dir|`), so under a lamp they fade out and back in on the other
side. Lit by the single nearest lamp, a walker's lit side flipped in one step halfway between two
lamps and swung across in a few steps under each, so their coat's shading jumped as they passed a
post. Lamp glows and the pools they throw are an additive layer (`_glow`), and an evening
shade darkens the screen's edges and the bottom (`_shade`).

## The look (the 2026-11-10 facelift)

- **Dusk, lit by its lamps and windows.** A deep-blue sky with stars and a moon over a skyline of
  different heights with chimneys; every lit shop window and door lays its light on the far sidewalk
  and a little way onto the road, and glows into the street (`street.window_glows`, drawn additively
  by the level); each lamp has a visible cone down to a pool; the whole scene is tinted a shade
  cooler and darker (`_draw_shade`), so the warm lights are what light it.
- **The street is DRY.** A wet road (every window a reflection in the asphalt) and puddles were tried
  and removed: nothing else in the scene says rain, and the shiny tar read as odd.
- **The scene runs to the very bottom of the screen**, behind the app's bottom bar
  (`full_screen_size`); it used to stop at the play area's edge, leaving a gray band.
- **The near sidewalk is flagstones**, staggered, each a tone of its own.
- **People** (`passerby.gd`): warm light and COOL shadow (`_lit`), a soft form shadow down the far
  side of the body and the back of the head, a warm rim on the lamp's side (shoulder, side, hem,
  head, sleeve), lapels, buttons, a pocket flap, cuffs, a trouser crease and a sole; a face with an
  eye (white, iris, lid), a brow in the hair's color, a nostril, lips, an ear's fold and a sheen on
  the hair. All sizes are shares of `h`, so the far lane stays a few clean pixels. Each casts a long
  shadow away from its lamp. The ONLOOKERS are lit by the hustler's lantern, from the table's side
  (`_light_people`, lane 2) -- under the street lamps alone they were murky at the screen's edges.

- **The hustler** (`shell_table.gd` `_draw_hustler` / `_draw_head`): a showman with a face -- a jaw
  and cheekbones, heavy-lidded eyes on the player with one brow cocked, a nose with a bridge and
  wings, a mustache waxed to two curls over a one-sided smirk, sideburns under a paneled newsboy cap
  with its button. A plum waistcoat with lapels, brass buttons and a watch chain, a red neckerchief,
  sleeves rolled to the elbow under red garters. The lantern lights his near side warm (a rim down
  it); his far side and the far side of his face go to the evening's blue (`COOL`).
- **His shoulders and hands**: shoulders about three heads across (`_body_pose`, 0.84 `hs` each
  side), sloping DOWN from the neck, each under a cap of waistcoat that turns with the arm (below).
  (A "far side in shadow" overlay across his body was removed: its hard edge showed as a stray
  line.) A HAND on each
  cup -- the back of the hand widening to the knuckles, four fingers of their own lengths draped over
  the cup's near edge, the thumb down the inner side (it was an oval with four sticks). The cap's
  peak has an arc for its lower edge: three nearly collinear points there sometimes failed to
  triangulate as he breathed, and the peak flickered.
- **Everyone's hands** (`passerby._draw_arm`): a palm running on from the forearm, the fingers as one
  tapering shape, a thumb on the forward side (they were small ovals).
- **The table**: a shadow on the pavement, worn rings in the baize where the cups stand, a wooden
  front rail with brass corners, the stakes (a note and a short stack of coins) at its far end, and
  on the velvet skirt a gold braid of scallops above the fringe with a tassel at each corner.
- **The lantern lights its corner**: `shell_table.lantern_world()` gives the level the flame, and
  `_draw_glow` lays a wide warm bloom over the table, the hustler and the onlookers.
- **The top bar is the night's**: `main.gd` `_dress_top_bar` recolors the shared HUD's gray strip
  (`BkLabel`) to the sky's navy with a thin gold line, for this game only.

## A round

`IDLE -> PEEK -> SHUFFLE -> FREEZE -> ASK_CUP -> CUP_SHOWN -> ASK_PERSON -> FEEDBACK -> GAP`

1. **PEEK**: the hustler lifts the cup with the ball and sets it down (`tock`).
2. **SHUFFLE**: `swaps` swaps of `swap_ms` each (`slide` as the cups start moving). A swap moves two
   cups along opposite arcs, one in front of the other. A feint (`fake_p`) meets in the middle and
   goes back.
3. **FREEZE**: the whistle. Everyone stops mid-stride; nothing moves until the round ends.
4. **ASK_CUP**: "Where is the ball?" (EVERY line the game says is framed and popped in -- a dark
   pill with a shadow and an edge, `_say`: the two questions at 36 with a gold edge, the result lines
   at 30 with the edge in their own color. Plain, they read like captions and were missed.) Tapping a cup lifts it (`ball` / `empty`). After a wrong cup,
   the right one comes up too.
5. **ASK_PERSON**: "Who was robbed?" (or "Who was the pickpocket?", `thief_q`). Tap a person, or
   "No one" -- offered on EVERY level, also where no round is ever empty: a button that appeared
   only where it could be the answer would say something. On desktop the person under the pointer is ringed. A tap
   is tested against each person's EXACT drawn shapes (`passerby.hit`, the polygons of the last
   draw), frontmost first; only a tap on no body at all falls back to the nearest figure's box. The
   answer tags are drawn on a layer over everything, their pointer ending on the crown
   (`head_top`), and the prompt sits on the table's cloth, where no tag can fall under it.
6. **FEEDBACK**: tags over the victim ("Robbed") and the pickpocket ("Pickpocket"), and over a
   wrong pick ("Your pick"). No two tags ever overlap (`_stack_tags`): the person nearer the viewer
   keeps theirs, the one behind lifts theirs a line at a time until it is clear (`passerby.tag_box`),
   over EVERYONE tagged (`_all_people()`: the onlookers are not among the street's `_people`, and
   stacking only those left a pickpocket and victim both at the table overlapping), plus one line: "Both right! +20", "Found the ball, missed the theft",
   "Caught the theft, lost the ball", "Missed both".

## The theft is choreographed

`_start_round` plans it for a moment inside the shuffle, with time left before the freeze for the
pickpocket to get away. It happens in one of two places.

- **On the street** (`_plan_theft`): it picks a victim already on screen, walking or window-shopping.
  It sends a NEW walker in from behind them at the speed that brings the two together at that
  moment, at a spot where the victim will still be on screen at the freeze. The pickpocket keeps
  pace, reaches into the back pocket (`reach`), and the wallet travels pocket -> hand -> coat. Then
  they walk on, or double back half the time, and stop at a window once they are clear of the
  victim. If nobody suitable is on the street, someone stops to look in a window and is tried again.
- **In the crowd at the table** (`_plan_crowd_theft`, about a third of thefts when there is a pair):
  one onlooker of a pair robs the other without taking a step, EITHER WAY ROUND at random -- the
  edge one from the inner one's back pocket (which faces the edge), or the inner one from the edge
  one's side pocket at the front of the coat (`_steal_point`; the edge one's back pocket faces off
  the screen). It was always the edge one robbing, so an edge onlooker was never the victim.
  An onlooker pickpocket always gets the "Pickpocket" tag, even at the screen's very edge
  (`_thief_on_screen`; a test of a fifth of their height in from the side left them untagged).
  A shell game has always been the pickpocket's cover.

Nothing marks the pickpocket. They come from the same pool of looks, at a walking speed inside the
ordinary range, and blend back in. **The theft makes no sound**, because a sound would tell the
player when to look up. On the easy levels (`cue`) the wallet is bright yellow and the victim
starts at the touch (`jolt`).

**No one carries a visible wallet.** One drawn on everyone would let the player find the victim
afterwards by scanning for the one without it.

## The hustler (shell_table.gd)

- **The hands are never teleported.** Every move has a lead (`LEAD_MS`): the hands ease toward the
  cups they are about to move while the cups wait, then ride them. The next swap is chosen one swap
  ahead (`_pending` / `set_next`), so the hands set off during the gap. At rest the hands lie on
  two of the cups. Resting them beyond the outer cups laid both arms across the row.
- **The body follows the hands by LEANING**: the shoulders keep their width and move together, by
  however much the longer reach is short of an arm's length (`_body_pose`, up to 0.8 `hs`), the
  reaching side's shoulder dips, the head follows the torso, and he breathes. Each shoulder used to
  be dragged toward its own hand: with a hand across the body the torso collapsed into a narrow
  tube and the waistcoat's shapes folded over each other.
- **Nothing on him is thinner than two units.** He breathes (a fraction of a pixel up and down), and
  a feature a pixel thin shimmers as it crosses the pixel grid: the watch chain (now one smoothed
  line 2.2+ wide, no separate glint), the lapels' edges, and a 1-2 px sliver of shirt that showed
  above the waistcoat's top edge along the shoulders and neckline (the waistcoat now covers it).
- **The lean is eased** (`_ease_lean`, `LEAN_RATE` 5/s against the hands' 26): the hands snap back
  to rest in a few frames, and a lean that followed them exactly threw his torso back in a jump.
- **A reach longer than the arm is drawn longer** (up to 1.45x, `_draw_arm`). The hand's outer side
  is a quarter turn from the forearm, the same way round always: choosing it by sign flipped the
  hand over whenever the forearm came level.
- **THE SHOULDER CAP TURNS WITH THE ARM** (`_draw_arm`): the waistcoat covers the half of the joint
  that faces AWAY from the arm -- its inner top for an arm out to the side (the strap), its outer
  top for one reaching across (his shoulder). Everything else was tried and failed: the sleeve's
  bare round end is a pale ball on the dark waistcoat; a strap fixed over it cuts off a crossing arm
  and sits on his chest as a wedge; drawing the strap under a crossing arm shows the ball again, and
  switching between the two orders makes the layers swap mid-move. The cap rotates continuously, so
  nothing swaps.
- **Arms are two-bone limbs, foreshortened**, because a forearm reaching forward looks short from the
  front. Each arm always bends the same way (elbow on its outer side). Choosing per frame flipped
  the elbow across in one frame.
- **He is drawn in his own unit `hs`** (1.25 cup heights): the cups are about two thirds of his
  head (at a cup taller than his head they read as buckets). He STANDS at a waist-high table,
  shoulders well above the cups (`hustler_top` = 3 `hs` above the table), so his arms reach down;
  the torso has sloping shoulders with rounded caps, the sleeves start inside them.
- **With two cups held up** (a wrong pick and then the right one), each hand holds one.
- **The cups are round solids**: strips around the front half follow the rim's curve, shaded by the
  way each faces (`_metal`). The rim bows toward the viewer and the base is a full ellipse. The
  first version was shaded in flat strips with a straight rim and read as a wooden bucket. The
  cups are identical on purpose, so the ball cannot be found afterwards by a mark on its cup.

## People (passerby.gd)

- **Proportions and shading.** Adult proportions, tapered limbs bending at knee and elbow,
  everything shaded by `_lit` (higher is brighter, the lamp's side brighter and warmer).
- **Telling people apart.** People are distinguished by coat color (kept unique on screen), cut,
  hat or hairstyle, bag, skin and height.
- **Standing people are never still** (`tick_idle`). They breathe, shift their weight, lean, glance
  away, and change what their hands are doing (a hand to the chin or on the hip). The onlookers
  lean in while the cups move (`excite`).

## Levels (PickpocketLevelConfig)

| id | cups | swaps | swap_ms | crowd | lift_ms | cue | thief_q | empty_p | fake_p | far | rounds | pass |
|----|------|-------|---------|-------|---------|-----|---------|---------|--------|-----|--------|------|
| 1 | 3 | 4 | 760 | 4 | 1100 | yes | 0 | 0 | 0 | no | 6 | 66 |
| 2 | 3 | 5 | 660 | 5 | 900 | yes | 0 | 0 | 0 | no | 6 | 66 |
| 3 | 3 | 6 | 570 | 6 | 760 | no | 0 | 0 | 0 | yes | 6 | 66 |
| 4 | 3 | 7 | 510 | 6 | 660 | no | 0.3 | 0 | 0 | yes | 8 | 75 |
| 5 | 4 | 7 | 490 | 7 | 570 | no | 0.3 | 0 | 0.15 | yes | 8 | 75 |
| 6 | 4 | 8 | 450 | 7 | 500 | no | 0.35 | 0.15 | 0.2 | yes | 8 | 75 |
| 7 | 4 | 9 | 410 | 8 | 430 | no | 0.4 | 0.2 | 0.25 | yes | 8 | 75 |
| 8 | 5 | 10 | 380 | 9 | 370 | no | 0.4 | 0.2 | 0.3 | yes | 8 | 75 |

`far` (`far_thefts`): whether a theft may happen among the FAR people, on the sidewalk across the
road by the shops. They are small and far off, much harder to notice, so levels 1-2 keep every theft
on the near side of the road or at the table (also the fallback window-shopper, `_start_round`).

`crowd` is the street's walkers. The onlookers are on top of that. `pass_pct` sits on a rung of
the round count: 66 = 4 of 6, 75 = 6 of 8.

## Scoring

- **Points per round:** ball +5, person +10, both +5 more.
- **Counting:** one verdict per round (`add_correct_or_mistake(1, 0)` only when both are right).
- **Level end:** after `rounds` rounds the level is judged on the share of rounds with both
  right. Below `pass_pct` the same level comes again. The card lists both right, ball found and
  street right.
- **No session clock** (`uses_session_clock = false`).
- **Score row:** `[didwin, aborted, level, mean answer time, pct]`. The answer time runs from the
  person question to the tap.

## Sound

- **Effects:** `devtools/make_pickpocket_sounds.py`: slide (-10 dB), tock (-6), whistle (-8), ball,
  empty, right, wrong.
- **Ambient:** `make_ambient_sounds.py` `pickpocket`: a STREET with music in it (2026-11-10; the music
  alone did not sound like a street). The tune (`_caper`: pizzicato bass, finger snaps, a vibraphone
  creeping up in half steps, a low clarinet-like tune) as from a player down the way, under light
  distant chatter (`mu.babble`, low-passed, speech-like and never words), passers-by's footsteps
  (`passer_by`: leather heels and sneakers, coming up and going, often two at once), and now and then
  a laugh, a car, a bicycle bell, a far horn. Played at -6 dB while the table is up. The theft itself
  still makes no sound.

## Tutorial

`pickpocket/scripts/tutorial.gd` (in `MainCfg.tutorials`; first run and "How to play"). One real
round, slowed down (`level._tutorial_setup`: 3 cups, 4 swaps of 950 ms, a 1.5 s theft with the
bright wallet and the victim's start, always in the NEAR lane, never a pickpocket question or an
empty round; rounds never end the level):

1. the hustler and his cups (spotlit); 2. two jobs at once; 3. **watch** (`watch_only`, waits for
`street_frozen`); 4. tap the cup (`cup_picked`); 5. tap who was robbed (`person_picked`);
6. "this is who was robbed" (spotlit, with its tag); 7. "and this is the pickpocket" and the rule
that a round needs both; 8. what changes later, and "No one".

Guarantees the lesson depends on:

- **There is always a theft**, in the lesson and in play alike, unless the round is MEANT to be
  empty (`empty_p`). If nobody can be reached in time (or the table has no pair for a crowd theft),
  a window-shopper is placed mid-street to be robbed, on the near sidewalk or failing that the far
  one (`_start_round`). This was the lesson's rule only: in play such a round quietly became an
  empty one, on level 1 too, where there was then no "No one" to tap.
- **The pickpocket stays in view.** In the lesson they stop as soon as the theft is done, if they are
  within the middle 76% of the screen; one already heading out past that band turns round and walks
  back into it, then stops (`_update_thief`, "away"). Step 7 always has someone to point at. (They
  used to stop only after the getaway delay and only if still inside the band, so one walking
  outward sometimes left the screen before the question.)
- **Tags are drawn before the coach freezes the game.** `person_picked` is notified LAST in
  `_resolve` (and `cup_picked` last in `_on_cup_picked`): notified first, the runner froze the game
  before the tags were set, and the coach pointed at a victim with no "Robbed" over them.
- **No caption covers what its step is about.** Every step lists its zones (`keep_clear`): the
  table, both lanes head to foot, the onlookers, the victim and the pickpocket with their tags; the
  short captions fit in the strip over the shops. The runner now narrows a short caption to its
  text (`scripts/tutorial.gd` `_layout_panel`), for every game.

## The shop signs

Each shop has its own sign, in the manner of its trade (`street.gd` `_shop_sign`): the bakery a cream
board with rounded ends, red lettering (Exo 2) and a loaf painted at each end; the bookshop a deep
green board with gilt capitals spaced wide (Space Grotesk), a double gold rule and an open book at
each end; the florist a white oval with pink lettering (Open Sans) and blooms; the cafe a dark board
with its name in warm neon (Orbitron) beside a steaming cup. They were four identical black boards.
The two street lamps stand at the joints between buildings (`lamp_xs`), never across a sign.
