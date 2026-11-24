# DRAA — دراع | Architecture Notes (v0.1 playable slice)

## Flow
`Main.tscn` (bootstrap) → `GameManager` autoload owns MENU → SELECT →
ARENA → RESULTS scene switches. No UI talks to scenes directly except
through `GameManager` (flow), `SaveManager` (data), `LocalizationManager`
(strings), `AudioManager` (sound).

## Autoloads (project.godot order matters)
1. `SaveManager` — sole owner of `user://draa_save.json` (profile, settings,
   unlocks). Corrupt save → backup + defaults, never a freeze.
2. `LocalizationManager` — Arabic-first CSV table (`data/localization/`),
   `tr_key()` everywhere; RTL layout flag. Gameplay code holds zero Arabic.
3. `AudioManager` — procedural SFX (synthesized WAV, no binaries): UI, attack
   per element, hit/heavy, dash, countdown, victory/defeat, voice-sting slot
   for Phase 8 Arabic VO. Master/music/SFX buses + toggles.
4. `GameManager` — state machine, selected fighter/difficulty/arena,
   Low/Medium/High quality presets, `shake_allowed()` / `reduced_motion()`.
5. `NetworkManager` (class `DraaNetwork`) — real ENet host/join by 6-digit
   room code, ready-state sync, disconnect signals, `validate_hit()` sanity
   gate so remote damage reports are never trusted blindly.
6. `DebugOverlay` — hidden FPS/MEM/OBJ/PHYS/DRAW readout (F3 or 5× tap).

## Combat (deterministic, net-ready)
- `FighterData` (.tres ×4) + `AbilityDB` (abilities.json) — all balance in
  data, see §40. `ElementMatrix` — elemental multipliers + team-combo table
  (display names in team_combos.json).
- `Fighter` (CharacterBody3D): context-aware attack with data-driven
  windup/active/recover phases, 0.3s input buffer, dash-cancelable recovery,
  light-light-heavy-finisher chains + dash-launcher routes, dash i-frames
  with perfect-dodge rewards, block (70% cut), 2 abilities (lunges, chain
  arcs, shadow decoys), ult charge 0–100 with hyper-armor windup,
  stun/knockback, ring-out detect. Melee = range+facing check shared by
  touch buttons, keyboard test path, and `BotController` (no cheat paths).
- `CombatHealth` — defense-aware HP + signals; owner decides consequences.
- `MagicArm` — THE hook: procedural Fist/Blade/Shield morphs, element
  emissive + charge glow, idle bob, lunge. New forms = new `Form` + mesh.
- `BreakableBarrel` ("breakables" group) — punchable, 20 HP, AoE detonation.
- `MatchManager` — countdown, 90 s rounds, best-of-3, KO/ring-out/timeout
  judging, 2v2 team-elimination path, XP via `SaveManager`.
- `CameraRig` — midpoint framing of living fighters (2v2 = wider), trauma
  shake gated by settings, impact zoom skipped under reduced motion.
- `VFXManager` — pooled CPUParticles3D (4/kind), shape-distinct per element,
  minor puffs skipped on Low.
- `DraaArena` — Volcano Temple built in code (floor, lava-moat hazard,
  pillars, barrels, ult orb, 1 dir-light + ambient, no GI).

## UI (ui-ux-pro-max DRAA tokens: Claymorphism, #F97316 + #2563EB)
- `DraaTheme` factory: chunky rounded panels, 3 px borders, double shadows,
  ≥96 px touch targets, 16 px gaps, safe-area margins, Arabic-capable font
  chain (bundled Cairo preferred, SystemFont fallback). Shape+text coded —
  no emoji icons, no color-only meaning.
- HUD: HP/ult bars both sides, tabular timer, joystick (left) + 5 action
  buttons (right), cooldown dimming, damage flash, low-HP warning, countdown,
  pause overlay (PROCESS_ALWAYS so it works while paused).
- Menu has a live 3D fighter preview; only shipped systems get buttons.

## Mini-games / progression (framework ready, games = Phase 5)
- `MiniGameBase` (INTRO→COUNTDOWN→PLAY→SCORE→DONE + scoring/winner API),
  `data/minigames/minigames.json` (all 4 games + party order),
  `data/rewards/rewards.json` (win-count titles, wired into Results/Profile).
- `LobbyManager` — offline 2-slot lobby exercises the same ready-check path
  online will use; host controls land here in Phase 6.

## What plugs in next (no rewrites)
- Phase 4 (2v2): TeamManager reads `ElementMatrix.team_combo` + proximity;
  spawn/team-UI hooks already exist (`team`, `_team_alive`).
- Phase 6 (online): add MultiplayerSynchronizer to Fighter replication +
  route remote hits through `DraaNetwork.validate_hit` (server authoritative).
- Phase 7 (Arm Lab): cosmetics split from stats already (`MagicArm`
  visuals vs `AbilityData` numbers); store in `profile.cosmetics`.
- Phase 8 (polish): drop Cairo TTFs in `assets/fonts/`, VO clips into
  `AudioManager.play_voice()`, arena 2–4 as new `DraaArena`-style builders.
