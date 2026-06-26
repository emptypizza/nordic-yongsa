"""Placeholder normal-monster sprite raws (2x2 idle, magenta bg) for the escort game.

image_gen (higgsfield) is credit-blocked, so these stand in until real art is
available; they still flow through generate2dsprite.py `process` exactly like a
generated sheet. Three distinct silhouettes so normal monsters vary: slime,
skeleton, bat. Clean hard-ish edges (drawn on transparent, composited to magenta).
"""
from PIL import Image, ImageDraw
import math
import sys

MAGENTA = (255, 0, 255, 255)
CELL = 256
SS = 4
C = CELL * SS
OUTLINE = (28, 30, 36)


def E(d, cx, cy, rx, ry, fill, outline=None, w=0):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill, outline=outline, width=w)


# ---------------- Slime ----------------
def slime(frame):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = SS
    ow = 3 * u
    midx = C // 2
    ground = int(C * 0.82)
    # wobble: squash/stretch
    t = frame / 4.0 * 2 * math.pi
    sq = 1.0 + 0.12 * math.sin(t)
    bw = int(95 * u / sq)
    bh = int(78 * u * sq)
    cy = ground - bh
    BODY = (74, 184, 150)
    BODY_DK = (44, 140, 112)
    BELLY = (150, 226, 200)
    # base puddle
    E(d, midx, ground, int(bw * 1.05), 18 * u, BODY_DK, OUTLINE, ow)
    # body blob (rounded dome)
    d.pieslice([midx - bw, cy - bh, midx + bw, cy + bh], 180, 360, fill=BODY, outline=OUTLINE, width=ow)
    d.rectangle([midx - bw, cy, midx + bw, ground - 2 * u], fill=BODY)
    d.line([(midx - bw, cy), (midx - bw, ground)], fill=OUTLINE, width=ow)
    d.line([(midx + bw, cy), (midx + bw, ground)], fill=OUTLINE, width=ow)
    d.arc([midx - bw, ground - 30 * u, midx + bw, ground + 30 * u], 0, 180, fill=OUTLINE, width=ow)
    # glossy highlight
    E(d, midx - 24 * u, cy + 8 * u, 26 * u, 20 * u, BELLY)
    E(d, midx + 34 * u, cy - 6 * u, 10 * u, 8 * u, (235, 255, 245))
    # eyes
    blink = (frame == 2)
    for sgn in (-1, 1):
        ex = midx + sgn * 30 * u
        ey = cy + 30 * u
        if blink:
            d.line([(ex - 14 * u, ey), (ex + 14 * u, ey)], fill=OUTLINE, width=4 * u)
        else:
            E(d, ex, ey, 18 * u, 22 * u, (250, 250, 245), OUTLINE, ow)
            E(d, ex, ey + 4 * u, 9 * u, 11 * u, (30, 30, 40))
            E(d, ex - 4 * u, ey - 2 * u, 3 * u, 3 * u, (255, 255, 255))
    # mouth
    d.arc([midx - 20 * u, cy + 48 * u, midx + 20 * u, cy + 74 * u], 10, 170, fill=OUTLINE, width=3 * u)
    return img


# ---------------- Skeleton ----------------
def skeleton(frame):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = SS
    ow = 3 * u
    midx = C // 2
    bob = int(round(4 * math.sin(frame / 4.0 * 2 * math.pi))) * u
    BONE = (236, 234, 220)
    BONE_DK = (200, 196, 178)
    SOCKET = (24, 22, 26)
    top = int(C * 0.16) + bob
    # legs
    for lx in (-20, 20):
        d.line([(midx + lx * u, int(C * 0.86)), (midx + lx * u, int(C * 0.64))], fill=BONE, width=10 * u)
        E(d, midx + lx * u, int(C * 0.87), 12 * u, 7 * u, BONE_DK, OUTLINE, 2 * u)
    # pelvis
    E(d, midx, int(C * 0.62) + bob, 34 * u, 18 * u, BONE, OUTLINE, ow)
    # spine + ribcage
    spine_top = top + 96 * u
    d.line([(midx, spine_top), (midx, int(C * 0.62) + bob)], fill=BONE, width=9 * u)
    for i, ry in enumerate([0, 22, 44]):
        ry = ry * u + spine_top + 6 * u
        half = (40 - i * 5) * u
        d.arc([midx - half, ry - 16 * u, midx + half, ry + 22 * u], 20, 160, fill=BONE, width=6 * u)
    # arms (bony), slight sway
    sway = int(round(6 * math.sin(frame / 4.0 * 2 * math.pi))) * u
    for sgn in (-1, 1):
        sx = midx + sgn * 30 * u
        d.line([(sx, spine_top + 6 * u), (sx + sgn * 26 * u + sway, spine_top + 70 * u)], fill=BONE, width=8 * u)
        E(d, sx + sgn * 26 * u + sway, spine_top + 74 * u, 8 * u, 8 * u, BONE_DK, OUTLINE, 2 * u)
    # skull
    sk_cy = top + 50 * u
    E(d, midx, sk_cy, 50 * u, 50 * u, BONE, OUTLINE, ow)
    E(d, midx, sk_cy + 40 * u, 30 * u, 26 * u, BONE, OUTLINE, ow)  # jaw
    # eye sockets (glow flicker)
    glow = (255, 90, 60) if frame % 2 == 0 else (255, 150, 70)
    for sgn in (-1, 1):
        E(d, midx + sgn * 22 * u, sk_cy - 2 * u, 15 * u, 17 * u, SOCKET)
        E(d, midx + sgn * 22 * u, sk_cy, 6 * u, 7 * u, glow)
    # nose + teeth
    d.polygon([(midx, sk_cy + 14 * u), (midx - 7 * u, sk_cy + 28 * u), (midx + 7 * u, sk_cy + 28 * u)], fill=SOCKET)
    for tx in range(-3, 4):
        d.line([(midx + tx * 9 * u, sk_cy + 34 * u), (midx + tx * 9 * u, sk_cy + 50 * u)], fill=OUTLINE, width=2 * u)
    return img


