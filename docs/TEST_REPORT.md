# TEST REPORT — v0.1 slice

## Ran here (no engine needed)
- `py -3 tests/smoke_test.py` → **ALL GREEN** (~100 checks):
  JSON validity (abilities/minigames/rewards), balance ordering
  (heavy > light, ult > basics, volt dash longest), 87-key CSV coverage of
  every static + dynamic (`diff_*`, `quality_*`) `tr_key()`, zero hard-coded
  Arabic in combat/ai/multiplayer/minigames, zero banned placeholders,
  tabs-only indentation, no `;` separators, .tres stat sanity ×4, .tscn→script
  references ×5, project.godot autoloads + main scene + mobile renderer.
- `gdparse` sweep → **28/28 files parse clean** (all scripts + both tests).

## Ran in-engine (Godot 4.7 headless, 2026-10-09) — ALL GREEN
- `godot --headless --path . res://tests/test_full.tscn` → **41/41 PASS**,
  exit 0: menu/select (fighter + arena cards)/arena boot, 2 fighters, arm
  detail, HUD bind, countdown, melee, hurt feedback, perfect dodge (charge
  + no damage), dash, ability1, combo x3 chain, ult (consume + damage),
  ability2 button + cast, barrels, orb, lava, frozen probe (traction value,
  ice slide, shard damage + slow), volcano dressing (rocks, lava, torches,
  sky), frozen dressing (fangs, snowfall, sky), forced 1v1 win, XP record,
  results screen.
- `godot --headless --path . -s tests/test_combat.gd` → **52/52 PASS**.
- `godot --headless --path . -s tests/test_data.gd` → **35/35 PASS**
  (the JSON error + corruption warning in its log are the test working).
- Full editor import: zero script errors.
- Note: `-s` runs print ObjectDB/resource teardown warnings — harness
  noise (Nodes freed at quit), not game leaks.
- Headless runbook: plain `--headless` suffices (no GPU/audio hardware
  needed; `--audio-driver Dummy` optional). On kill, prefer the engine log
  at `user://logs/godot.log` — it captures prints reliably, unlike
  CRT-buffered stdout redirection.

## Manual matrix (do on device after first import)
- [ ] VISUAL PASS (v0.4, editor required): fighter reads as a character at
  3m distance (face/arm/silhouette), arm forms distinct mid-fight, lava
  flows, torches flicker, snow falls, menu preview matches arena fighter,
  no z-fighting/popping on a real GPU, 60fps feel on a mid-range phone
- [ ] RTL layout on Arabic, LTR on English; long names don't overflow HUD
- [ ] 1280×720 landscape + tall/odd aspects (safe areas hold)
- [ ] Attack/dash/ability/ult vs each bot difficulty; round timeout judging
- [ ] Barrel punch → explosion → 15 s respawn; lava tick past the moat
- [ ] Pause → resume/quit; airplane-mode mid-match (bot fallback path)
- [ ] Corrupt `user://draa_save.json` → clean defaults, no freeze
- [ ] Low preset holds frame budget on a mid-range device (see PERFORMANCE)

## UI pre-delivery (ui-ux-pro-max checklist, adapted to Godot)
- No emoji icons (shape+text coded buttons) ✓ · touch ≥96 px, gaps 16 ✓
- Contrast: white/ink on clay panels, HP bars + text labels (not color-only) ✓
- Reduced-motion path (calm arm idle, no hitstop/zoom/shake) ✓
- Safe-area margins (status bar 28, bottom 28, sides 24–32) ✓
- Focus: buttons FOCUS_ALL/pointing-hand; joystick/act-buttons touch-owned ✓
