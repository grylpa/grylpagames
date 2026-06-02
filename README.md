# Nomizo

A collection of mini-games built with Godot 4.6, targeting Android, desktop, and web. Portrait orientation (680×788). No accounts required — plays fully as a guest.

## Games

**Serenity / Breathing**
- **Breathe** — tap to breathe along a visual guide; tracks your rhythm on a graph
- **Crack the Safe** — follow a breathing pattern (inhale / hold / exhale) to open a vault
- **Mother** — draw a shape that matches a breathing-pace curve; a child shape mirrors you
- **River** — guide a boat down a river by breathing in time with the current
- **UDBR** — up / down / breathe / rest; four-quadrant guided breathing drill

**Attention / Reflexes**
- **Sorting Robots** — two conveyor belts, two hidden rules; swipe to keep or discard each item
- **Whack** — classic timing and reaction game
- **Weris** — colour-word Stroop variant; pick the ink colour, not the word
- **OOO** — one of these things is not like the others
- **RL Madness** — left/right split-attention task
- **Pop** — tap the right bubbles before they drift off screen

**Memory / Matching**
- **Match WS** — vocabulary pair matching; supports multiple languages
- **Moving Cards** — memory card-flip game with moving cards
- **Polkadots** — remember the dot pattern, then reproduce it
- **Faces** — match face pairs; expressions and identities change between glimpse and recall

**Planning / Reasoning**
- **DIDI** — shape-selection puzzle with a fixed number of correct picks
- **DDOOO** — extended shape variant of DIDI
- **Wolves** — logic deduction over a grid of hidden wolves and sheep
- **Lights Out** — classic toggle-neighbour lights puzzle
- **Gorilla** — brick-clearing physics puzzle with a gorilla and coins

**Other**
- **Storm** — manage leaks with the right tools before the boat sinks
- **Guidem** — guide characters through a maze; plan the path before they move
- **Taxi** — route a taxi to pick up and drop off passengers
- **Monkey C** — pattern completion / sequence game
- **MMM** — timed multi-modal memory task

## Tech Stack

- **Engine**: Godot 4.6 (GDScript)
- **Platforms**: Android, Linux/Windows desktop, Web (HTML5)
- **Save format**: versioned binary files under `user://` (`.gpa` extension)
- **Backend**: optional Supabase score sync; defaults to guest-only mode (`use_BE = false`)

## Project Structure

```
braingames/
├── main/               # Godot project root (open this in the editor)
│   ├── project.godot
│   ├── scripts/        # Shared autoloads (MainGlobals, BE, SaveManager, …)
│   ├── art/            # Shared art and sounds (all sounds live here)
│   ├── scenes/         # Shared scenes (GameChooser, menus, overlays)
│   ├── {game}/         # One folder per game
│   │   ├── scripts/
│   │   ├── scenes/
│   │   ├── art/        # Game-specific graphics only
│   │   └── docs/
│   │       └── design.md
│   └── addons/
│       └── ver_tools/  # Version-bump plugin
└── export/             # Built export artefacts (git-ignored)
```

## Disclaimer

This project is a personal software experiment.

It is not medical advice, cognitive training, therapy, diagnosis, or a proven method for preventing or treating any condition. Any references to memory, attention, learning, brain challenge, or similar ideas describe the design goals and personal motivation behind the project, not scientifically validated claims.

The software is provided as-is, with no warranty or guarantee of correctness, reliability, safety, availability, or fitness for any particular purpose. Use it at your own discretion.

The games are intended for entertainment and personal challenge only. They are not designed or validated to measure, diagnose, improve, or preserve cognitive ability.
