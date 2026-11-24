# CHANGELOG — DRAA دراع

## v0.4 — Visual identity pass (2026-10-09)
### From basic to character (procedural, zero shipped assets, mobile-safe)
- New `FighterVisual` shared builder: chibi cartoon body (legs/boots, normal
  arm, shoulder pads, belly band), expressive face (eyes/pupils/brows,
  element headband), big MagicArm. Menu preview uses the same builder —
  menu IS the game now.
- MagicArm detail: shoulder block, pulsing element elbow core, per-form
  garnish (fist knuckles, hot blade edge, shield boss) that rides the lunge.
- Juice everywhere: blink, hover bob, speed lean, dash stretch, hit/land
  squash, landing dust + thud, dash dust, ult shockwave rings, pulsing
  ult-ready button.
- Volcano: flowing lava texture (scrolling emission noise), basalt rim
  rocks, 2 flickering torches (real lights), dusk sky grading.
- Frozen: sparkling ice-floor texture, glowing fangs, looping snowfall,
  night sky; menu pedestal steps + element rune ring.
### Verification
- Integration 41/41, combat unit 47/47, data unit 35/35 — all green in
  Godot 4.7 headless, exit 0. Smoke + gdparse sweeps green.
- Honest note: headless can't screenshot — final visual QA needs the editor
  on a real screen (see TEST_REPORT manual matrix).

## v0.3 — Phase 3: second arena + full 1v1 (2026-10-09)
### Arenas (was 1 hardcoded, now a framework)
- New `ArenaBase`: lighting/env/props hooks + shared fighters, HUD, match
  flow, ult orb. Volcano slimmed to its identity (same numbers/geometry);
  no behavior change (all Phase-1/2 asserts still green unmodified).
- New Frozen Ruins: black-ice floor (traction 0.12 — steering slides,
  knockback stays instant), ice pillars, frost rim, pale orb, falling-ice
  hazard (fair telegraph ring + ping, then 15 dmg + 2s slow in radius).
- Fighter traction blend (`lerp` to wish; 1.0 = byte-identical to old
  snap) + ice slow status (strongest wins, longest refreshes); ice hits
  slow 0.65/1.5s. Telegraph sting in the procedural audio set.
- Arena select: `arenas.json` registry, GameManager resolution with volcano
  fallback, 2 cards in FighterSelect (persisted), second-fighter data-safe
  bot pool unchanged.
### Verification
- Integration 31/31, combat unit 44/44, data unit 35/35 — all green in
  Godot 4.7 headless, exit 0. Smoke + gdparse sweeps green.

## v0.2 — Phase 2: Core Combat feel (2026-10-09)
### Combat system (was instant-hit, now committed + readable)
- Attack phases per ability (`windup`/`recover`/`lunge` in data): arm coils,
  lunges, lands exactly at windup end; recoveries are punishable but
  dash-cancellable. Cooldowns start at commit (no free whiffs).
- Input buffer (0.3s): buttons pressed mid-action fire when free — mashing
  never eats inputs. Bots and keyboard ride the same `try_*` API.
- Combo chain: light, light, heavy finisher (x1.3 + pop-up); dash inside
  the window routes into a launcher; HUD combo counter; floating damage
  numbers (actual post-defense values, size-coded).
- Perfect dodge: dashing clean through an attack grants ult charge + sting
  + banner instead of damage. Ultimates get hyper-armor (unstoppable boom).
- All 12 abilities now real: dash-strikes lunge, volt_chain arcs to a 2nd
  enemy, shadow_clone spawns a 1-HP decoy that splits bot aggro (never ends
  rounds, expires, cleaned per round).
- HUD: 2nd ability button (replaces dead filler), KO/round banners, center
  announcements, directional damage chevrons (screen-side, not color-only),
  named buttons for test lookup.
- Feel tuning: hitstop 0.05/0.09 (nesting-safe), trauma shake, ult slow
  push-in, whiff ult trickle kept, block 70% cut + reduced stun.
