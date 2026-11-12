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
- **No top bar**: the shared HUD has none any more (`generic_game_hud.gd` `_clear_top_bar`, all games),
  and the night sky, its stars and the evening shading run on up to the very top of the screen behind
  the counters (`street.gd`, `_draw_shade`). `main.gd` `_dress_top_bar` moves the level label up into
  the strip's free left end (`hud.move_level_label_to_strip()`): below the strip, over the roofs, it
  crowded the street.
- **The prompt is set in the app's reading face** (`MainGlobals.get_text_font()`, as the HUD's level
  label), not the theme's display face, whose capitals read badly as a sentence.

## A round

`IDLE -> PEEK -> SHUFFLE -> FREEZE -> ASK_CUP -> CUP_SHOWN -> ASK_PERSON -> FEEDBACK -> GAP`

1. **PEEK**: the hustler lifts the cup with the ball and sets it down (`tock`).
2. **SHUFFLE**: `swaps` swaps of `swap_ms` each (`slide` as the cups start moving). A swap moves two
   cups along opposite arcs, one in front of the other. A feint (`fake_p`) meets in the middle and
   goes back.
3. **FREEZE**: the whistle. Everyone stops mid-stride; nothing moves until the round ends.
4. **ASK_CUP**: "Where is the ball?" (EVERY line the game says is framed and popped in -- a dark
   pill with a shadow and an edge, `_say`: the questions on two lines at 30 (`QUESTION_FS`, see "The questions") with a gold edge, the result lines
   at 30 with the edge in their own color. Plain, they read like captions and were missed.) Tapping a cup lifts it (`ball` / `empty`). After a wrong cup,
   the right one comes up too.
5. **ASK_PERSON**: "Who was robbed?" (or "Who was the pickpocket?", `thief_q`). Tap a person, or
   "No one" -- offered on EVERY level, also where no round is ever empty: a button that appeared
   only where it could be the answer would say something. On desktop the person under the pointer is ringed. A tap
   is tested against each person's EXACT drawn shapes (`passerby.hit`, the polygons of the last
   draw), frontmost first; only a tap on no body at all falls back to the nearest figure's box. The
   answer tags are drawn on a layer over everything, their pointer ending on the crown
   (`head_top`), and the prompt sits on the table's cloth, where no tag can fall under it. The
   prompt is sized by `_place_prompt`: one line if it fits, else wrapped inside the screen. Its
   word-wrap is ALWAYS on and its size set twice (now, and deferred): switched on only for long
   lines, a long result after a short one kept the short state's unwrapped minimum width and ran
   off a phone's screen.
6. **FEEDBACK**: tags over the victim ("Robbed") and the pickpocket ("Pickpocket"), and over a
   wrong pick ("Your pick"). No two tags ever overlap (`_stack_tags`): the person nearer the viewer
   keeps theirs, the one behind lifts theirs a line at a time until it is clear (`passerby.tag_box`),
   over EVERYONE tagged (`_all_people()`: the onlookers are not among the street's `_people`, and
   stacking only those left a pickpocket and victim both at the table overlapping), plus one line: "Both right! +20", "Found the ball, missed the theft",
   "Caught the theft, lost the ball", "Missed both".

## The theft is choreographed

`_start_round` plans it for a moment inside the shuffle, over `THEFT_DONE_MS` (0.25 s) before the
freeze. No time is kept for a getaway (until 2026-11-12, 1.2 s was). It happens in one of two places.

