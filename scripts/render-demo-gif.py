#!/usr/bin/env python3
"""
Render an animated GIF demo of DockBuddies without running the app.

Recreates the 16×16 pixel-art agents, bounce/blink/glow animations,
status bubbles, and a mock dock bar — then composites everything into
a looping GIF suitable for the README.

Usage:
    python3 scripts/render-demo-gif.py          # writes Resources/demo.gif
"""

import math
from PIL import Image, ImageDraw, ImageFont

# ── Sprite definition (matches AgentSprite.swift) ────────────────────────

SPRITE_RAW = [
    "......T..T......",
    "......A..A......",
    "......A..A......",
    "....DBBBBBD.....",
    "...DBBBBBBBD....",
    "..DBEEPBEEPBD...",
    "..DBEEPBEEPBD...",
    "..DBBMMMBBBBD...",
    "..DBBBBBBBBD....",
    "...DBBBBBBBD....",
    "...DBBBBBBD.....",
    "....DBBBBBD.....",
    "....DBBBBBD.....",
    "...FF....FF.....",
    "...FF....FF.....",
    "................",
]

BLINK_OVERRIDES = {
    # row 5: eyes → body, row 6: eyes → bodyDark
    (5, "E"): "B",
    (5, "P"): "B",
    (6, "E"): "D",
    (6, "P"): "D",
}

# ── Color palettes (matches AgentColor.swift) ────────────────────────────

def rgb(r, g, b):
    return (int(r * 255), int(g * 255), int(b * 255))

PALETTES = {
    "orange": {
        "B": rgb(0.85, 0.55, 0.20),
        "D": rgb(0.65, 0.40, 0.15),
        "E": (255, 255, 255),
        "P": rgb(0.15, 0.10, 0.10),
        "A": rgb(0.50, 0.35, 0.15),
        "T": rgb(1.0, 0.8, 0.3),
        "F": rgb(0.65, 0.40, 0.15),
        "M": rgb(0.45, 0.30, 0.15),
    },
    "green": {
        "B": rgb(0.30, 0.75, 0.30),
        "D": rgb(0.20, 0.55, 0.20),
        "E": (255, 255, 255),
        "P": rgb(0.10, 0.15, 0.10),
        "A": rgb(0.20, 0.50, 0.20),
        "T": rgb(0.5, 1.0, 0.3),
        "F": rgb(0.20, 0.55, 0.20),
        "M": rgb(0.15, 0.40, 0.15),
    },
    "red": {
        "B": rgb(0.85, 0.25, 0.25),
        "D": rgb(0.65, 0.18, 0.18),
        "E": (255, 255, 255),
        "P": rgb(0.15, 0.10, 0.10),
        "A": rgb(0.55, 0.15, 0.15),
        "T": rgb(1.0, 0.3, 0.3),
        "F": rgb(0.65, 0.18, 0.18),
        "M": rgb(0.50, 0.15, 0.15),
    },
    "teal": {
        "B": rgb(0.20, 0.75, 0.70),
        "D": rgb(0.15, 0.55, 0.50),
        "E": (255, 255, 255),
        "P": rgb(0.10, 0.10, 0.15),
        "A": rgb(0.15, 0.50, 0.45),
        "T": rgb(0.3, 1.0, 0.9),
        "F": rgb(0.15, 0.55, 0.50),
        "M": rgb(0.10, 0.40, 0.35),
    },
}

# ── Agent definitions ────────────────────────────────────────────────────

AGENTS = [
    {"color": "orange", "status": "EDITING"},
    {"color": "green",  "status": "SEARCHING"},
    {"color": "red",    "status": "THINKING"},
    {"color": "teal",   "status": "RUNNING TESTS"},
]

# ── Rendering constants ─────────────────────────────────────────────────

PIXEL_SIZE = 5
SPRITE_W = 16 * PIXEL_SIZE  # 80
SPRITE_H = 16 * PIXEL_SIZE  # 80
AGENT_SPACING = 36
BUBBLE_PAD_H = 10
BUBBLE_PAD_V = 5
BUBBLE_CORNER = 6
BUBBLE_GAP = 6           # gap between bubble bottom and sprite top
TRIANGLE_H = 7
DOCK_HEIGHT = 8
DOCK_MARGIN = 16

# Animation
FPS = 20
DURATION_SEC = 4.0
TOTAL_FRAMES = int(FPS * DURATION_SEC)
FRAME_MS = int(1000 / FPS)

# Blink schedule: list of (start_frame, duration_frames) per agent
BLINK_SCHEDULE = [
    [(12, 3), (52, 3)],   # orange
    [(25, 3), (60, 3)],   # green
    [(8, 3), (45, 3)],    # red
    [(35, 3), (70, 3)],   # teal
]

# ── Helpers ──────────────────────────────────────────────────────────────

