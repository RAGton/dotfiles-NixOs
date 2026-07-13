#!/usr/bin/env python3
"""Generate the RAGOS Plasma wallpaper collections.

The goal is to keep the wallpaper source reproducible in the repo while moving
away from the placeholder single-image backgrounds. Each variant gets three
slides with a restrained technical landscape and a subtle RAGOS mark.
"""

from __future__ import annotations

import argparse
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


DEFAULT_SIZE = (5120, 2880)

PALETTES = {
    "dark": {
        "sky_top": (8, 16, 32),
        "sky_mid": (18, 34, 62),
        "sky_bottom": (16, 34, 54),
        "haze": (84, 144, 210),
        "accent": (76, 170, 236),
        "accent_soft": (111, 201, 246),
        "water": (10, 26, 48),
        "line": (120, 192, 232),
        "panel": (9, 18, 30),
        "text": (212, 228, 242),
    },
    "light": {
        "sky_top": (194, 214, 232),
        "sky_mid": (176, 198, 220),
        "sky_bottom": (160, 182, 204),
        "haze": (118, 154, 188),
        "accent": (62, 126, 181),
        "accent_soft": (104, 166, 212),
        "water": (104, 126, 148),
        "line": (90, 132, 168),
        "panel": (220, 230, 238),
        "text": (30, 44, 58),
    },
}

SCENES = ("alpine", "mesa", "coast")


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


def rgba(color: tuple[int, int, int], alpha: int) -> tuple[int, int, int, int]:
    return (*color, alpha)