### Verification
- Integration 25/25, combat unit 39/39, data unit 31/31 — all green in
  Godot 4.7 headless, exit 0. Smoke + gdparse sweeps green.

## v0.1 — First playable slice (2026-10-09)
### Added (Phase 1 + 2 + 3 core, vs bot)
- Godot 4.x project, Android-first config (landscape sensor, mobile GL
  renderer, 60 fps physics, touch emulation, ENet-ready permissions).
- Arabic-first RTL UI + localization system (`strings.csv`, 87 keys, ar/en).
- 3D main menu with live fighter preview + idle MagicArm, CTA العب دلوقتي,
  fighter select (4 data-driven cards + stats), profile (name/level/rank/
  wins), settings (language, music/SFX, vibration, reduce-shake, quality).
- 4 fighters balanced in data (fire/ice/lightning/shadow), 12 + 2 abilities
  in `abilities.json`, elemental matrix + team-combo table.
- One-arm combat: Fist/Blade/Shield morphs, context-aware attack,
  light/heavy timing combos, launcher (attack→dash→attack), dash i-frames,
  block, ult charge, hitstop, knockback, stun, ring-out.
- Volcano Temple arena: lava-moat hazard, pillars, punchable explosive
  barrels, ult orb, dynamic camera, pooled VFX, procedural SFX.
- Match flow: countdown, 90 s rounds, best-of-3, timeout judging, results
  with Egyptian reactions + title unlocks + XP/rank.
- Bots (easy/normal/hard, human-like reaction, no cheats), keyboard test
  path (WASD + J/K/L/U/H), ENet room layer + lobby ready-check path,
  save system with corruption fallback, debug overlay, Low/Med/High presets.
- Tests: `tests/test_combat.gd` + `tests/test_data.gd` (Godot headless),
  `tests/smoke_test.py` (CI, no engine needed) — all green.
### Fixed during slice
- Smoke test caught dynamic `tr_key("diff_"+…)` coverage gap → test now
  verifies prefix families; Arabic combo names moved from code comments
  into `team_combos.json` (zero hard-coded Arabic in gameplay code).
- Dead barrel-scan code replaced with real `BreakableBarrel` + shared
  "breakables" melee scan; joystick/keyboard move ownership race fixed via
  `touch_move`; HUD pause overlay set PROCESS_ALWAYS.
- `AudioStreamWav` → `AudioStreamWAV` (wrong casing, engine has no such
  type); added casing regression guard to `smoke_test.py`.
- Undeclared `_pivot` in `MainMenu.gd` (leftover `_preview_pivot` member
  rename); added in-file scope guard (§9) that catches this bug class —
  negative-tested against the original bug.
- `:=` inference failures over dynamic autoload calls (`calm`, `txt`,
  `bot_label/name`, `rtl`, `r`, `base`, `flavor`, `low_fx`) → explicit
  `: bool` / `: String`; added inference guard (§10), negative-tested.
- Engine audit on Godot 4.7 headless (full project import + integration +
  unit suites, all green) found and fixed:
  - Typed-array invariant: `configure([f1,f2], spawns)` rejected at
    runtime — all array vars now explicit (`Array[Fighter]`,
    `Array[Vector3]`, `Array[Node3D]`, `Array[String]`); guard §11.
  - Countdown corpse rounds: fighters now freeze during intro
    (`set_frozen` + try_* gates); freed bot drivers clear `move_dir`.
  - Nested `_hitstop` calls corrupted `Engine.time_scale` — now
    depth-counted and nesting-safe.
  - Wet-discharge never applied (match order) — `lightning+wet` x1.35 now
    overrides the table, per design §11.
  - Test-only: arena `auto_show_results` flag (match-end auto-advance
    yanked the tree mid-test); await-free step machine; typed-array and
    inference discipline in tests too.
