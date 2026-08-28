# Taxi — design

You own a taxi station. Customers appear around the city, taxis fetch them and drive them to their
destination, and they pay on arrival. Everything else is cost: fuel burns per tile moved and per
second idling, a new taxi costs money, and a taxi that runs dry is gone for the rest of the game.
The score IS the money — the game ends when it reaches zero (`game_over_on_zero_score = true`,
`initial_score = 5000`).

## Files

```
taxi/scripts/
├── globals.gd        TaxiG autoload: starting_level, prices, fuel constants, save/load settings
├── level_config.gd   TaxiLevelConfig.LEVELS — 9 levels, one round each
├── main.gd           orchestrator: menu, HUD, buy-taxi button, saved-game state
├── level.gd          the city: board, taxis, customers, targets, gas stations, pathing
├── agent.gd          one taxi OR one customer (is_taxi tells them apart); fuel lives here
├── target.gd         a building: sender / receiver / gas station, and its lobby + dropoff tiles
├── door.gd, pipe.gd, empty_space.gd, player.gd, tube_animation.gd   board furniture
```

## Board and difficulty

`increase_difficulty()` is the whole progression: level 1 is a 21×21 board with 4 taxis and a
customer every 5 s; by level 6 it is 31×31, and dispatch intervals tighten to 2 s. On mobile the
board is cut by (10, 6) tiles. `game.max_board_size` grows with the level even where
`forced_board_size` is pinned.

## The loop

- **Select then send.** `on_taxi_pressed()` toggles selection (only one taxi at a time). With a
  taxi selected, `on_agent_pressed()` on a waiting customer calls `move_taxi_to_agent()`, which
  assigns the transaction, appends the customer's tile and then the destination tile to
  `taxi.goal_pos`, and A*s a path. Pressing a taxi that already has a transaction CANCELS it.
- **Gas.** `on_clicked_target()` with a gas station and a selected taxi sets `going_to_fill_gas`
  and sends it to the station's `dropoff_pos`.
- **Customers.** `_on_agent_dispatch_timer_timeout()` fires while `start_dispatch` is on, picks a
  free start tile at least 4 away from the last one, and `add_mission()` pairs a sender building
  with a random receiver, colors both, and spawns the customer.
- **Money.** `score_delivered_passenger()` is +200 (and +10 s); picking up scores separately;
  buying a taxi costs `TaxiG.prices_for_taxi` (5000) and adds a life.
- **Fuel.** `agent.gd` burns `dt / tile_size / num_tiles_for_empty_fuel_tank` while moving and
  `time_idle_ms / time_to_empty_fuel_tank_on_idle_sec` while stopped — so a parked taxi with its
  motor running still drains. At zero, `out_of_gas` latches and that taxi never moves again.

## Turning

`agent.gd::set_rot()` keeps `angles[0]` as the logical heading (the body segments trail off it) and
tweens a separate `_head_angle` that the sprite is drawn from, over `TURN_TIME_SEC` (0.12 s) and
always the short way round. `_process` applies it every frame: `set_rots()` does not run on a
standing taxi, so applying it only there left a stopped taxi snapping to its new heading.

## Saved game

Taxi is the only game with a full mid-game save: `main.gd::save_game_state()` writes
`$Level.get_state()` through `SaveManager` every `TaxiG.dtime_to_save_state_ms` (30 s), on focus
loss, on help, and on returning to the menu. `main_menu.show_continue_and_start_new()` offers
Continue when that file exists. `get_state()` returns `{}` when `can_use_state` is false, which is
how a finished game stops being resumable.

**This save is outside `GenericGameUtil`, so none of its tutorial guards cover it.** See below.

## Tutorial

`taxi/scripts/tutorial.gd`, entry `taxi/scripts/main.gd::start_tutorial()`. Taxi is the game whose
instruction text is longest in the app (eight numbered rules, ~580 characters) and almost none of
it is observable: fuel cost per tile, idle cost, "stranded forever", customers giving up. Those are
learned by losing, which is exactly what a tutorial is for.