- **On the street** (`_plan_theft`): it picks a victim already on screen, walking or window-shopping.
  It sends a NEW walker in from behind them at the speed that brings the two together at that
  moment, at a spot where the victim will still be on screen at the freeze. The pickpocket first
  walks right behind the victim for `tail_ms`, keeping pace (the hand went in the moment they
  caught up, which was too quick to see), then reaches into the back pocket (`reach`), and the
  wallet is drawn out and carried to their own pocket (see "The grab" below). Then ANYTHING, as an
  onlooker at the table never leaves either: they stop right there (30%), double back the way they
  came (35%) or walk on (35%), and a walker stops at a window once clear of the victim (the lesson's
  pickpocket never just stops: it must be pointed out on screen). If nobody suitable is on the street, someone stops to look in a window and is tried again.
  **The meeting is timed by choosing a moment and working out the speed** (7 moments across the
  window, speeds 0.85-1.45 of a walk); it tried five fixed speeds and hoped one landed in the window,
  and once `tail_ms` narrowed it (level 1: under 0.2 s) rounds quietly came out with no theft. The window
  starts 6% into the shuffle and ends `tail_ms + lift_ms + THEFT_DONE_MS` before the freeze. A fallback
  window-shopper faces away from the nearer edge, so the pickpocket comes from there; and if the
  street still cannot be timed, the theft happens at the table (`_plan_crowd_theft` /
  `_plan_corner_theft`) -- a round is empty only when it was meant to be.
- **In the crowd at the table** (`_plan_crowd_theft`, about a third of thefts when there is a pair):
  one onlooker of a pair robs the other without taking a step, EITHER WAY ROUND at random -- the
  edge one from the inner one's back pocket (which faces the edge), or the inner one from the edge
  one's side pocket at the front of the coat (`_steal_point`; the edge one's back pocket faces off
  the screen). It was always the edge one robbing, so an edge onlooker was never the victim.
  An onlooker pickpocket always gets the "Pickpocket" tag, even at the screen's very edge
  (`_thief_on_screen`; a test of a fifth of their height in from the side left them untagged).
  A shell game has always been the pickpocket's cover.
- **How many onlookers** (`_crowd_per_side`): two a side wherever the inner one stands clear of the
  outer cup -- every level on a desktop, five cups included. ONE a side only where a pair would hide
  a cup: five cups on a phone, where the people are far larger beside the cups.
- **At a corner with ONE onlooker** (`_plan_corner_theft`, the same third of thefts): there is no
  pair, and without this the onlookers -- the nearest, largest figures -- were never robbed there. The theft comes FROM THE SIDE: an ARM in a coat reaches in from beyond the
  screen's edge, behind the onlooker, to the back pocket (which faces that edge), takes the wallet
  and withdraws (`_hand_theft`, drawn by `_draw_hand_theft` on `_hand_node`, over the crowd and under
  the wallet; `_hand_reach` eases it in, holds, and out over `lift_ms * HAND_MS_K`). Nobody's whole
  figure is seen, so `_thief` is null and the round never asks "who was the pickpocket?". (A walker
  STEPPING DOWN from the near sidewalk to the onlooker was tried first and turned down: anyone coming
  forward to the table is far too easy to notice.)
- **A lone onlooker stands IN from the edge** (`_place_crowd`; pushed in on a desktop with no one
  added, the space was wasted, so a desktop keeps its pairs instead): as far in as the outer cup allows --
  `ONLOOKER_FRONT` of their height clear of it, plus `ONLOOKER_GAP` -- so their back pocket and the
  arm reaching for it are on screen, and never a cup hidden. On a phone the onlookers are much larger
  beside the cups and there was no room, so `_layout` holds the row in (`ShellTable.max_row_half`) and
  shrinks the cups a little when the row would crowd (`cup_k`; the hustler and the table keep their
  size). Desktop needs neither.

Nothing marks the pickpocket. They come from the same pool of looks, at a walking speed inside the
ordinary range, and blend back in. **The theft makes no sound**, because a sound would tell the
player when to look up. On the easy levels (`cue`, levels 1-2) the wallet is bright yellow and the
victim STARTS at the touch (`jolt`): once the wallet is out of the pocket the whole figure rises
5% of its height and settles (`_bob`), up on the toes -- a startle, a second cue for where to look.

