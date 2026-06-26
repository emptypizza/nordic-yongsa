"""Procedural top-down ground tile textures for the Crossy-Road escort board.

Placeholder art (image_gen is credit-blocked). Clean hand-painted-ish look,
NOT pixel art. Every texture is SEAMLESS (periodic value noise) so adjacent
board tiles of the same lane type read as one continuous surface.

Outputs 256x256 RGB PNGs: grass / water / path / plank.
"""
import numpy as np
from PIL import Image
import sys
from pathlib import Path

SIZE = 256


def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


def periodic_noise(size, period, seed):
    """Seamless value noise: random lattice tiled periodically + bilinear smooth."""
    rng = np.random.default_rng(seed)
    lattice = rng.random((period, period)).astype(np.float64)
    coords = np.linspace(0.0, period, size, endpoint=False)
    i0 = np.floor(coords).astype(int) % period
    i1 = (i0 + 1) % period
    f = _smooth(coords - np.floor(coords))
    # rows
    gy0 = lattice[i0][:, :]          # (size, period)
    gy1 = lattice[i1][:, :]
    rows = gy0 * (1 - f)[:, None] + gy1 * f[:, None]   # interp along y
    # cols
    c0 = rows[:, i0]
    c1 = rows[:, i1]
    out = c0 * (1 - f)[None, :] + c1 * f[None, :]
    return out


def fbm(size, seed, octaves=(4, 8, 16, 32), amps=(0.5, 0.27, 0.15, 0.08)):
    acc = np.zeros((size, size))
    for o, a in zip(octaves, amps):
        acc += a * periodic_noise(size, o, seed + o)
    acc -= acc.min()
    acc /= max(acc.max(), 1e-6)
    return acc


def lerp_color(a, b, t):
    a = np.array(a, float)
    b = np.array(b, float)
    return a[None, None, :] * (1 - t)[..., None] + b[None, None, :] * t[..., None]


def save(arr, path):
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    img.save(path)
    print("wrote", path)


def grass(path):
    n = fbm(SIZE, 11)
    patches = periodic_noise(SIZE, 4, 71)          # broad light/dark patches
    base = lerp_color((58, 120, 48), (96, 165, 70), _smooth(patches))
    base = base * (0.82 + 0.36 * n)[..., None]
    # bright blade speckles
    blades = fbm(SIZE, 23, octaves=(32, 64), amps=(0.6, 0.4))
    mask = (blades > 0.72)[..., None]
    base = np.where(mask, base * 0.55 + np.array([150, 205, 110]) * 0.45, base)
    # a few darker clumps
    dark = (fbm(SIZE, 31, octaves=(8, 16), amps=(0.6, 0.4)) < 0.22)[..., None]
    base = np.where(dark, base * 0.78, base)
    save(base, path)


def water(path):
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    warp = fbm(SIZE, 5) * 6.2
    ripple = 0.5 + 0.5 * np.sin((xx / 13.0) + warp + (yy / 40.0))
    ripple = _smooth(ripple)
    base = lerp_color((26, 86, 150), (54, 140, 205), ripple)
    # sparkle highlights on ripple crests
    crest = ((ripple > 0.86) & (fbm(SIZE, 17, octaves=(32,), amps=(1.0,)) > 0.5))[..., None]
    base = np.where(crest, base * 0.4 + np.array([200, 235, 255]) * 0.6, base)
    save(base, path)


def path(path):
    n = fbm(SIZE, 13)
    base = lerp_color((96, 70, 44), (150, 116, 74), _smooth(n))
    # scattered pebbles (grey, soft)
    peb = fbm(SIZE, 29, octaves=(16, 32), amps=(0.6, 0.4))
    pmask = (peb > 0.80)[..., None]
    base = np.where(pmask, base * 0.5 + np.array([150, 142, 130]) * 0.5, base)
    # subtle darker ruts
    rut = (fbm(SIZE, 19, octaves=(6, 12), amps=(0.6, 0.4)) < 0.25)[..., None]
    base = np.where(rut, base * 0.82, base)
    save(base, path)


def plank(path):
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    n = fbm(SIZE, 21)
    plank_w = SIZE / 4.0
    idx = (xx // plank_w).astype(int)
    rng = np.random.default_rng(5)
    tint = rng.uniform(0.85, 1.12, size=5)[idx]
    grain = 0.5 + 0.5 * np.sin(yy / 5.0 + n * 7.0 + idx[:, :] * 1.3)
    base = lerp_color((96, 66, 38), (150, 108, 64), _smooth(grain * 0.6 + n * 0.4))
    base = base * tint[..., None]
    # dark seams between planks
    seam = (np.abs((xx % plank_w) - 0.0) < 2.0) | (np.abs((xx % plank_w) - (plank_w - 1)) < 2.0)
    base[seam] *= 0.45
    save(base, path)


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    grass(out / "grass.png")
    water(out / "water.png")
    path(out / "path.png")
    plank(out / "plank.png")
    # quick 4-up contact sheet for review
    sheet = Image.new("RGB", (SIZE * 2, SIZE * 2))
    for i, name in enumerate(["grass", "water", "path", "plank"]):
        im = Image.open(out / f"{name}.png")
        sheet.paste(im, ((i % 2) * SIZE, (i // 2) * SIZE))
    sheet.save(out / "_contact.png")
    print("wrote", out / "_contact.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "tiles")
