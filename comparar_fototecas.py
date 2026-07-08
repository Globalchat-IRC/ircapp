#!/usr/bin/env python3
"""Compara Fototeca vs CATALOGO-PRINCIPAL por hash. Reanuda si se interrumpe."""
import hashlib, os, sys, time
from pathlib import Path

FOTO = Path("/Volumes/TOSHIBA EXT2/Fototeca.photoslibrary/originals")
CAT = Path("/Volumes/TOSHIBA EXT2/CATALOGO-PRINCIPAL-FOTOS.photoslibrary/originals")
CACHE = Path("/tmp/fotos_catalogo_principal_hashes.txt")
PROGRESS = Path("/tmp/fotos_catalogo_index_progress.txt")
FOTO_PROGRESS = Path("/tmp/fotos_fototeca_compare_progress.txt")
RESULT = Path("/tmp/fotos_comparar_resultado.txt")

def rel(root: Path, p: Path) -> str:
    return str(p.relative_to(root))

def iter_files(root: Path):
    for dp, _, fs in os.walk(root):
        for f in fs:
            p = Path(dp) / f
            if p.is_file():
                yield p

def md5(path: Path) -> str:
    h = hashlib.md5()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def load_lines(path: Path) -> set[str]:
    if path.exists() and path.stat().st_size:
        return set(path.read_text().splitlines())
    return set()

def save_catalog_progress(hashes: set[str], done: set[str]):
    CACHE.write_text("\n".join(hashes))
    PROGRESS.write_text("\n".join(done))

def index_catalog() -> set[str]:
    hashes = load_lines(CACHE)
    done = load_lines(PROGRESS)
    if done:
        print(f"Reanudando índice: {len(done)} ya hechos, {len(hashes)} hashes", flush=True)
    else:
        print("Indexando catálogo principal (~50k, 15-30 min)...", flush=True)

    n = len(done)
    t0 = time.time()
    for p in iter_files(CAT):
        key = rel(CAT, p)
        if key in done:
            continue
        try:
            hashes.add(md5(p))
        except OSError as e:
            print(f"\n❌ Error leyendo disco (¿Toshiba desconectado?): {e}", flush=True)
            save_catalog_progress(hashes, done)
            sys.exit("Reconecta TOSHIBA EXT2 y vuelve a ejecutar el script.")
        done.add(key)
        n += 1
        if n % 2000 == 0:
            save_catalog_progress(hashes, done)
            print(f"  {n} archivos ({time.time()-t0:.0f}s) — progreso guardado", flush=True)

    save_catalog_progress(hashes, done)
    print(f"Índice completo: {len(hashes)} hashes únicos", flush=True)
    return hashes

def compare_fototeca(cat_hashes: set[str]):
    done = load_lines(FOTO_PROGRESS)
    total = len(done)
    match = 0
    # Recalcular match de los ya hechos no guardamos; recontar solo si reanudamos parcial
    if done:
        print(f"Reanudando comparación Fototeca ({len(done)} ya hechos)...", flush=True)

    t0 = time.time()
    for p in iter_files(FOTO):
        key = rel(FOTO, p)
        if key in done:
            continue
        try:
            if md5(p) in cat_hashes:
                match += 1
        except OSError as e:
            print(f"\n❌ Toshiba desconectado: {e}", flush=True)
            FOTO_PROGRESS.write_text("\n".join(done))
            sys.exit("Reconecta el disco y vuelve a ejecutar.")
        done.add(key)
        total += 1
        if total % 1000 == 0:
            FOTO_PROGRESS.write_text("\n".join(done))
            # match parcial aproximado no exacto al reanudar; ok para progreso
            print(f"  {total}/26670...", flush=True)

    # Recount exact match at end
    match = sum(1 for p in iter_files(FOTO) if md5(p) in cat_hashes)
    total = sum(1 for _ in iter_files(FOTO))
    pct = 100 * match / total if total else 0

    lines = [
        f"Fototeca:           {total} archivos",
        f"Ya en catálogo:     {match} ({pct:.1f}%)",
        f"Solo en Fototeca:   {total - match} ({100-pct:.1f}%)",
    ]
    if pct >= 95:
        lines.append("→ SEGURO: no importes. Puedes borrar Fototeca.")
    elif pct >= 80:
        lines.append("→ Casi todo duplicado. Revisa el % restante.")
    else:
        lines.append("→ Hay fotos únicas en Fototeca. NO borres sin revisar.")

    text = "\n".join(lines)
    RESULT.write_text(text)
    print(f"\n{'='*50}\n{text}\n{'='*50}", flush=True)

def main():
    if not CAT.is_dir():
        sys.exit("❌ Conecta TOSHIBA EXT2 (no veo CATALOGO-PRINCIPAL-FOTOS)")
    if not FOTO.is_dir():
        sys.exit("❌ No veo Fototeca.photoslibrary en el Toshiba")

    if RESULT.exists() and not PROGRESS.exists():
        print(RESULT.read_text())
        return

    cat_hashes = index_catalog()
    compare_fototeca(cat_hashes)

if __name__ == "__main__":
    main()