# ---------------- Bat ----------------
def bat(frame):
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = SS
    ow = 3 * u
    midx = C // 2
    cy = int(C * 0.5)
    BODY = (104, 84, 168)
    BODY_DK = (72, 58, 122)
    WING = (88, 70, 146)
    # wing flap: open on 0/2, folded on 1/3
    flap = math.sin(frame / 4.0 * 2 * math.pi)
    wing_y = int(-18 * flap) * u
    span = int((86 + 20 * flap)) * u
    for sgn in (-1, 1):
        bx = midx + sgn * 34 * u
        tip = midx + sgn * span
        d.polygon([
            (bx, cy - 6 * u),
            (tip, cy - 30 * u + wing_y),
            (tip - sgn * 10 * u, cy + 4 * u + wing_y),
            (tip, cy + 26 * u + wing_y),
            (bx, cy + 22 * u),
        ], fill=WING, outline=OUTLINE)
        # membrane ribs
        for k in (0.45, 0.75):
            d.line([(bx, cy + 8 * u), (bx + sgn * int(span * k), cy - 18 * u + wing_y + int(40 * k * u))], fill=BODY_DK, width=2 * u)
    # body
    E(d, midx, cy, 34 * u, 42 * u, BODY, OUTLINE, ow)
    E(d, midx, cy + 6 * u, 18 * u, 24 * u, (140, 120, 196))
    # ears
    for sgn in (-1, 1):
        d.polygon([(midx + sgn * 18 * u, cy - 36 * u), (midx + sgn * 30 * u, cy - 64 * u), (midx + sgn * 4 * u, cy - 44 * u)], fill=BODY, outline=OUTLINE)
    # eyes (glow) + blink
    blink = (frame == 3)
    for sgn in (-1, 1):
        ex = midx + sgn * 14 * u
        ey = cy - 8 * u
        if blink:
            d.line([(ex - 9 * u, ey), (ex + 9 * u, ey)], fill=OUTLINE, width=3 * u)
        else:
            E(d, ex, ey, 11 * u, 12 * u, (255, 224, 90), OUTLINE, 2 * u)
            E(d, ex, ey + 1 * u, 4 * u, 5 * u, (40, 28, 18))
    # fangs
    for sgn in (-1, 1):
        fx = midx + sgn * 8 * u
        d.polygon([(fx - 4 * u, cy + 16 * u), (fx + 4 * u, cy + 16 * u), (fx, cy + 30 * u)], fill=(250, 250, 245), outline=OUTLINE)
    return img


CREATURES = {"slime": slime, "skeleton": skeleton, "bat": bat}


def build(name, fn, out_path):
    sheet = Image.new("RGBA", (CELL * 2, CELL * 2), MAGENTA)
    for i in range(4):
        g = fn(i).resize((CELL, CELL), Image.LANCZOS)
        sheet.alpha_composite(g, ((i % 2) * CELL, (i // 2) * CELL))
    sheet.convert("RGB").save(out_path)
    print("wrote", name, out_path)


if __name__ == "__main__":
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    for nm, fn in CREATURES.items():
        build(nm, fn, f"{out_dir}/{nm}-raw.png")
