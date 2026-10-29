# Scores, speed table and chart (shared)

How the shared stats screen and score saving behave for every game (`scripts/scores_list.gd`,
`scripts/chart_control.gd`, `scripts/generic_game_util.gd`). This used to live in RL Madness's
design doc, which went when that game was removed (2026-10-29); the games' docs point here now.

- **Monotonic mode (scores table)**: iterates stored scores oldest→newest; includes a row only when its score exceeds all previously included scores; result displayed newest/highest on top.
- **Monotonic mode (speed table)**: same logic but criteria is avg time < previous best (smaller = better).
- **Font size in scores table**: reduced font (size 22) applied to date + level columns only for games that set `game.show_scores_level_as_name = true` in their `_ready()`. Games whose levels have names set it (Dino, Dino N-Back, Couples, Mosaic, Aliens, Apprentice, Sorting Robots, Bucket Madness, Nudge, Change, Lighthouse); games with numeric level columns (e.g. ddooo) do not. All rows in the same list use the same font size regardless of individual name length.
- **% Correct column**: added to speed table when `progress_pct_pos >= 0`.
- **Default label text**: `grid_date_label.tscn` has a placeholder text "123" in its Label node. `scores_list.gd` explicitly clears the level label (`level_label.text = ""`) for rows where no level/pct text is provided, preventing the placeholder from showing.
- **Chart tab**: third tab in the stats screen (visible for all games). Custom line+dot chart via `scripts/chart_control.gd` using Godot's `_draw()` API. Three metrics via a segmented pill control (amber = active) below the chart. X-axis: `#` (game index, default) or `D` (date), toggled by a `D/#` switch (dark capsule, orange dot) to the right of the pills; mode persisted per game in `MainGlobals.chart_x_mode_by_game`. Empty chart shows a stub grid with "No data yet" and metric-appropriate Y range. Tab bar matches the bottom pill bar in style (dark panel `Color(0.14,0.14,0.17)` with top-rounded outer corners `r=14`, active tab amber fill `r=12`, inactive transparent; 38px side margins). Tab preference ("scores"/"speed"/"chart") persisted in `MainGlobals.progress_tab_by_game`; backward-compatible with old bool values.
- **score_was_changed flag** (`GenericGameUtil`): both `save_ongoing_score` and `save_score` are skipped when `score == initial_score` throughout the session. Set to `true` by `add_score_and_time` when `score != initial_score`; reset to `false` by `reset(from_scratch=true)`.