**The grab is one continuous move** (`_lift_wallet`, 2026-11-12, from a frame-by-frame strip): over
`lift_ms` the hand goes to the pocket (to 0.30), draws the wallet UP out of it -- only the part above
the pocket's mouth shows, `_wallet_clip` (to 0.50) -- carries it in its fingers to the thief's own
coat pocket at the front hip (`stash_point`, to 0.78), pushes it down in (to 0.90) and goes back to
rest. The wallet hangs from `grip_point` with the fingertips drawn over its top, so it is always
HELD; it is a real wallet's size (`WALLET_W`/`WALLET_H`, 0.085 x 0.06 of a height -- it was twice
that). The arm from the edge does the same up to the pull and then carries it out of the picture.
Before, the wallet appeared whole beside the pocket before the hand arrived, glided to meet it,
jumped to the thief's chest and hung there in the air while the hand went back.

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
- **The ball** (`_draw_ball`) has a radius of 0.25 `cup_w` (it was 0.18, too small to spot at a glance
  under a lifted cup), so it is about half the cup's mouth across.

## People (passerby.gd)

- **Proportions and shading.** Adult proportions, tapered limbs bending at knee and elbow,
  everything shaded by `_lit` (higher is brighter, the lamp's side brighter and warmer).
- **Nothing on a person changes in one frame** (`tick_motion`, 2026-11-12, called for everyone every
  live frame). A head turning for a glance back narrows about its center to 60% and widens the other
  way (`_glance`, `TURN_S` 0.24 s); a figure turning on the spot (a pickpocket doubling back) does the
  same to 55% (`_face`); setting off and stopping blend stride and stance, the arm swing, the standing
  poses and the lean over 0.3 s (`_gait`). Each used to switch in a frame. A deeper squash (30%) was
  tried and left a paper sliver mid-turn: a person seen from the front is wider, not thinner.
- **A glance back is a moment**: anyone, standing or walking, now and then looks back over their
  shoulder for 0.5-1.1 s (not an onlooker watching the cups, not the pickpocket at work). It was one
  of the standing fidgets, held until the next change of pose, so one caught as they set off kept
  the head turned for the whole walk.
- **The body is seen from the side** (`DEPTH` 0.68, 2026-11-12): the head, legs and arms always were,
  but the coat was a front view's breadth (0.22 of the height across the shoulders), so everyone
  looked barrel-chested. Every torso measure across the figure, the pockets (`pocket_point`,
  `stash_point`, level.gd's `_steal_point`) and the lighting's side scale by it.
- **The near arm has an edge** (`_draw_arm`, 2026-11-12): a dark contour round the sleeve and the
  hand, and the sleeve a shade LIGHTER than the coat. It was the coat's own color lying on the coat,
  so an arm in front of the body vanished into it and a hand going for a pocket was never seen to
  move. The hands are a quarter larger than they were. The far arm, behind the body, has no edge.
- **Elbows are SOLVED, never placed** (`_elbow_for`, 2026-11-12): two-bone IK from the shoulder and
  the hand at the arm's true lengths (`UPPER_ARM` 0.165, `FOREARM` 0.15 of a height), the elbow always
  behind and below the shoulder-hand line for the way the person faces. Each pose used to place its
  own elbow: the hand on the hip bent it backwards, and blends between poses could swing it across.
  The arm from the screen's edge (`_hand_points`) is solved the same way, its shoulder an arm's reach
  behind the hand but never on screen (it was a hose, a stub growing to twice an arm's length).
- **Telling people apart.** People are distinguished by coat color (kept unique on screen), cut,
  hat or hairstyle, bag, skin and height.
- **Standing people are never still** (`tick_idle`). They breathe, shift their weight, lean, glance
  away, and change what their hands are doing (a hand to the chin or on the hip). The onlookers
  lean in while the cups move (`excite`).

## Levels (PickpocketLevelConfig)

| id | cups | swaps | swap_ms | crowd | lift_ms | tail_ms | cue | thief_q | empty_p | fake_p | far | rounds | pass |
|----|------|-------|---------|-------|---------|---------|-----|---------|---------|--------|-----|--------|------|
| 1 | 3 | 4 | 760 | 4 | 1500 | 600 | yes | 0 | 0 | 0 | no | 6 | 66 |
| 2 | 3 | 5 | 660 | 5 | 1400 | 550 | yes | 0 | 0 | 0 | no | 6 | 66 |
| 3 | 3 | 6 | 570 | 6 | 1300 | 500 | no | 0 | 0 | 0 | yes | 6 | 66 |
| 4 | 3 | 7 | 510 | 6 | 1200 | 450 | no | 0.3 | 0 | 0 | yes | 8 | 75 |
| 5 | 4 | 7 | 490 | 7 | 1100 | 400 | no | 0.3 | 0 | 0.15 | yes | 8 | 75 |
| 6 | 4 | 8 | 450 | 7 | 1000 | 350 | no | 0.35 | 0.15 | 0.2 | yes | 8 | 75 |
| 7 | 4 | 9 | 410 | 8 | 950 | 300 | no | 0.4 | 0.2 | 0.25 | yes | 8 | 75 |
| 8 | 5 | 10 | 380 | 9 | 900 | 300 | no | 0.4 | 0.2 | 0.3 | yes | 8 | 75 |

**The theft's pace** (2026-11-12, "too fast"): `lift_ms` -- the reach in, a hold at the pocket, the
hand out -- was 1100 down to 370 ms, a blink on the upper levels; it is now 1500 down to 900. The
arm from the screen's edge takes `HAND_MS_K` (1.5) times it, the crowd thefts exactly it, and a street
pickpocket adds `tail_ms` of walking behind the victim first. **One knob moves them all:**
`PickpocketLevelConfig.THEFT_PACE` multiplies every `lift_ms` and `tail_ms` (1.0 now; higher is
slower and easier to notice). The longest theft fits the shortest shuffle with room to spare.

`far` (`far_thefts`): whether a theft may happen among the FAR people, on the sidewalk across the
road by the shops. They are small and far off, much harder to notice, so levels 1-2 keep every theft
on the near side of the road or at the table (also the fallback window-shopper, `_start_round`).

`crowd` is the street's walkers. The onlookers are on top of that. `pass_pct` sits on a rung of
the round count: 66 = 4 of 6, 75 = 6 of 8.

## The questions

**Two short lines, a size smaller** (`QUESTION_FS` 30, 2026-11-12): "Where is / the ball?", "Who was /
robbed?", "Who was the / pickpocket?". On one line at 36 the pill ran across the onlookers at the
table's front corners on a phone -- over their coats, near their back pockets; two lines make a
narrow pill that stands between them. (Result lines stay one line at 30.)

## The "No one" button

- **A button, not a caption** (2026-11-12): solid app gold (`ScreenBackdrop.ACCENT`) with dark ink, a
  deeper gold lip along its bottom and a shadow; pressed, it sinks onto its lip. It was a dark pill
  with a gold edge and gold letters -- the question's own pill -- and read as one more line of text.
- **Never over anyone** (`_place_noone`, when the question is asked; the street is frozen then): the
  first spot whose box touches no one's `body_rect` (grown 6) -- the road between the sidewalks; the
  band of shop fronts above the far sidewalk, where nobody stands; under the question. It used to sit
  at a fixed spot on the road, where the near sidewalk's heads and hats reach up into it. On a phone
  the near people are tall enough that it usually goes to the shop fronts.

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

## The level card (2026-11-12)

The card before a level holds its FACTS only: `Cups`, `Asks for the thief: Sometimes` (levels with
`thief_q`), `No theft at all: Sometimes` (levels with `empty_p`), `Rounds`. "Follow the ball under the
cups, and keep an eye on the street" was repeated on every card; it is the instructions screen's, which
now also says that later levels sometimes ask for the pickpocket instead.
