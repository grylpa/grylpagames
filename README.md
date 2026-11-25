# Nomizo

More than thirty short brain teasers: puzzles, memory and reflexes, each game its own little illustrated world.
Built with Godot 4.7 for Android, desktop (Windows, Linux) and the web. Portrait (680x788). No accounts, no ads,
nothing collected: it plays fully offline as a guest.

## Play it

- Web: https://grylpa.com/games/nomizo/ (each game also has its own link there)
- Android: https://play.google.com/store/apps/details?id=com.grylpa.nomizo
- itch.io: https://grylpa.itch.io/nomizo

## Games

**Brain twisters**
- **Aliens** — work the gates of an alien spaceport and let the right travelers board
- **Sorting Robots** — sort parcels on a depot belt by hidden rules
- **Pockets** — send each rolling ball into the right pocket of a billiard table
- **Change** — pay the exact amount from a pile of coins
- **Tip the Scales** — weigh the crates with nothing but balance scales

**Attention & speed**
- **Gorilla** — eat apples and rescue the lost baby gorillas
- **Pickpocket** — follow the ball under the cups, and catch the pickpocket
- **Wolves** — guard your flock from the wolves
- **Pinpoint** — catch the courier and the lookout in a flash of lightning

**Memory & speed**
- **Dino** — say whether you have seen the card before
- **Dino N-Back** — does this card match the one N cards back?
- **Moving Cards** — remember cards that move
- **Mosaic** — rebuild the picture, faster every round
- **Lighthouse** — the beam shows the rocks for a moment; remember them and sail through the dark

**Planning**
- **Taxi** — run a taxi station: fetch the customers, watch the fuel, keep the business alive
- **Storm** — save your house from the storm
- **Valet** — switch the junctions to get every car to its spot
- **Pneumo** — manage the pneumatic tube deliveries
- **Detour** — keep the monsters from reaching their goals
- **Ants** — keep the colony from carrying the food home

**Reflexes**
- **Whack** — tap quickly and accurately, and avoid the decoys
- **Nudge** — nudge every ball into its own basket
- **Typit** — how fast and accurately can you type?

**Recognition**
- **Couples** — find the two identical cards
- **Friends** — recognize your friends on an evening stroll
- **Weris** — find people in a crowd
- **Polka Dots** — identify the scatter of dots

**Memory & navigation**
- **Mind Palace** — open the vault in every room of a castle, then remember where each treasure was
- **Lights Out** — remember your path, goal and obstacles in the dark
- **Dispatch** — remember the delivery order
- **Headlights** — deliver the packets in order while zoomed in

Some older games are still in the source but hidden (`HIDDEN_GAMES` in `scripts/config.gd`). The list of games
and their categories is `MainCfg.games` in the same file.

## Tech

- **Engine**: Godot 4.7, GDScript, Compatibility renderer
- **Platforms**: Android, Windows and Linux desktop, Web (HTML5)
- **Saves**: versioned binary files under `user://` (`.gry`)
- **Backend**: optional Supabase score sync, off by default (`use_BE = false`): nothing leaves the device
- **Web build**: a base pack plus one pack per game, fetched the first time that game is opened. The editor plugin
  `addons/web_pack_split` splits every Web export by itself (a `nomizo.pck` of ~50 MB means it did not run).

## Project structure

```
main/                   Godot project root (open project.godot in the editor)
├── scripts/            shared code and autoloads (MainGlobals, MainCfg, SaveManager, GenericGameUtil, ...)
├── scenes/             shared scenes (game chooser, menus, overlays)
├── art/                shared graphics and ALL sounds
├── shared/             shared game pieces (the card, ...)
├── {game}/             one folder per game: scripts/, scenes/, art/ (graphics only), docs/design.md
├── addons/
│   ├── ver_tools/      version bump
│   └── web_pack_split/ splits the Web export into per-game packs
├── docs/               cross-game docs (tutorials.md, ...)
└── export/             zip.sh (packages every platform's export) and itch.sh (the itch.io upload)
```

Each game's `docs/design.md` describes how it works. `how_to_add_a_new_game.txt` is the checklist for a new one.

## Building

Export from the editor (Project > Export), then in `export/`:

```sh
./zip.sh     # zips each platform's export; makes web/index.html
./itch.sh    # the web build as an itch.io upload (after zip.sh)
```

The export presets are not in this repository; set them up in the editor's Export dialog.

## Disclaimer

This project is a personal software experiment, is in its alpha stage and not ready for production.

It is not medical advice, cognitive training, therapy, diagnosis, or a proven method for preventing or treating any condition. Any references to memory, attention, learning, brain challenge, or similar ideas describe the design goals and personal motivation behind the project, not scientifically validated claims.

The software is provided as-is, with no warranty or guarantee of correctness, reliability, safety, availability, or fitness for any particular purpose. Use it at your own discretion.

The games are intended for entertainment and personal challenge only. They are not designed or validated to measure, diagnose, improve, or preserve cognitive ability.

## License

The code is MIT; see [LICENSE](LICENSE).

Not all the assets are the project's own to license: some sounds were bought, the fonts keep their own licenses
(SIL OFL and others), and the cardboard texture is CC0. Ask (info@grylpa.com) before reusing any art, photo or
sound outside this project.

## Attribution

Created by grylpa.

## Contact

info@grylpa.com
