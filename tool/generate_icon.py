#!/usr/bin/env python3
"""Generates the app icon source images.

The icon is drawn here, in code, rather than checked in as an opaque binary:
that way it is reviewable, tweakable (the constants below are the whole design),
and reproducible without any image tooling installed. It writes a PNG encoder by
hand for the same reason — no Pillow, no ImageMagick, no build-machine setup.

    python tool/generate_icon.py

Then regenerate the per-platform outputs:

    dart run flutter_launcher_icons

The design: an open sefer, cream on the app's deep blue, with the ruled lines of
text suggested rather than drawn. Two files come out —

  assets/icon/icon.png             full-bleed, for legacy Android/Windows
  assets/icon/icon_foreground.png  transparent, inset for Android's adaptive
                                   mask (which crops aggressively)
"""

import struct
import zlib
from array import array

SIZE = 1024
SUBSAMPLES = 3  # vertical supersampling for anti-aliasing

BACKGROUND = (0x2E, 0x4A, 0x8C)   # deep blue — the app's seed colour, darkened
PAGE = (0xF6, 0xF1, 0xE4)         # warm cream, like paper
INK = (0x3B, 0x5B, 0xA5)          # the ruled lines, in the app's primary


def book_polygons(scale, cx, cy):
    """The open sefer, as polygons in a 1024-space centred on (cx, cy).

    `scale` is the fraction of the canvas the book occupies. Both pages are
    trapezoids meeting at a gap in the middle; the outer edges sit lower than
    the spine, which is what reads as "open book" rather than "two rectangles".
    """
    def pt(x, y):
        return (cx + (x - 512) * scale, cy + (y - 512) * scale)

    left_page = [pt(110, 335), pt(496, 288), pt(496, 762), pt(110, 715)]
    right_page = [pt(528, 288), pt(914, 335), pt(914, 715), pt(528, 762)]

    lines = []
    # Four ruled lines per page; the last is short, like the end of a paragraph.
    for fraction, width in ((0.17, 1.0), (0.33, 1.0), (0.49, 1.0), (0.65, 1.0),
                            (0.81, 0.55)):
        for side in (-1, 1):
            near_x, far_x = (452, 168) if side < 0 else (572, 856)
            far_x = near_x + (far_x - near_x) * width
            # Interpolate the page's own top and bottom edges at each end.
            def edge(x, top_near, top_far, bot_near, bot_far):
                u = (x - near_x) / (far_x - near_x) if far_x != near_x else 0
                return (top_near + (top_far - top_near) * u,
                        bot_near + (bot_far - bot_near) * u)

            # Both ends interpolate the page's own sloping top and bottom, so
            # the ruled lines follow the page rather than cutting across it.
            t0, b0 = edge(near_x, 294, 341, 756, 709)
            t1, b1 = edge(far_x, 294, 341, 756, 709)

            y0 = t0 + (b0 - t0) * fraction
            y1 = t1 + (b1 - t1) * fraction
            half = 15
            lines.append([
                pt(near_x, y0 - half), pt(far_x, y1 - half),
                pt(far_x, y1 + half), pt(near_x, y0 + half),
            ])

    return [left_page, right_page], lines


def coverage(polygons, size=SIZE, subsamples=SUBSAMPLES):
    """Anti-aliased coverage in [0,1] per pixel for a set of polygons.

    Scanline fill: for each sub-row, find where the polygon edges cross it and
    fill the spans between crossings, adding fractional weight at the ends. Far
    cheaper than testing every sub-pixel, and exact enough for an icon.
    """
    cov = array('f', bytes(4 * size * size))
    weight = 1.0 / subsamples

    for sub in range(size * subsamples):
        y = (sub + 0.5) / subsamples
        row_base = (sub // subsamples) * size
        for poly in polygons:
            crossings = []
            n = len(poly)
            for i in range(n):
                x0, y0 = poly[i]
                x1, y1 = poly[(i + 1) % n]
                if (y0 <= y < y1) or (y1 <= y < y0):
                    t = (y - y0) / (y1 - y0)
                    crossings.append(x0 + (x1 - x0) * t)
            if len(crossings) < 2:
                continue
            crossings.sort()
            for i in range(0, len(crossings) - 1, 2):
                _fill_span(cov, row_base, size, crossings[i], crossings[i + 1],
                           weight)
    return cov


def _fill_span(cov, row_base, size, xa, xb, weight):
    if xb <= xa:
        return
    xa = max(xa, 0.0)
    xb = min(xb, float(size))
    if xb <= xa:
        return
    first, last = int(xa), int(xb)
    if first == last:
        cov[row_base + first] += (xb - xa) * weight
        return
    cov[row_base + first] += (first + 1 - xa) * weight
    for x in range(first + 1, min(last, size)):
        cov[row_base + x] += weight
    if last < size:
        cov[row_base + last] += (xb - last) * weight


def compose(page_cov, line_cov, background):
    """Blends the layers into RGBA bytes. `background` is None for transparent."""
    out = bytearray()
    for y in range(SIZE):
        out.append(0)  # PNG filter type 0 for this scanline
        base = y * SIZE
        for x in range(SIZE):
            p = min(page_cov[base + x], 1.0)
            l = min(line_cov[base + x], 1.0)
            if background is None:
                alpha = p
                if alpha <= 0.0:
                    out.extend((0, 0, 0, 0))
                    continue
                rgb = _mix(PAGE, INK, l / alpha if alpha > 0 else 0)
                out.extend((*[int(round(c)) for c in rgb], int(round(alpha * 255))))
            else:
                rgb = _mix(background, PAGE, p)
                rgb = _mix(rgb, INK, l)
                out.extend((*[int(round(c)) for c in rgb], 255))
    return bytes(out)


def _mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def write_png(path, raw):
    """Minimal PNG writer: signature, IHDR, IDAT, IEND. 8-bit RGBA."""
    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data +
                struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))

    header = struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0)
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) +
           chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)
    print(f'wrote {path} ({len(png):,} bytes)')


def render(path, scale, background):
    pages, lines = book_polygons(scale, SIZE / 2, SIZE / 2)
    write_png(path, compose(coverage(pages), coverage(lines), background))


if __name__ == '__main__':
    import os
    os.makedirs('assets/icon', exist_ok=True)
    # Full-bleed: the book fills most of the tile.
    render('assets/icon/icon.png', 1.0, BACKGROUND)
    # Adaptive foreground: Android crops to a circle/squircle inside the middle
    # ~66%, so the book has to sit well inside that.
    render('assets/icon/icon_foreground.png', 0.62, None)
