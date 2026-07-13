#!/usr/bin/env python3
"""Gera os assets raster do tema Plymouth autoral do RAGOS.

O objetivo aqui e manter o conjunto leve para initrd, mas com uma identidade
mais controlada que o script antigo. O pipeline reaproveita a marca do projeto
e gera fundo, logo, barra de progresso e frames de animacao com Pillow.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


REPO_ROOT = Path(__file__).resolve().parents[4]
THEME_DIR = REPO_ROOT / "themes" / "plymouth" / "ragos"
SOURCE_WORDMARK = THEME_DIR / "source-background.jpg"
SOURCE_ICON = REPO_ROOT / "installer" / "installer-ui" / "shared" / "public" / "imgs" / "ragton.png"
FRAMES_DIR = THEME_DIR / "frames"

SIZE_BG = (1920, 1080)
SIZE_TRACK = (420, 12)
SIZE_FRAMES = (448, 40)

PALETTE = {
    "bg_top": (3, 8, 18),
    "bg_mid": (6, 16, 30),
    "bg_bottom": (4, 10, 20),
    "graphite": (20, 28, 40),
    "graphite_soft": (34, 46, 66),
    "line": (74, 110, 154),
    "line_soft": (56, 84, 118),
    "blue": (96, 168, 231),
    "cyan": (150, 234, 255),
    "steel": (213, 225, 237),
}


def lerp(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def mix(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(lerp(a, b, t) for a, b in zip(c1, c2))


def round_rect_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def sampled_background_color(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    points = [
        (0, 0),
        (rgb.width - 1, 0),
        (0, rgb.height - 1),
        (rgb.width - 1, rgb.height - 1),
        (rgb.width // 8, rgb.height // 8),
        (rgb.width * 7 // 8, rgb.height // 8),
    ]
    samples = [rgb.getpixel(point) for point in points]
    return tuple(sum(channel[i] for channel in samples) // len(samples) for i in range(3))


def extract_logo() -> Image.Image:
    base = Image.open(SOURCE_WORDMARK).convert("RGB")
    bg = sampled_background_color(base)
    bg_fill = Image.new("RGB", base.size, bg)
    diff = ImageChops.difference(base, bg_fill)
    r, g, b = diff.split()
    mask = ImageChops.lighter(ImageChops.lighter(r, g), b)
    mask = mask.point(lambda p: 0 if p < 18 else min(255, int((p - 18) * 255 / 34)))
    mask = mask.filter(ImageFilter.GaussianBlur(0.7))

    rgba = base.convert("RGBA")
    rgba.putalpha(mask)
    bbox = mask.getbbox()
    if not bbox:
        raise RuntimeError("Nao foi possivel extrair a marca do RAGOS.")

    crop = rgba.crop(bbox)
    crop = ImageEnhance.Contrast(crop).enhance(1.08)
    crop = ImageEnhance.Color(crop).enhance(1.05)
    target_width = 560
    target_height = int(crop.height * (target_width / crop.width))
    logo = crop.resize((target_width, target_height), Image.Resampling.LANCZOS)

    pad = 28
    canvas = Image.new("RGBA", (logo.width + pad * 2, logo.height + pad * 2), (0, 0, 0, 0))

    glow_mask = logo.getchannel("A").filter(ImageFilter.GaussianBlur(16))
    glow_layer = Image.new("RGBA", logo.size, (*PALETTE["blue"], 0))
    glow_layer.putalpha(glow_mask.point(lambda p: min(88, int(p * 0.34))))
    canvas.alpha_composite(glow_layer, (pad, pad + 2))
    canvas.alpha_composite(logo, (pad, pad))
    return canvas


def build_gradient_background() -> Image.Image:
    width, height = SIZE_BG
    base = Image.new("RGBA", SIZE_BG)
    pixels = base.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        vertical = mix(PALETTE["bg_top"], PALETTE["bg_bottom"], t)
        horizontal_mix = 0.18 * (1 - abs((y / height) - 0.45))
        color = mix(vertical, PALETTE["bg_mid"], horizontal_mix)
        for x in range(width):
            pixels[x, y] = (*color, 255)

    planes = Image.new("RGBA", SIZE_BG, (0, 0, 0, 0))
    draw = ImageDraw.Draw(planes, "RGBA")
    draw.polygon(
        [(0, 0), (910, 0), (1510, 1080), (760, 1080)],
        fill=(12, 34, 58, 92),
    )
    draw.polygon(
        [(0, 280), (580, 120), (1420, 1080), (320, 1080)],
        fill=(20, 58, 94, 58),
    )
    draw.polygon(
        [(1180, 0), (1920, 0), (1920, 720), (1560, 540)],
        fill=(16, 42, 70, 44),
    )

    lines = Image.new("RGBA", SIZE_BG, (0, 0, 0, 0))
    draw = ImageDraw.Draw(lines, "RGBA")
    for offset in range(-420, 1420, 180):
        draw.line((offset, 0, offset + 820, 1080), fill=(*PALETTE["line_soft"], 20), width=1)
    for y in (248, 540, 832):
        draw.line((220, y, 1700, y), fill=(*PALETTE["line"], 12), width=1)

    ring_layer = Image.new("RGBA", SIZE_BG, (0, 0, 0, 0))
    draw = ImageDraw.Draw(ring_layer, "RGBA")
    center = (width // 2, height // 2 - 30)
    for radius, alpha in ((220, 24), (320, 18), (430, 14)):
        box = (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius)
        draw.arc(box, start=200, end=340, fill=(*PALETTE["line"], alpha), width=2)
        draw.arc(box, start=20, end=122, fill=(*PALETTE["line_soft"], max(alpha - 6, 8)), width=1)

    flow = Image.new("RGBA", SIZE_BG, (0, 0, 0, 0))
    draw = ImageDraw.Draw(flow, "RGBA")
    flow_points = [
        ((240, 760), (700, 640), (950, 510)),
        ((1680, 330), (1300, 420), (990, 520)),
        ((320, 270), (730, 410), (980, 530)),
    ]
    for start, mid, end in flow_points:
        draw.line((start, mid, end), fill=(*PALETTE["line"], 40), width=2)
        for point in (mid, end):
            x, y = point
            draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(*PALETTE["cyan"], 90))

    glow = Image.new("RGBA", SIZE_BG, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow, "RGBA")
    draw.ellipse((660, 210, 1260, 810), fill=(*PALETTE["blue"], 44))
    draw.ellipse((760, 320, 1160, 720), fill=(*PALETTE["cyan"], 28))
    glow = glow.filter(ImageFilter.GaussianBlur(70))

    final = Image.alpha_composite(base, planes)
    final = Image.alpha_composite(final, glow)
    final = Image.alpha_composite(final, lines)
    final = Image.alpha_composite(final, ring_layer)
    final = Image.alpha_composite(final, flow)
    return final.convert("RGB")


def build_progress_track() -> Image.Image:
    image = Image.new("RGBA", SIZE_TRACK, (0, 0, 0, 0))
    mask = round_rect_mask(SIZE_TRACK, 6)
    fill = Image.new("RGBA", SIZE_TRACK, (*PALETTE["graphite"], 158))
    fill.putalpha(mask.point(lambda p: min(128, p // 2)))
    image.alpha_composite(fill)

    outline = Image.new("RGBA", SIZE_TRACK, (0, 0, 0, 0))
    draw = ImageDraw.Draw(outline, "RGBA")
    draw.rounded_rectangle(
        (0, 0, SIZE_TRACK[0] - 1, SIZE_TRACK[1] - 1),
        radius=6,
        outline=(*PALETTE["steel"], 60),
        width=1,
    )
    image.alpha_composite(outline)
    return image


def build_progress_fill() -> Image.Image:
    width, height = SIZE_TRACK
    gradient = Image.new("RGBA", SIZE_TRACK, (0, 0, 0, 0))
    pixels = gradient.load()
    for x in range(width):
        t = x / max(width - 1, 1)
        color = mix(PALETTE["blue"], PALETTE["cyan"], min(1.0, t * 1.12))
        for y in range(height):
            alpha = 218 if 1 < y < height - 2 else 198
            pixels[x, y] = (*color, alpha)

    sheen = Image.new("RGBA", SIZE_TRACK, (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheen, "RGBA")
    draw.line((8, 2, width - 8, 2), fill=(255, 255, 255, 52), width=1)
    gradient = Image.alpha_composite(gradient, sheen)

    mask = round_rect_mask(SIZE_TRACK, 6)
    image = Image.new("RGBA", SIZE_TRACK, (0, 0, 0, 0))
    image.paste(gradient, mask=mask)
    return image


def shard_polygon(x: int, y: int, width: int, height: int, direction: str) -> list[tuple[int, int]]:
    half = height // 2
    if direction == "left":
        return [
            (x, y + half),
            (x + width // 3, y),
            (x + width, y),
            (x + width - width // 4, y + half),
            (x + width, y + height),
            (x + width // 3, y + height),
        ]
    return [
        (x + width, y + half),
        (x + width - width // 3, y),
        (x, y),
        (x + width // 4, y + half),
        (x, y + height),
        (x + width - width // 3, y + height),
    ]


def center_polygon(cx: int, y: int, width: int, height: int) -> list[tuple[int, int]]:
    half_w = width // 2
    half_h = height // 2
    return [
        (cx, y),
        (cx + half_w, y + half_h),
        (cx, y + height),
        (cx - half_w, y + half_h),
    ]


def build_frame(index: int) -> Image.Image:
    width, height = SIZE_FRAMES
    image = Image.new("RGBA", SIZE_FRAMES, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")

    base_pairs = [
        ("L4", shard_polygon(22, 11, 58, 18, "left")),
        ("L3", shard_polygon(76, 10, 56, 20, "left")),
        ("L2", shard_polygon(132, 9, 56, 22, "left")),
        ("L1", shard_polygon(188, 8, 54, 24, "left")),
        ("C", center_polygon(width // 2, 7, 34, 26)),
        ("R1", shard_polygon(206, 8, 54, 24, "right")),
        ("R2", shard_polygon(260, 9, 56, 22, "right")),
        ("R3", shard_polygon(316, 10, 56, 20, "right")),
        ("R4", shard_polygon(370, 11, 58, 18, "right")),
    ]

    stage_sequence = [0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3]
    stage = stage_sequence[index]
    pair_order = [("L4", "R4"), ("L3", "R3"), ("L2", "R2"), ("L1", "R1")]
    active_names = set()
    trail_names = set()
    if stage == 4:
        active_names.add("C")
        trail_names.update(("L1", "R1"))
    else:
        active_names.update(pair_order[stage])
        if stage > 0:
            trail_names.update(pair_order[stage - 1])

    glow = Image.new("RGBA", SIZE_FRAMES, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow, "RGBA")

    for name, polygon in base_pairs:
        fill = (*PALETTE["graphite_soft"], 96)
        outline = (*PALETTE["line_soft"], 44)
        if name in trail_names:
            fill = (*PALETTE["blue"], 120)
            outline = (*PALETTE["cyan"], 58)
        if name in active_names:
            fill = (*PALETTE["cyan"], 228)
            outline = (255, 255, 255, 110)
            xs = [point[0] for point in polygon]
            ys = [point[1] for point in polygon]
            glow_draw.polygon(
                [
                    (min(xs), min(ys)),
                    (max(xs), min(ys)),
                    (max(xs), max(ys)),
                    (min(xs), max(ys)),
                ],
                fill=(*PALETTE["blue"], 76),
            )
        draw.polygon(polygon, fill=fill, outline=outline)

    glow = glow.filter(ImageFilter.GaussianBlur(12))
    return Image.alpha_composite(glow, image)


def save_png(image: Image.Image, path: Path) -> None:
    image.save(path, format="PNG", optimize=True, compress_level=9)


def main() -> None:
    FRAMES_DIR.mkdir(parents=True, exist_ok=True)

    save_png(extract_logo(), THEME_DIR / "logo.png")
    save_png(build_gradient_background(), THEME_DIR / "background.png")
    save_png(build_progress_track(), THEME_DIR / "progress-track.png")
    save_png(build_progress_fill(), THEME_DIR / "progress-fill.png")

    for idx in range(12):
        save_png(build_frame(idx), FRAMES_DIR / f"frame-{idx + 1:02d}.png")


if __name__ == "__main__":
    main()
