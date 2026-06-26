"""Author a placeholder goblin idle sheet (2x2) on a magenta chroma-key background.

This stands in for the AI-generated raw sheet until real credits are available.
Output feeds generate2dsprite.py `process` exactly like a generated image would.
"""
from PIL import Image, ImageDraw
import math
import sys

MAGENTA = (255, 0, 255, 255)
CELL = 256          # output cell size
SS = 4              # supersample factor for smooth alpha edges
C = CELL * SS

# Palette (avoid anything near magenta)
SKIN = (96, 165, 64)
SKIN_DK = (66, 122, 44)
SKIN_LT = (132, 196, 96)
BELLY = (150, 200, 110)
EYE_WHITE = (245, 245, 230)
PUPIL = (30, 24, 20)
BROW = (50, 80, 30)
FANG = (250, 248, 235)
LOIN = (120, 78, 44)
LOIN_DK = (92, 58, 32)
CLUB_WOOD = (138, 96, 56)
CLUB_WOOD_DK = (104, 70, 40)
NAIL = (60, 45, 32)
OUTLINE = (28, 40, 18)


def ellipse(d, cx, cy, rx, ry, fill, outline=None, w=0):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill,
              outline=outline, width=w)


def draw_goblin(frame):
    """frame: 0..3 idle cycle. Returns RGBA CxC transparent image of one goblin."""
    img = Image.new("RGBA", (C, C), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = SS  # 1 logical px

    # idle motion params
    bob = int(round(6 * math.sin(frame / 4.0 * 2 * math.pi))) * u   # body bob
    breathe = 1.0 + 0.04 * math.sin(frame / 4.0 * 2 * math.pi)
    blink = (frame == 2)                                            # blink frame
    club_up = int(round(4 * math.sin((frame + 1) / 4.0 * 2 * math.pi))) * u

    midx = C // 2
    ground = int(C * 0.86)

    ow = max(2 * u, 1)  # outline width

    # feet
    foot_y = ground
    for fx in (-34, 34):
        ellipse(d, midx + fx * u, foot_y, 26 * u, 14 * u, SKIN_DK,
                OUTLINE, ow)

    # legs
    for lx in (-24, 24):
        d.rounded_rectangle(
            [midx + lx * u - 14 * u, ground - 46 * u + bob,
             midx + lx * u + 14 * u, foot_y - 4 * u],
            radius=10 * u, fill=SKIN, outline=OUTLINE, width=ow)

    # body (pot-bellied)
    body_cy = int(ground - 92 * u + bob)
    bw = int(70 * u * breathe)
    bh = int(64 * u)
    ellipse(d, midx, body_cy, bw, bh, SKIN, OUTLINE, ow)
    # belly highlight
    ellipse(d, midx, body_cy + 14 * u, int(bw * 0.55), int(bh * 0.55), BELLY)

    # loincloth
    d.polygon([
        (midx - 46 * u, body_cy + 30 * u),
        (midx + 46 * u, body_cy + 30 * u),
        (midx + 30 * u, body_cy + 70 * u),
        (midx, body_cy + 54 * u),
        (midx - 30 * u, body_cy + 70 * u),
    ], fill=LOIN, outline=OUTLINE)
    d.line([(midx - 46 * u, body_cy + 30 * u),
            (midx + 46 * u, body_cy + 30 * u)], fill=LOIN_DK, width=4 * u)

    # left arm (goblin's right) hanging
    d.rounded_rectangle(
        [midx - 84 * u, body_cy - 6 * u, midx - 58 * u, body_cy + 52 * u],
        radius=12 * u, fill=SKIN, outline=OUTLINE, width=ow)
    ellipse(d, midx - 71 * u, body_cy + 54 * u, 16 * u, 16 * u, SKIN_LT,
            OUTLINE, ow)

    # right arm holding a club, raised by club_up
    arm_top = body_cy - 10 * u - club_up
    d.rounded_rectangle(
        [midx + 58 * u, arm_top, midx + 84 * u, body_cy + 40 * u],
        radius=12 * u, fill=SKIN, outline=OUTLINE, width=ow)
    hand_cx, hand_cy = midx + 71 * u, arm_top - 2 * u
    # club: handle + knobby head
    d.line([(hand_cx, hand_cy + 6 * u), (hand_cx + 30 * u, hand_cy - 60 * u)],
           fill=CLUB_WOOD, width=14 * u)
    d.line([(hand_cx, hand_cy + 6 * u), (hand_cx + 30 * u, hand_cy - 60 * u)],
           fill=CLUB_WOOD_DK, width=4 * u)
    ellipse(d, hand_cx + 32 * u, hand_cy - 66 * u, 24 * u, 22 * u, CLUB_WOOD,
            OUTLINE, ow)
    for nx, ny in [(-8, -10), (10, -4), (2, 12), (14, 8)]:
        ellipse(d, hand_cx + 32 * u + nx * u, hand_cy - 66 * u + ny * u,
                3 * u, 3 * u, NAIL)
    ellipse(d, hand_cx, hand_cy + 6 * u, 16 * u, 16 * u, SKIN_LT, OUTLINE, ow)

    # head
    head_cy = int(body_cy - 96 * u)
    hw, hh = 64 * u, 56 * u
    ellipse(d, midx, head_cy, hw, hh, SKIN, OUTLINE, ow)
    # cheek shading
    ellipse(d, midx, head_cy + 18 * u, int(hw * 0.7), int(hh * 0.5), SKIN_LT)

    # ears (big, pointy, sideways)
    for sgn in (-1, 1):
        ex = midx + sgn * 60 * u
        d.polygon([
            (ex, head_cy - 10 * u),
            (ex + sgn * 64 * u, head_cy - 30 * u),
            (ex + sgn * 18 * u, head_cy + 20 * u),
        ], fill=SKIN, outline=OUTLINE)
        d.polygon([
            (ex + sgn * 6 * u, head_cy - 6 * u),
            (ex + sgn * 42 * u, head_cy - 22 * u),
            (ex + sgn * 16 * u, head_cy + 10 * u),
        ], fill=SKIN_DK)

    # brow (angry monobrow)
    d.line([(midx - 40 * u, head_cy - 16 * u), (midx - 6 * u, head_cy - 4 * u)],
           fill=BROW, width=8 * u)
    d.line([(midx + 40 * u, head_cy - 16 * u), (midx + 6 * u, head_cy - 4 * u)],
           fill=BROW, width=8 * u)

    # eyes
    for sgn in (-1, 1):
        ex = midx + sgn * 24 * u
        ey = head_cy + 2 * u
        if blink:
            d.line([(ex - 16 * u, ey), (ex + 16 * u, ey)], fill=OUTLINE,
                   width=5 * u)
        else:
            ellipse(d, ex, ey, 18 * u, 16 * u, EYE_WHITE, OUTLINE, ow)
            # pupil looks slightly toward center (menacing)
            ellipse(d, ex - sgn * 4 * u, ey + 2 * u, 8 * u, 9 * u, PUPIL)
            ellipse(d, ex - sgn * 6 * u, ey - 1 * u, 3 * u, 3 * u, EYE_WHITE)

    # nose (big warty)
    ellipse(d, midx, head_cy + 22 * u, 14 * u, 12 * u, SKIN_DK, OUTLINE, ow)

    # mouth + underbite fangs
    d.arc([midx - 30 * u, head_cy + 18 * u, midx + 30 * u, head_cy + 52 * u],
          start=10, end=170, fill=OUTLINE, width=6 * u)
    for sgn in (-1, 1):
        fx = midx + sgn * 16 * u
        fy = head_cy + 40 * u
        d.polygon([(fx - 6 * u, fy), (fx + 6 * u, fy), (fx, fy + 16 * u)],
                  fill=FANG, outline=OUTLINE)

    return img


def main(out_path):
    sheet = Image.new("RGBA", (CELL * 2, CELL * 2), MAGENTA)
    for i in range(4):
        g = draw_goblin(i).resize((CELL, CELL), Image.LANCZOS)
        cx = (i % 2) * CELL
        cy = (i // 2) * CELL
        sheet.alpha_composite(g, (cx, cy))
    sheet.convert("RGB").save(out_path)
    print("wrote", out_path, sheet.size)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "goblin-raw.png")
