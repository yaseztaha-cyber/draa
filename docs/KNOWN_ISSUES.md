# KNOWN ISSUES — v0.1 (honest list, §54)

1. **Engine audit: DONE here (Godot 4.7 headless).** Full editor import
   (zero script errors) + all three suites green (18 + 28 + 31 asserts).
   Remaining device work: first real import on your machine, touch feel,
   and the manual matrix in TEST_REPORT. A reusable 4.7 binary lives at
   `C:\Users\DELL\AppData\Local\Temp\opencode\godot47\` for future audits.
2. **Online transform replication not wired yet.** Host/join/room-code/ready/
   disconnect are real ENet; fighter position sync (MultiplayerSynchronizer)
   + authoritative hit validation land in Phase 6. Menu exposes vs-bot only —
   no fake online button.
3. **No bundled Arabic font.** Font chain tries `assets/fonts/Cairo-*.ttf`
   then system fonts (Cairo/Tajawal/Noto Kufi Arabic). Drop the TTFs in
   before release or Arabic falls back to system rendering.
4. **Procedural characters, no rigged models.** Fighters are expressive
   capsule+sphere builds with the MagicArm as the visual star. Real
   character art + full animation set (victory/defeat/ultimate cinematics)
   land in Phase 8.
5. **Mini-games 2–4, arenas 2–4, 2v2 matchmaking, Arm Lab:** framework + data
   shipped (`MiniGameBase`, `minigames.json`, `team_combos.json`), games and
   lab UI arrive per the phase plan — deliberately not buttoned in menus.
6. **Voice reactions are synth stings.** `play_voice()` API is stable; Arabic
   VO clips replace the sting in Phase 8 with zero call-site changes.
7. **Balance is first-pass.** Numbers are data-driven and test-guarded for
   ordering (heavy > light, ult > all), but feel-tuning needs device
   playtesting (see PERFORMANCE.md).
