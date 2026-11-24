# DRAA — دراع
**Arabic-first 3D party + fantasy fighting game (Godot 4.x, Android-first).**
One magical combat arm. Funny, competitive, chaotic with friends.

## Playable slice (v0.1)
Arabic 3D menu → fighter select (4 fighters) → Volcano Temple arena →
1v1 vs bot → best-of-3 → results + titles + XP. Mobile touch HUD included.

## Open in Godot
1. Install **Godot 4.3+** (standard, not .NET).
2. `Project → Import` → select `project.godot` in this folder.
3. Press **F5** (menu boots automatically). Test keys: WASD move, J attack,
   K ability, L/Shift dash, U ultimate, H block, F3 debug overlay.
4. Headless tests: `godot --headless --path . -s tests/test_combat.gd`
   and `-s tests/test_data.gd`. Engine-free check: `py -3 tests/smoke_test.py`.

## Export APK
1. Install Android export templates (`Editor → Manage Export Templates`).
2. `Project → Export` → preset **Android** → `../builds/draa-v0.1.apk`.
3. Optional: drop `Cairo-Regular.ttf` / `Cairo-Bold.ttf` into
   `assets/fonts/` first for guaranteed Arabic typography.

## Docs
`docs/ARCHITECTURE.md` (systems + phase hooks) · `docs/CHANGELOG.md` ·
`docs/KNOWN_ISSUES.md` (read before release) · `docs/TEST_REPORT.md` ·
`docs/PERFORMANCE.md`. Design tokens: `design-system/draa/MASTER.md`.
