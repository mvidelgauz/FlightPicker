#!/usr/bin/env python3
"""
split_kayak.py - Split a Kayak full-page screenshot into individual flight cards.

Usage:
    python split_kayak.py <image.png> [--debug]

Output:
    <image>_cards/  - folder with one PNG per expanded card
    <image>_cards/debug/  - debug images (if --debug)
"""

import sys
import os
import argparse
from PIL import Image
import numpy as np


def find_orange_buttons(img_array):
    """
    Find rows containing orange 'Select' buttons.
    Orange color range: R high, G medium, B low.
    Returns list of (start_row, end_row) tuples.
    """
    r = img_array[:, :, 0].astype(int)
    g = img_array[:, :, 1].astype(int)
    b = img_array[:, :, 2].astype(int)

    # Orange pixel: R > 200, G between 80-160, B < 60
    orange_mask = (r > 200) & (g > 80) & (g < 160) & (b < 60)

    # Count orange pixels per row
    orange_per_row = orange_mask.sum(axis=1)

    # A row is "orange button" if it has enough orange pixels (button is wide)
    threshold = 50  # minimum orange pixels to count as button row
    is_button_row = orange_per_row > threshold

    # Group consecutive button rows into buttons
    buttons = []
    in_button = False
    start = 0
    for i, val in enumerate(is_button_row):
        if val and not in_button:
            in_button = True
            start = i
        elif not val and in_button:
            in_button = False
            buttons.append((start, i))
    if in_button:
        buttons.append((start, len(is_button_row)))

    return buttons


def classify_buttons(buttons):
    """
    Classify buttons as 'collapsed' (small, ~56px) or 'expanded' (large, ~69px).
    Collapsed buttons are summary rows; expanded are detail rows.
    """
    classified = []
    for start, end in buttons:
        height = end - start
        # Collapsed summary buttons are ~50-60px, expanded detail buttons ~65-75px
        if height < 63:
            classified.append((start, end, 'collapsed'))
        else:
            classified.append((start, end, 'expanded'))
    return classified


def build_segments(buttons, total_rows):
    """
    Build segments between buttons.
    Each segment spans from end of one button to end of next button.
    Alternates: collapsed card summary -> expanded card detail.
    """
    segments = []
    prev_end = 0

    for i, (start, end, kind) in enumerate(buttons):
        seg_start = prev_end
        seg_end = end + 15  # small padding past button bottom
        seg_end = min(seg_end, total_rows)
        segments.append((seg_start, seg_end, kind))
        prev_end = seg_end

    # Last segment to end of image
    if prev_end < total_rows:
        # Determine kind based on last button
        last_kind = buttons[-1][2] if buttons else 'expanded'
        segments.append((prev_end, total_rows, last_kind))

    return segments


def save_debug_button(img_array, button_idx, btn_start, btn_end, btn_kind, out_dir, context=200):
    """Save a debug image showing the button area with context."""
    h = img_array.shape[0]
    top = max(0, btn_start - context)
    bot = min(h, btn_end + context)
    crop = img_array[top:bot, :, :]
    img = Image.fromarray(crop.astype(np.uint8))

    # Draw red rectangle around button area
    from PIL import ImageDraw
    draw = ImageDraw.Draw(img)
    btn_top_in_crop = btn_start - top
    btn_bot_in_crop = btn_end - top
    draw.rectangle([0, btn_top_in_crop, img.width - 1, btn_bot_in_crop],
                   outline=(255, 0, 0), width=3)

    # Add label
    try:
        from PIL import ImageFont
        font = ImageFont.load_default()
    except Exception:
        font = None
    label = f"Button {button_idx} (row {btn_start})"
    draw.text((5, btn_top_in_crop - 20 if btn_top_in_crop > 20 else btn_top_in_crop + 5),
              label, fill=(255, 0, 0), font=font)

    path = os.path.join(out_dir, f"debug_button_{button_idx:02d}.png")
    img.save(path)
    return path


def main():
    parser = argparse.ArgumentParser(description='Split Kayak screenshot into flight cards')
    parser.add_argument('image', help='Input PNG screenshot')
    parser.add_argument('--debug', action='store_true', help='Save debug images')
    args = parser.parse_args()

    if not os.path.exists(args.image):
        print(f"Error: file not found: {args.image}")
        sys.exit(1)

    img = Image.open(args.image).convert('RGB')
    img_array = np.array(img)
    h, w = img_array.shape[:2]
    print(f"Image: {w} x {h} pixels")

    # Find orange Select buttons
    raw_buttons = find_orange_buttons(img_array)
    classified = classify_buttons(raw_buttons)

    print(f"Found {len(classified)} orange 'Select' buttons")
    for i, (start, end, kind) in enumerate(classified, 1):
        print(f"  Button {i}: rows {start}-{end} ({end-start}px)")

    # Build segments
    segments = build_segments(classified, h)

    # Print segments
    print(f"{len(segments)} segments:")
    for i, (start, end, kind) in enumerate(segments, 1):
        label = "[EXPANDED]" if kind == 'expanded' else "[collapsed]"
        print(f"  {i:3d}. rows {start:6d}-{end:6d}  ({end-start:5d}px)  {label}")

    # Output directory
    base = os.path.splitext(os.path.basename(args.image))[0]
    out_dir = base + "_cards"
    os.makedirs(out_dir, exist_ok=True)

    if args.debug:
        debug_dir = os.path.join(out_dir, "debug")
        os.makedirs(debug_dir, exist_ok=True)

    # Save expanded cards (min 400px to filter noise)
    min_height = 400
    expanded = [(s, e, k) for s, e, k in segments if k == 'expanded' and (e - s) >= min_height]
    print(f"Keeping {len(expanded)} expanded cards (>={min_height}px)")

    for i, (start, end, kind) in enumerate(expanded, 1):
        crop = img_array[start:end, :, :]
        card_img = Image.fromarray(crop.astype(np.uint8))
        out_path = os.path.join(out_dir, f"{base}_card_{i:03d}.png")
        card_img.save(out_path)
        print(f"  -> {out_path}")

    # Save debug images for first 6 buttons
    if args.debug:
        for i, (start, end, kind) in enumerate(classified[:6], 1):
            path = save_debug_button(img_array, i, start, end, kind, debug_dir)
            print(f"  Debug: {path}")

        # Save overview (thumbnail of full image)
        thumb = img.copy()
        thumb.thumbnail((300, 3000))
        thumb.save(os.path.join(debug_dir, "overview.png"))
        print(f"  Debug overview: {os.path.join(debug_dir, 'overview.png')}")

    print("=" * 50)
    print(f"Done! {len(expanded)} expanded cards saved.")


if __name__ == '__main__':
    main()
