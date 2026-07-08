#!/usr/bin/env python3
"""Mueve subidas y borra duplicadas según log de immich-go."""
import re, sys
from pathlib import Path

src, moved, log_path = map(Path, sys.argv[1:4])
uploaded, duplicates = set(), set()

for line in log_path.read_text(errors="replace").splitlines():
    if "uploaded successfully" in line or "server asset upgraded" in line:
        kind = "up"
    elif any(x in line for x in ("server has duplicate", "Already on server", "discarded local duplicate")):
        kind = "dup"
    else:
        continue
    m = re.search(r"file=([^\s]+)", line)
    if not m:
        continue
    name = m.group(1).split(":")[-1]
    (uploaded if kind == "up" else duplicates).add(name)

n_mv = n_rm = 0
for name in uploaded:
    f = src / name
    if not f.is_file():
        continue
    sc = src / f"{Path(name).stem}.aae"
    dest = moved / name
    if dest.exists():
        f.unlink(missing_ok=True)
    else:
        f.rename(dest)
    if sc.is_file():
        sc_dest = moved / sc.name
        if sc_dest.exists():
            sc.unlink(missing_ok=True)
        else:
            sc.rename(sc_dest)
    n_mv += 1

for name in duplicates:
    for p in (src / name, src / f"{Path(name).stem}.aae"):
        if p.is_file():
            p.unlink()
            n_rm += 1

left = sum(1 for _ in src.iterdir() if _.is_file())
print(f"Movidas: {n_mv} -> {moved}")
print(f"Borradas: {n_rm}")
print(f"Quedan en origen: {left}")
