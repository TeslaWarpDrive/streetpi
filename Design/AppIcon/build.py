"""Render icon.svg to the app icon PNG.

Design-time only: needs cairosvg and Pillow on the machine that runs it.
Neither is part of the app or StreetPiCore.

    python3 build.py

Writes AppIcon-1024.png next to this file: 1024x1024, RGB, no alpha.
Copy it over StreetPi/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png.
"""

import io
from pathlib import Path

import cairosvg
from PIL import Image

here = Path(__file__).resolve().parent
png = cairosvg.svg2png(url=str(here / "icon.svg"), output_width=1024, output_height=1024)
Image.open(io.BytesIO(png)).convert("RGB").save(here / "AppIcon-1024.png")