def sample_bg_color(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    samples = [
        rgb.getpixel((0, 0)),
        rgb.getpixel((rgb.width - 1, 0)),
        rgb.getpixel((0, rgb.height - 1)),
        rgb.getpixel((rgb.width - 1, rgb.height - 1)),
    ]
    return tuple(sum(px[i] for px in samples) // len(samples) for i in range(3))


def extract_logo(logo_source: Path) -> Image.Image:
    base = Image.open(logo_source).convert("RGB")
    bg = sample_bg_color(base)
    diff = ImageChops.difference(base, Image.new("RGB", base.size, bg))
    r, g, b = diff.split()
    mask = ImageChops.lighter(ImageChops.lighter(r, g), b)
    mask = mask.point(lambda p: 0 if p < 14 else min(255, int((p - 14) * 255 / 48)))
    mask = mask.filter(ImageFilter.GaussianBlur(0.8))

    rgba_logo = base.convert("RGBA")
    rgba_logo.putalpha(mask)
    bbox = mask.getbbox()
    if not bbox:
        raise RuntimeError("Failed to extract RAGOS logo alpha mask.")
    return rgba_logo.crop(bbox)


def make_gradient(size: tuple[int, int], top: tuple[int, int, int], mid: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size)
    pixels = image.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        if t < 0.55:
            color = mix(top, mid, t / 0.55)
        else:
            color = mix(mid, bottom, (t - 0.55) / 0.45)
        for x in range(width):
            pixels[x, y] = color
    return image


def add_noise(image: Image.Image, opacity: float) -> Image.Image:
    noise = Image.effect_noise(image.size, 10).convert("L")
    noise = ImageEnhance.Contrast(noise).enhance(0.65)
    noise_rgba = Image.merge("RGBA", (noise, noise, noise, noise.point(lambda p: int(p * opacity))))
    return Image.alpha_composite(image.convert("RGBA"), noise_rgba)


def draw_glow(canvas: Image.Image, box: tuple[int, int, int, int], color: tuple[int, int, int], alpha: int, blur: int) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.ellipse(box, fill=rgba(color, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(layer)


def draw_stars(draw: ImageDraw.ImageDraw, size: tuple[int, int], rng: random.Random, alpha: int) -> None:
    width, height = size
    for _ in range(85):
        x = rng.randint(0, width)
        y = rng.randint(0, int(height * 0.44))
        r = rng.randint(1, 4)
        a = rng.randint(alpha // 2, alpha)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(230, 242, 255, a))


def ridge_points(width: int, height: int, anchors: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(int(width * x), int(height * y)) for x, y in anchors]


def draw_polygon_layer(canvas: Image.Image, points: list[tuple[int, int]], color: tuple[int, int, int], alpha: int) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.polygon(points, fill=rgba(color, alpha))
    canvas.alpha_composite(layer)


def draw_water_reflection(canvas: Image.Image, horizon_y: int, strength: float) -> None:
    top = canvas.crop((0, 0, canvas.width, horizon_y)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    top = top.crop((0, 0, canvas.width, canvas.height - horizon_y))
    top = top.filter(ImageFilter.GaussianBlur(10))
    mask = Image.new("L", top.size)
    mask_draw = ImageDraw.Draw(mask)
    for y in range(top.height):
        alpha = int(180 * (1 - (y / max(top.height - 1, 1))) * strength)
        mask_draw.line((0, y, top.width, y), fill=max(alpha, 0))
    reflection = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    reflection.paste(top, (0, horizon_y), mask)
    canvas.alpha_composite(reflection)


def draw_logo(canvas: Image.Image, logo: Image.Image, variant: str, scale: float, y_ratio: float) -> None:
    target_width = int(canvas.width * scale)
    target_height = int(logo.height * (target_width / logo.width))
    mark = logo.resize((target_width, target_height), Image.Resampling.LANCZOS)
    if variant == "light":
        mark = ImageEnhance.Color(mark).enhance(0.72)
        mark = ImageEnhance.Brightness(mark).enhance(0.82)
        alpha_gain = 58
    else:
        mark = ImageEnhance.Color(mark).enhance(0.95)
        alpha_gain = 82
    alpha = mark.getchannel("A").point(lambda p: min(alpha_gain, int(p * alpha_gain / 255)))
    mark.putalpha(alpha)

    glow = Image.new("RGBA", mark.size, (0, 0, 0, 0))
    glow_alpha = alpha.filter(ImageFilter.GaussianBlur(18)).point(lambda p: min(54, p))
    glow.paste((96, 181, 237, 0), (0, 0), glow_alpha)

    x = (canvas.width - mark.width) // 2
    y = int(canvas.height * y_ratio)
    canvas.alpha_composite(glow, (x, y))
    canvas.alpha_composite(mark, (x, y))


def draw_tech_lines(canvas: Image.Image, palette: dict[str, tuple[int, int, int]], variant: str, scene: str) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    width, height = canvas.size
    opacity = 42 if variant == "dark" else 34
    if scene == "alpine":
        for offset in range(-400, width + 600, 480):
            draw.line((offset, int(height * 0.04), offset + 1000, int(height * 0.95)), fill=rgba(palette["line"], opacity), width=2)
        for y in (int(height * 0.22), int(height * 0.74)):
            draw.line((int(width * 0.14), y, int(width * 0.92), y), fill=rgba(palette["line"], opacity // 2), width=2)
    elif scene == "mesa":
        for x in range(int(width * 0.08), int(width * 0.95), 520):
            draw.arc((x - 760, int(height * 0.18), x + 760, int(height * 1.12)), start=238, end=332, fill=rgba(palette["line"], opacity), width=3)
        draw.line((int(width * 0.16), int(height * 0.72), int(width * 0.88), int(height * 0.72)), fill=rgba(palette["line"], opacity // 2), width=2)
    else:
        for step in range(0, 6):
            shrink = step * 180
            draw.arc(
                (int(width * 0.52) - 1300 + shrink, int(height * 0.08) + shrink // 2, int(width * 0.52) + 1300 - shrink, int(height * 1.06) - shrink // 2),
                start=206,
                end=320,
                fill=rgba(palette["line"], max(18, opacity - step * 5)),
                width=2,
            )
        for x, y in ((0.77, 0.18), (0.84, 0.3), (0.7, 0.56), (0.88, 0.7)):
            px = int(width * x)
            py = int(height * y)
            draw.ellipse((px - 8, py - 8, px + 8, py + 8), fill=rgba(palette["accent_soft"], 120))
    canvas.alpha_composite(layer)


def build_alpine(size: tuple[int, int], variant: str, logo: Image.Image) -> Image.Image:
    palette = PALETTES[variant]
    base = make_gradient(size, palette["sky_top"], palette["sky_mid"], palette["sky_bottom"]).convert("RGBA")
    draw = ImageDraw.Draw(base, "RGBA")
    width, height = size

    if variant == "dark":
        draw_glow(base, (int(width * 0.28), int(height * 0.12), int(width * 0.74), int(height * 0.54)), palette["accent"], 76, 120)
        draw_stars(draw, size, random.Random(11), 180)
        draw.ellipse((int(width * 0.48), int(height * 0.1), int(width * 0.54), int(height * 0.18)), fill=(240, 246, 255, 218))
        draw.ellipse((int(width * 0.49), int(height * 0.105), int(width * 0.545), int(height * 0.18)), fill=rgba(palette["sky_top"], 255))
    else:
        draw_glow(base, (int(width * 0.22), int(height * 0.08), int(width * 0.76), int(height * 0.48)), palette["accent_soft"], 64, 110)
        draw.ellipse((int(width * 0.46), int(height * 0.11), int(width * 0.56), int(height * 0.27)), fill=rgba((244, 248, 252), 210))

    ranges = [
        ([(0, 0.6), (0.14, 0.48), (0.26, 0.56), (0.4, 0.34), (0.53, 0.54), (0.68, 0.4), (0.82, 0.57), (1, 0.46), (1, 1), (0, 1)], mix(palette["sky_bottom"], (12, 24, 40), 0.15 if variant == "dark" else 0.45), 255),
        ([(0, 0.73), (0.16, 0.62), (0.31, 0.7), (0.48, 0.5), (0.67, 0.72), (0.83, 0.58), (1, 0.71), (1, 1), (0, 1)], mix(palette["water"], palette["haze"], 0.18 if variant == "dark" else 0.34), 255),
        ([(0, 0.82), (0.2, 0.74), (0.34, 0.78), (0.5, 0.66), (0.7, 0.8), (0.86, 0.72), (1, 0.79), (1, 1), (0, 1)], mix(palette["water"], palette["line"], 0.08 if variant == "dark" else 0.22), 255),
    ]
    for anchors, color, alpha in ranges:
        draw_polygon_layer(base, ridge_points(width, height, anchors), color, alpha)

    horizon = int(height * 0.7)
    water = Image.new("RGBA", size, (0, 0, 0, 0))
    water_draw = ImageDraw.Draw(water, "RGBA")
    water_draw.rectangle((0, horizon, width, height), fill=rgba(palette["water"], 196 if variant == "dark" else 146))
    base.alpha_composite(water)
    draw_water_reflection(base, horizon, 0.44 if variant == "dark" else 0.28)

    shoreline = [
        [(0, 0.84), (0.09, 0.8), (0.16, 0.82), (0.22, 0.78), (0.28, 0.82), (0.32, 1), (0, 1)],
        [(1, 0.84), (0.9, 0.8), (0.82, 0.81), (0.78, 0.77), (0.73, 0.82), (0.7, 1), (1, 1)],
    ]
    shore_color = mix(palette["sky_top"], palette["panel"], 0.7 if variant == "dark" else 0.55)
    for anchors in shoreline:
        draw_polygon_layer(base, ridge_points(width, height, anchors), shore_color, 255)

    draw_tech_lines(base, palette, variant, "alpine")
    draw_logo(base, logo, variant, 0.16, 0.78)
    return add_noise(base, 0.06 if variant == "dark" else 0.04).convert("RGB")


def build_mesa(size: tuple[int, int], variant: str, logo: Image.Image) -> Image.Image:
    palette = PALETTES[variant]
    if variant == "dark":
        base = make_gradient(size, (12, 18, 34), (34, 54, 86), (40, 32, 42)).convert("RGBA")
    else:
        base = make_gradient(size, (178, 196, 212), (201, 182, 174), (169, 154, 152)).convert("RGBA")
    draw = ImageDraw.Draw(base, "RGBA")
    width, height = size

    sun_color = (244, 202, 144) if variant == "light" else (250, 230, 200)
    sun_box = (int(width * 0.68), int(height * 0.14), int(width * 0.84), int(height * 0.34))
    draw_glow(base, (sun_box[0] - 220, sun_box[1] - 120, sun_box[2] + 220, sun_box[3] + 120), palette["accent_soft"], 72 if variant == "dark" else 58, 110)
    draw.ellipse(sun_box, fill=rgba(sun_color, 212 if variant == "dark" else 188))

    layers = [
        ([(0, 0.58), (0.18, 0.46), (0.34, 0.5), (0.52, 0.42), (0.68, 0.5), (0.86, 0.38), (1, 0.46), (1, 1), (0, 1)], mix((31, 29, 42), palette["sky_mid"], 0.22 if variant == "dark" else 0.48)),
        ([(0, 0.7), (0.14, 0.62), (0.32, 0.66), (0.5, 0.56), (0.7, 0.66), (0.84, 0.58), (1, 0.64), (1, 1), (0, 1)], mix((56, 46, 52), palette["panel"], 0.2 if variant == "dark" else 0.42)),
        ([(0, 0.84), (0.18, 0.8), (0.35, 0.82), (0.55, 0.74), (0.74, 0.8), (0.9, 0.76), (1, 0.8), (1, 1), (0, 1)], mix((64, 56, 62), palette["water"], 0.18 if variant == "dark" else 0.36)),
    ]
    for anchors, color in layers:
        draw_polygon_layer(base, ridge_points(width, height, anchors), color, 255)

    mesa_color = mix(palette["panel"], palette["accent"], 0.08 if variant == "dark" else 0.18)
    foregrounds = [
        [(0.08, 0.78), (0.18, 0.64), (0.26, 0.64), (0.31, 0.78), (0.31, 1), (0.08, 1)],
        [(0.42, 0.74), (0.52, 0.52), (0.62, 0.52), (0.69, 0.74), (0.69, 1), (0.42, 1)],
        [(0.74, 0.8), (0.81, 0.62), (0.89, 0.62), (0.95, 0.8), (0.95, 1), (0.74, 1)],
    ]
    for anchors in foregrounds:
        draw_polygon_layer(base, ridge_points(width, height, anchors), mesa_color, 255)

    draw_tech_lines(base, palette, variant, "mesa")
    draw_logo(base, logo, variant, 0.15, 0.79)
    return add_noise(base, 0.05 if variant == "dark" else 0.035).convert("RGB")


def build_coast(size: tuple[int, int], variant: str, logo: Image.Image) -> Image.Image:
    palette = PALETTES[variant]
    base = make_gradient(size, mix(palette["sky_top"], (6, 10, 16), 0.1 if variant == "dark" else 0.0), palette["sky_mid"], palette["sky_bottom"]).convert("RGBA")
    draw = ImageDraw.Draw(base, "RGBA")
    width, height = size

    draw_glow(base, (int(width * 0.62), int(height * 0.04), int(width * 0.94), int(height * 0.54)), palette["accent_soft"], 64 if variant == "dark" else 52, 118)

    ocean_horizon = int(height * 0.63)
    ocean = Image.new("RGBA", size, (0, 0, 0, 0))
    ocean_draw = ImageDraw.Draw(ocean, "RGBA")
    ocean_draw.rectangle((0, ocean_horizon, width, height), fill=rgba(mix(palette["water"], palette["sky_bottom"], 0.18), 220))
    base.alpha_composite(ocean)

    wave_layer = Image.new("RGBA", size, (0, 0, 0, 0))
    wave_draw = ImageDraw.Draw(wave_layer, "RGBA")
    for step in range(8):
        y = ocean_horizon + 80 + step * 90
        wave_draw.arc((int(width * -0.2), y - 120, int(width * 1.2), y + 120), start=192, end=348, fill=rgba(palette["line"], 26 - step * 2), width=3)
    base.alpha_composite(wave_layer)

    cliffs = [
        [(0, 0.84), (0.0, 0.58), (0.12, 0.54), (0.2, 0.72), (0.28, 0.7), (0.35, 0.86), (0.35, 1), (0, 1)],
        [(1, 0.84), (1.0, 0.5), (0.88, 0.46), (0.81, 0.62), (0.74, 0.6), (0.66, 0.86), (0.66, 1), (1, 1)],
    ]
    cliff_color = mix(palette["panel"], palette["sky_top"], 0.55 if variant == "dark" else 0.48)
    for anchors in cliffs:
        draw_polygon_layer(base, ridge_points(width, height, anchors), cliff_color, 255)

    if variant == "dark":
        draw_stars(draw, size, random.Random(29), 132)

    draw_tech_lines(base, palette, variant, "coast")
    draw_logo(base, logo, variant, 0.14, 0.78)
    return add_noise(base, 0.05 if variant == "dark" else 0.03).convert("RGB")


def build_scene(size: tuple[int, int], variant: str, scene: str, logo: Image.Image) -> Image.Image:
    if scene == "alpine":
        return build_alpine(size, variant, logo)
    if scene == "mesa":
        return build_mesa(size, variant, logo)
    if scene == "coast":
        return build_coast(size, variant, logo)
    raise ValueError(f"Unknown scene: {scene}")


def build_contact_sheet(slides: list[Image.Image], size: tuple[int, int], variant: str) -> Image.Image:
    width, height = size
    background = Image.new("RGBA", size, (*mix(PALETTES[variant]["sky_top"], PALETTES[variant]["panel"], 0.35), 255))
    draw = ImageDraw.Draw(background, "RGBA")
    margin = int(width * 0.045)
    gap = int(width * 0.018)
    card_w = (width - margin * 2 - gap * 2) // 3
    card_h = int(card_w * 9 / 16)
    top = (height - card_h) // 2

    for index, slide in enumerate(slides):
        x = margin + index * (card_w + gap)
        card = slide.resize((card_w, card_h), Image.Resampling.LANCZOS)
        shadow = Image.new("RGBA", (card_w + 40, card_h + 40), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow, "RGBA")
        shadow_draw.rounded_rectangle((20, 20, card_w + 20, card_h + 20), radius=34, fill=(0, 0, 0, 86 if variant == "dark" else 50))
        shadow = shadow.filter(ImageFilter.GaussianBlur(18))
        background.alpha_composite(shadow, (x - 20, top - 12))
        rounded_mask = Image.new("L", (card_w, card_h), 0)
        mask_draw = ImageDraw.Draw(rounded_mask)
        mask_draw.rounded_rectangle((0, 0, card_w, card_h), radius=28, fill=255)
        background.paste(card, (x, top), rounded_mask)
        draw.rounded_rectangle((x, top, x + card_w, top + card_h), radius=28, outline=rgba(PALETTES[variant]["line"], 120), width=3)
    return background.convert("RGB")


def write_collection(output_dir: Path, variant: str, size: tuple[int, int], logo: Image.Image) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    slides: list[Image.Image] = []
    for index, scene in enumerate(SCENES, start=1):
        slide = build_scene(size, variant, scene, logo)
        slide_path = output_dir / f"{index:02d}.png"
        slide.save(slide_path, quality=96)
        slides.append(slide)

    slides[0].save(output_dir / "featured.png", quality=96)
    contact = build_contact_sheet(slides, (1920, 1080), variant)
    contact.save(output_dir / "preview.png", quality=94)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dark-dir", type=Path, required=True)
    parser.add_argument("--light-dir", type=Path, required=True)
    parser.add_argument("--logo-source", type=Path, required=True)
    parser.add_argument("--width", type=int, default=DEFAULT_SIZE[0])
    parser.add_argument("--height", type=int, default=DEFAULT_SIZE[1])
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    size = (args.width, args.height)
    logo = extract_logo(args.logo_source)
    write_collection(args.dark_dir, "dark", size, logo)
    write_collection(args.light_dir, "light", size, logo)


if __name__ == "__main__":
    main()
