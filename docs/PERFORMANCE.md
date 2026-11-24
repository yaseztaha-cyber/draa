# PERFORMANCE — v0.1 budget + report

## Budget (mid-range Android, 60 fps where hardware permits)
- Draw calls: ≤40 in arena (1 dir-light w/ shadows, ambient only, no GI,
  ≤2 omnis: arm glow + menu rim; arena uses dir + ambient only).
- Particles: pooled CPUParticles3D, 4 per kind, minor puffs skipped on Low.
- Physics: 60 Hz, CharacterBody + deterministic range checks (no ragdolls,
  no Area-per-punch allocation — zero per-frame allocs in melee scan).
- Textures: all procedural (no textures ship in v0.1); when art lands:
  ETC2/ASTC, ≤1024 px characters, ≤2048 px environments.
- Presets: Low = no MSAA + 0.75 3D scale + 30 fps cap + calm FX;
  Medium = MSAA 2× + 0.9 scale + 60 fps; High = MSAA 4× + 1.0 + 60 fps.
- Watch live: DebugOverlay (F3 / 5× tap version tag) shows FPS, MEM (MB),
  OBJ count, PHYS ms, DRAW calls.

## v0.1 report (static analysis — device run pending, see KNOWN_ISSUES #1)
- Estimated arena draw calls: ~25–35 (floor, moat, 4 pillars, 2 fighters ×
  ~5 meshes, barrels ×2 meshes, orb ×1, particles as single quads). Fits.
- Physics bodies: 2 fighters + ~8 statics + 3 small Areas. Trivial load.
- Biggest risks to verify on device: shadow-map cost on Mali GPUs (disable
  `sun.shadow_enabled` on Low if needed — one-line change flagged here),
  SubViewport menu preview cost (UPDATE_ALWAYS; switch to ONCE when hidden
  if menu idle drains battery).
