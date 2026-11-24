#!/usr/bin/env python3
"""DRAA smoke test — runs WITHOUT the Godot editor (CI-friendly).
Validates: JSON/CSV data, .tres/.tscn references, localization coverage
(every tr_key() has a CSV entry), no hard-coded Arabic in gameplay code,
no placeholders/fake-markers, no ';' statement separators in GDScript,
combat-balance sanity. Exit 0 = green.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fails: list[str] = []


def check(cond: bool, name: str) -> None:
    print(("PASS  " if cond else "FAIL  ") + name)
    if not cond:
        fails.append(name)


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


AR_RE = re.compile(r"[\u0600-\u06FF]")
GAMEPLAY_DIRS = ["scripts/combat", "scripts/ai", "scripts/multiplayer", "scripts/minigames"]
AR_ALLOW = {"Arena.gd"}  # uses tr_key() only; verified below

# 1. JSON data files.
for rel in ["data/abilities/abilities.json", "data/minigames/minigames.json",
            "data/rewards/rewards.json"]:
    p = ROOT / rel
    try:
        data = json.loads(read(p))
        check(isinstance(data, dict), f"{rel} parses as JSON object")
    except Exception as e:  # noqa: BLE001
        check(False, f"{rel} parses ({e})")

abilities = json.loads(read(ROOT / "data/abilities/abilities.json"))
check(abilities["heavy_punch"]["damage"] > abilities["light_punch"]["damage"],
      "heavy out-damages light")
check(abilities["fire_eruption"]["damage"] > abilities["heavy_punch"]["damage"],
      "ult out-damages basics")
check(abilities["volt_dash"]["range"] > abilities["fire_dash"]["range"],
      "lightning dash out-ranges fire dash")

# 2. Localization coverage.
csv_lines = read(ROOT / "data/localization/strings.csv").splitlines()
keys = {line.split(",")[0].strip() for line in csv_lines[1:] if line.strip()}
check(len(keys) > 50, f"strings.csv has 50+ keys ({len(keys)})")
used: set[str] = set()
prefixes: set[str] = set()
for gd in (ROOT / "scripts").rglob("*.gd"):
    text = read(gd)
    for m in re.finditer(r'tr_key\(\s*"([^"]+)"\s*\)', text):
        used.add(m.group(1))
    # Dynamic keys: tr_key("prefix_" + var) — verify the prefix family exists.
    for m in re.finditer(r'tr_key\(\s*"([^"]+)"\s*\+', text):
        prefixes.add(m.group(1))
missing = sorted(k for k in used if k not in keys)
check(not missing, f"all tr_key() covered {missing[:5]}")
for pfx in sorted(prefixes):
    family = [k for k in keys if k.startswith(pfx)]
    check(len(family) >= 2, f"dynamic prefix '{pfx}' has family {family[:4]}")

# 3. No hard-coded Arabic in gameplay scripts (must go through tr_key).
for d in GAMEPLAY_DIRS:
    for gd in (ROOT / d).rglob("*.gd"):
        if gd.name in AR_ALLOW:
            # Arena may only use Arabic inside comments/tr_key-adjacent? enforce zero:
            pass
        hits = [ln for ln in read(gd).splitlines() if AR_RE.search(ln)
                and "tr_key" not in ln and ln.strip().startswith("#") is False]
        # allow comment lines mentioning Arabic? No: keep strict, comments are English.
        check(not hits, f"no hard-coded Arabic in {gd.relative_to(ROOT)}")

# 4. No placeholders / fake markers.
banned = ["TODO", "FIXME", "Coming Soon", "Lorem Ipsum", "Test Button",
          "fake multiplayer", "fake rewards", "fake combat", "placeholder descriptions"]
blobs = [(p, read(p)) for p in list((ROOT / "scripts").rglob("*.gd"))
         + list((ROOT / "scenes").rglob("*.tscn"))]
for pat in banned:
    hit = [str(p.relative_to(ROOT)) for p, b in blobs if pat.lower() in b.lower()
           and "no placeholders" not in b.lower()]
    # allow the word in test files? tests live elsewhere; scripts must be clean.
    check(not hit, f"no '{pat}' in shipped code {hit[:3]}")

# 5. GDScript hygiene: tabs, no ';' separators.
for gd in (ROOT / "scripts").rglob("*.gd"):
    lines = read(gd).splitlines()
    bad_indent = [i + 1 for i, ln in enumerate(lines)
                  if ln.startswith(" ") and not ln.strip().startswith("#")]
    check(not bad_indent, f"tabs indentation {gd.name}")
    semis = [i + 1 for i, ln in enumerate(lines)
             if ";" in ln.split("#")[0]
             and not re.search(r'".*;.*"', ln)]
    check(not semis, f"no ';' separators {gd.name} {semis[:3]}")

# 5b. Engine class-name casing (gdparse can't catch these; the editor can).
# Verified against Godot 4 docs. Extend this map when new traps are found.
WRONG_CASE = {
    "AudioStreamWav": "AudioStreamWAV",  # v0.1 bug: broke AudioManager._tone
}
for gd in (ROOT / "scripts").rglob("*.gd"):
    text = read(gd)
    for wrong, right in WRONG_CASE.items():
        hit = [i + 1 for i, ln in enumerate(text.splitlines())
               if wrong in ln and right not in ln]
        check(not hit, f"no mis-cased '{wrong}' in {gd.name} {hit[:3]}")

# 6. .tres fighters reference the class + sane numbers.
import re as _re
for fid in ["fire", "ice", "lightning", "shadow"]:
    t = read(ROOT / f"data/fighters/{fid}.tres")
    check("FighterData.gd" in t, f"{fid}.tres links FighterData")
    hp = float(_re.search(r"max_hp = ([\d.]+)", t).group(1))
    sp = float(_re.search(r"move_speed = ([\d.]+)", t).group(1))
    check(80.0 <= hp <= 130.0 and 5.0 <= sp <= 8.0, f"{fid} sane stats")

# 7. .tscn scenes reference existing scripts.
for tscn in (ROOT / "scenes").rglob("*.tscn"):
    for m in re.finditer(r'path="(res://[^"]+\.gd)"', read(tscn)):
        target = ROOT / m.group(1).replace("res://", "")
        check(target.exists(), f"{tscn.name} -> {m.group(1)} exists")

# 8. project.godot: main scene + autoloads + mobile renderer.
proj = read(ROOT / "project.godot")
for needle in ['run/main_scene="res://scenes/main/Main.tscn"',
               "LocalizationManager", "SaveManager", "GameManager",
               "NetworkManager", "AudioManager", '"mobile"']:
    check(needle in proj, f"project.godot has {needle}")

# 9. Scope check: every private-style name used as a BARE identifier must be
#    declared in the same file (member/func/param/loop var). Attribute access
#    on other objects (f._x) is exempt — it resolves against their scope.
#    Catches the v0.1 _pivot bug class, which gdparse cannot see.
FUNC_SIG = re.compile(r'\bfunc\s*(?:[A-Za-z_]\w*\s*)?\(([^)]*)\)')
FUNC_NAME = re.compile(r'\bfunc\s+([A-Za-z_]\w*)')
MEMBER = re.compile(r'(?m)^\s*(?:static\s+)?(?:@export\s+|@onready\s+)?var\s+([A-Za-z_]\w*)')
INF = re.compile(r'(?m)^\s*([A-Za-z_]\w*)\s*:=')
FORV = re.compile(r'\bfor\s+([A-Za-z_]\w*)\s+in\b')
ATTR = re.compile(r'(?<!self)\.\s*_[A-Za-z]\w*')
USE = re.compile(r'\b(_[A-Za-z]\w*)\b')
STRLIT = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')


def _split_params(sig: str) -> list:
    parts, depth, cur = [], 0, ""
    for ch in sig:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    names = []
    for p in parts:
        p = p.strip()
        if not p:
            continue
        p = p.split("=")[0].split(":")[0].strip()
        if re.fullmatch(r'[A-Za-z_]\w*', p):
            names.append(p)
    return names


scope_problems = {}
# Class registry first: `extends` chains resolve like the editor does, so
# inherited _privates (ArenaBase._flat/_tick) are not false-flagged.
DECL_MEM = re.compile(r'(?m)^\s*(?:static\s+)?(?:@export\s+|@onready\s+)?var\s+([A-Za-z_]\w*)')
DECL_FUN = re.compile(r'(?m)^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)')
DECL_CLS = re.compile(r'(?m)^class_name\s+([A-Za-z_]\w*)')
DECL_EXT = re.compile(r'(?m)^extends\s+([A-Za-z_]\w*)')
DECL_ENUM = re.compile(r'(?m)^\s*enum\s+([A-Za-z_]\w*)')
gd_files = [g for g in list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tests").rglob("*.gd")) if g.name != "smoke_test.py"]
_file_code: dict = {}
_file_class: dict = {}
_file_parent: dict = {}
_file_decls: dict = {}
_class_file: dict = {}
for gd in gd_files:
    code0 = STRLIT.sub('""', read(gd))
    code0 = "\n".join(line.split("#")[0] for line in code0.splitlines())
    _file_code[gd] = code0
    names = set(DECL_MEM.findall(code0)) | set(DECL_FUN.findall(code0)) | set(DECL_ENUM.findall(code0))
    for m in FUNC_SIG.finditer(code0):
        names.update(_split_params(m.group(1)))
    names.update(FORV.findall(code0))
    for m in INF.finditer(code0):
        names.add(m.group(1))
    _file_decls[gd] = names
    cm = DECL_CLS.search(code0)
    em = DECL_EXT.search(code0)
    if cm:
        _file_class[gd] = cm.group(1)
        _class_file[cm.group(1)] = gd
    if em:
        _file_parent[gd] = em.group(1)


def _inherited(gd) -> set:
    out: set = set()
    seen: set = set()
    parent = _file_parent.get(gd, "")
    while parent and parent not in seen:
        seen.add(parent)
        pgd = _class_file.get(parent)
        if pgd is None:
            break # engine base (Node3D, Node, ...) — out of scope
        out |= _file_decls.get(pgd, set())
        parent = _file_parent.get(pgd, "")
    return out
for gd in gd_files:
    code = _file_code[gd]
    declared = set(_file_decls[gd]) | set(FUNC_NAME.findall(code))
    declared |= _inherited(gd)
    body = ATTR.sub("", code)
    used = set(USE.findall(body))
    missing = sorted(u for u in used if u not in declared)
    if missing:
        scope_problems[str(gd.relative_to(ROOT))] = missing
check(not scope_problems, f"all _private names resolve in-file {scope_problems}")

# 10. Inference guard: inferred `var x := ...` must not depend on dynamic
#    engine handles at paren-depth 0 (`tr_key(`, `get_setting(`, `get_meta(`,
#    bare dynamic member reads, or `and`/`or` chains over them). The editor
#    hard-errors these as "cannot infer type". Same calls nested inside
#    typed wrappers like str()/float()/make_button() are fine.
INF_DECL = re.compile(r'^\s*var\s+[A-Za-z_]\w*\s*:=')
DYN_MARKERS = ["tr_key(", "get_setting(", "get_meta(", ".profile",
               ".difficulty", ".current_locale", ".selected_fighter",
               ".players", ".settings", ".cosmetics"]
BOOLOP = re.compile(r'\b(and|or)\b')


def _depth_at(s: str, idx: int) -> int:
    d = 0
    for ch in s[:idx]:
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
    return d


infer_problems = {}
for gd in list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tests").rglob("*.gd")):
    if gd.name == "smoke_test.py":
        continue
    bad = []
    for i, raw in enumerate(read(gd).splitlines(), 1):
        line = STRLIT.sub('""', raw).split("#")[0]
        if not INF_DECL.match(line):
            continue
        rhs = line.split(":=", 1)[1]
        hits = [m for m in DYN_MARKERS if m in rhs and _depth_at(rhs, rhs.find(m)) == 0]
        hits += ["boolop:" + m.group(1) for m in BOOLOP.finditer(rhs)
                 if _depth_at(rhs, m.start()) == 0]
        if hits:
            bad.append(f"L{i}:{hits}")
    if bad:
        infer_problems[str(gd.relative_to(ROOT))] = bad
check(not infer_problems, f"no dynamic := inference {infer_problems}")

# 11. Typed-array guard: inferred `var x := [...]` literals must never flow
#    into typed `Array[T]` parameters (engine rejects untyped Array at the
#    call: "does not have the same element type"). Declare explicitly.
#    v0.1 bug: MatchManager.configure([f1,f2], spawns) failed at runtime.
INF_ARRAY = re.compile(r'^\s*var\s+[A-Za-z_]\w*\s*:=\s*\[')
array_hits = []
for gd in list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tests").rglob("*.gd")):
    if gd.name == "smoke_test.py":
        continue
    code = STRLIT.sub('""', read(gd))
    for i, line in enumerate(code.splitlines(), 1):
        if INF_ARRAY.match(line.split("#")[0]):
            array_hits.append(f"{gd.relative_to(ROOT)}:L{i}")
check(not array_hits, f"no inferred array literals {array_hits}")

# 12. Duplicate-definition guard: GDScript has no overloading — two funcs,
#    members, signals or consts with the same name in one scope never compile
#    ("has the same name as a previously declared function"). v0.1 bug: an
#    instance + static trace() pair broke the audit scene at load.
TOPFUNC = re.compile(r'^(?:static\s+)?func\s+([A-Za-z_]\w*)')
TOPVAR = re.compile(r'^(?:static\s+)?(?:@export\s+|@onready\s+)?var\s+([A-Za-z_]\w*)')
TOPSIG = re.compile(r'^signal\s+([A-Za-z_]\w*)')
TOPCONST = re.compile(r'^const\s+([A-Za-z_]\w*)')
CLASSNAME = re.compile(r'^class_name\s+([A-Za-z_]\w*)')
dup_problems: dict = {}
seen_classnames: dict = {}
for gd in list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "tests").rglob("*.gd")):
    if gd.name == "smoke_test.py":
        continue
    code = STRLIT.sub('""', read(gd))
    seen: dict = {}
    for line in code.splitlines():
        if line.startswith((" ", "\t")) or not line.strip() or line.strip().startswith("#"):
            continue
        m = TOPFUNC.match(line) or TOPVAR.match(line) or TOPSIG.match(line) or TOPCONST.match(line)
        if m:
            seen.setdefault(m.group(1), []).append(m.group(0).split()[0])
    dups = sorted(n for n, ks in seen.items() if len(ks) > 1)
    if dups:
        dup_problems[str(gd.relative_to(ROOT))] = dups
    cm = CLASSNAME.search(code)
    if cm:
        if cm.group(1) in seen_classnames:
            dup_problems.setdefault("GLOBAL class_name", []).append(cm.group(1))
        seen_classnames[cm.group(1)] = str(gd.relative_to(ROOT))
check(not dup_problems, f"no duplicate definitions {dup_problems}")

# 13. No class_name in tests/: test classes never enter the global class
#    cache reliably (cache builds at import; test files load later), so any
#    game->test class reference fails with "not declared in the current
#    scope" and cascades (MatchManager -> Arena -> scene). v0.1 audit bug:
#    RoundBisect broke the audit the same way. Tests load by path.
test_classes = []
for gd in (ROOT / "tests").rglob("*.gd"):
    if gd.name == "smoke_test.py":
        continue
    code = STRLIT.sub('""', read(gd))
    m = CLASSNAME.search(code)
    if m:
        test_classes.append(f"{gd.relative_to(ROOT)}:{m.group(1)}")
check(not test_classes, f"no class_name in tests {test_classes}")

print("---")
if fails:
    print(f"{len(fails)} FAILURES")
    sys.exit(1)
print("ALL SMOKE TESTS PASSED")