What it does that is specific to this game:

- **The saved game is protected.** `save_game_state()` returns early in `tutorial_mode`, and
  `_restore_tutorial_globals()` puts the player's own state back into the level afterwards, so
  neither the file nor the in-memory "Continue" is disturbed by a tutorial.
- **Dispatch is held** (`tutorial_hold_dispatch`) and customers are produced on demand by
  `tutorial_request_customer()`, so a lesson never has to wait out the 5 s timer or get buried by
  arrivals it did not ask for.
- **The city has one taxi** (`_tutorial_setup` sets `num_of_taxis = 1` before `create_board`).
  `can_go_to()` only refuses a tile occupied by another taxi, so with a single taxi no jam is
  possible — a taxi blocked mid-fare used to deadlock the lesson, and clearing it is rule 3, which
  the tutorial does not teach until its last step. `tutorial_unblock()` remains as a net for a
  player who buys a second taxi during the tutorial.
- **Fuel does not move at all.** Both burn rates (`time_to_empty_fuel_tank_on_idle_sec` and
  `num_tiles_for_empty_fuel_tank`) are set out of reach for the duration and restored afterwards,
  so the tank sits wherever the lesson put it however long the player takes. Idle burn alone was
  not enough: driving to the pump burns by the tile, and a stranded taxi cannot even be tapped.
- **The refuel is watched, not just ordered.** `sent_to_gas` fires on the tap, so the coach used to
  move on while the taxi was still driving — the player never saw it arrive or fill. A step now
  waits for `gas_filled` (from `on_finished_filling_gas`). It also says the taxi turns green while
  filling: `activate_gas_station_anim()` sets `modulate` to green, on a city whose clear colour is
  dark green, and players read that as the taxi having disappeared.
- **No timeouts on the steps that wait for the player.** A 120 s limit on the pump step silently
  advanced a slow player to "Ready", so their next tap appeared to produce the wrong text. Skip and
  ESC remain the way out.
- **Fuel is staged.** `tutorial_drain_taxi()` drops one taxi's tank low so the fuel lesson has
  something real to point at instead of describing a bar that is nearly full.
- Events reported to the coach: `taxi_selected`, `customer_assigned`, `picked_up`, `delivered`,
  `sent_to_gas` — all `game.tutorial_notify`, no-ops outside tutorial mode.

## The lawn

The ground is ONE continuous field of drawn grass over the whole board — `scripts/grass_field.gd`,
shared by the eleven grass games — not a tile. `level.gd`'s `_fit_ground_to_board()` is the whole
installation:

```gdscript
GrassField.fit(self, get_node_or_null("TextureRect") as CanvasItem, game, 20)
```

It hides the tiled `TextureRect` it replaces, attaches a `GrassField` control to the Level layer itself, as its first child so it
draws behind everything, sizes it to the board plus a four-tile margin (merged with the full canvas,
so a board smaller than the screen still has grass to the edges), and sows it. The seed is this
game's own — 20 — so no two games show the same field.

It is called twice: at the end of `_ready()`, so the lawn is already there before the first board is
built, and at the START of `create_board()`, for a level that changes the board's size. `fit()`
re-sows only when the rect actually changed, because the field is a `MultiMeshInstance2D` of tens to
hundreds of thousands of blades and building it is not something to redo between rounds.

Every empty cell used to carry its own 40x40 `grass.png`; `empty_space.gd`'s `_ready()` now hides it.
That per-cell sprite was the real reason the board looked tiled — the background alone was never
it — and the per-cell random rotation some of these games applied made it worse, because the tile
wraps seamlessly and turning a cell breaks the wrap.

`probe_lawn.gd` checks all eleven: the field exists, is the first child of its layer, is sown before
any board is built, covers the board and the canvas, retires the tiled ground only once it has
something in it, and that no cell shows its own grass again.