def draw_sprite(draw, x, y, palette, is_blink, glow_factor):
    """Draw a 16×16 sprite at (x, y) with the given palette."""
    for row_i, row_str in enumerate(SPRITE_RAW):
        for col_i, ch in enumerate(row_str):
            if ch == ".":
                continue

            actual_ch = ch
            if is_blink and (row_i, ch) in BLINK_OVERRIDES:
                actual_ch = BLINK_OVERRIDES[(row_i, ch)]

            color = palette.get(actual_ch)
            if not color:
                continue

            # Antenna glow: brighten antennaTop toward white
            if actual_ch == "T":
                r, g, b = color
                r = int(r + (255 - r) * glow_factor * 0.5)
                g = int(g + (255 - g) * glow_factor * 0.5)
                b = int(b + (255 - b) * glow_factor * 0.5)
                color = (min(r, 255), min(g, 255), min(b, 255))

            px = x + col_i * PIXEL_SIZE
            py = y + row_i * PIXEL_SIZE
            draw.rectangle([px, py, px + PIXEL_SIZE - 1, py + PIXEL_SIZE - 1], fill=color)


def measure_text(text, font):
    """Return (width, height) for text using a temporary image."""
    tmp = Image.new("RGBA", (1, 1))
    d = ImageDraw.Draw(tmp)
    bbox = d.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def draw_rounded_rect(draw, xy, radius, fill):
    """Draw a filled rounded rectangle."""
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_bubble(draw, cx, bottom_y, text, font):
    """Draw a status bubble centered at cx, with its bottom at bottom_y."""
    tw, th = measure_text(text, font)
    bw = tw + BUBBLE_PAD_H * 2
    bh = th + BUBBLE_PAD_V * 2

    bx = cx - bw // 2
    by = bottom_y - TRIANGLE_H - bh

    bubble_color = (15, 15, 15)
    draw_rounded_rect(draw, (bx, by, bx + bw, by + bh), BUBBLE_CORNER, fill=bubble_color)

    # Triangle pointer
    tri_cx = cx
    tri_top = by + bh
    tri_bot = tri_top + TRIANGLE_H
    draw.polygon([
        (tri_cx, tri_bot),
        (tri_cx - 5, tri_top),
        (tri_cx + 5, tri_top),
    ], fill=bubble_color)

    # Text
    tx = bx + BUBBLE_PAD_H
    ty = by + BUBBLE_PAD_V
    draw.text((tx, ty), text, fill=(255, 255, 255), font=font)


def draw_dock_bar(draw, y, width, height):
    """Draw a rounded dock bar."""
    margin = DOCK_MARGIN
    draw_rounded_rect(
        draw,
        (margin, y, width - margin, y + height),
        radius=6,
        fill=(50, 50, 50),
    )


def try_load_font(size):
    """Try to load a monospace font, fall back to default."""
    paths = [
        "/System/Library/Fonts/SFMono-Bold.otf",
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.dfont",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


# ── Main rendering ───────────────────────────────────────────────────────

def render_gif(output_path="Resources/demo.gif"):
    font = try_load_font(11)

    # Compute canvas size
    n = len(AGENTS)
    content_w = n * SPRITE_W + (n - 1) * AGENT_SPACING
    canvas_w = content_w + DOCK_MARGIN * 2 + 20
    # Height: bubble + gap + sprite + dock
    max_bubble_h = 0
    for agent in AGENTS:
        _, th = measure_text(agent["status"], font)
        bh = th + BUBBLE_PAD_V * 2 + TRIANGLE_H + BUBBLE_GAP
        max_bubble_h = max(max_bubble_h, bh)

    bounce_room = 8
    canvas_h = max_bubble_h + bounce_room + SPRITE_H + DOCK_HEIGHT + 20

    # Baseline Y: bottom of sprite (without bounce) just above dock
    dock_y = canvas_h - DOCK_HEIGHT - 8
    sprite_baseline_y = dock_y - 4 - SPRITE_H

    # X positions (centered)
    start_x = (canvas_w - content_w) // 2
    agent_xs = [start_x + i * (SPRITE_W + AGENT_SPACING) for i in range(n)]

    frames = []

    for frame_i in range(TOTAL_FRAMES):
        t = frame_i / FPS
        img = Image.new("RGB", (canvas_w, canvas_h), (30, 30, 30))
        draw = ImageDraw.Draw(img)

        # Dock bar
        draw_dock_bar(draw, dock_y, canvas_w, DOCK_HEIGHT)

        for agent_i, agent in enumerate(AGENTS):
            palette = PALETTES[agent["color"]]
            ax = agent_xs[agent_i]

            # Bounce: sin wave with per-agent phase offset
            phase = agent_i * 0.3
            bounce = math.sin((t + phase) * 2.5) * 5.0

            # Blink
            is_blink = False
            for bstart, bdur in BLINK_SCHEDULE[agent_i]:
                if bstart <= frame_i < bstart + bdur:
                    is_blink = True
                    break

            # Antenna glow
            glow = 0.6 + 0.4 * math.sin((t + phase) * 3.0)

            sy = sprite_baseline_y + int(bounce)
            draw_sprite(draw, ax, sy, palette, is_blink, glow)

            # Status bubble
            cx = ax + SPRITE_W // 2
            bubble_bot = sy - BUBBLE_GAP
            draw_bubble(draw, cx, bubble_bot, agent["status"], font)

        frames.append(img)

    # Save GIF
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=FRAME_MS,
        loop=0,
        optimize=False,
    )
    print(f"✅ Wrote {output_path} ({len(frames)} frames, {canvas_w}×{canvas_h}px)")


if __name__ == "__main__":
    render_gif()
