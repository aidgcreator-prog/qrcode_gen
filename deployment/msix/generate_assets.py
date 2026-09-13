"""Generate required Microsoft Store visual assets for MSIX packaging.

Reads image/logo_round.png and generates all standard Windows AppX / MSIX asset
resolutions and scale variations into deployment/msix/Assets/.
"""

import sys
from pathlib import Path
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_LOGO = PROJECT_ROOT / "image" / "logo_round.png"
OUTPUT_DIR = Path(__file__).resolve().parent / "Assets"


def make_centered_image(src: Image.Image, canvas_w: int, canvas_h: int, pad_ratio: float = 0.8) -> Image.Image:
    """Center src image inside a canvas of dimensions (canvas_w, canvas_h)."""
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    # Target size inside padding
    max_w = int(canvas_w * pad_ratio)
    max_h = int(canvas_h * pad_ratio)
    scale = min(max_w / src.width, max_h / src.height)
    new_w = max(1, int(src.width * scale))
    new_h = max(1, int(src.height * scale))

    resized = src.resize((new_w, new_h), Image.Resampling.LANCZOS)
    offset_x = (canvas_w - new_w) // 2
    offset_y = (canvas_h - new_h) // 2
    canvas.paste(resized, (offset_x, offset_y), resized)
    return canvas


def main() -> None:
    if not SOURCE_LOGO.exists():
        print(f"Error: Source image not found at {SOURCE_LOGO}", file=sys.stderr)
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    src = Image.open(SOURCE_LOGO).convert("RGBA")

    # Target asset specifications: (filename, width, height, is_canvas)
    specs = [
        # Store Logo
        ("StoreLogo.png", 50, 50, True),
        ("StoreLogo.scale-100.png", 50, 50, True),
        ("StoreLogo.scale-125.png", 63, 63, True),
        ("StoreLogo.scale-150.png", 75, 75, True),
        ("StoreLogo.scale-200.png", 100, 100, True),
        ("StoreLogo.scale-400.png", 200, 200, True),

        # Square 44x44 Logo
        ("Square44x44Logo.png", 44, 44, True),
        ("Square44x44Logo.scale-100.png", 44, 44, True),
        ("Square44x44Logo.scale-125.png", 55, 55, True),
        ("Square44x44Logo.scale-150.png", 66, 66, True),
        ("Square44x44Logo.scale-200.png", 88, 88, True),
        ("Square44x44Logo.scale-400.png", 176, 176, True),
        ("Square44x44Logo.targetsize-16.png", 16, 16, True),
        ("Square44x44Logo.targetsize-24.png", 24, 24, True),
        ("Square44x44Logo.targetsize-32.png", 32, 32, True),
        ("Square44x44Logo.targetsize-48.png", 48, 48, True),
        ("Square44x44Logo.targetsize-256.png", 256, 256, True),
        ("Square44x44Logo.altform-unplated_targetsize-16.png", 16, 16, True),
        ("Square44x44Logo.altform-unplated_targetsize-24.png", 24, 24, True),
        ("Square44x44Logo.altform-unplated_targetsize-32.png", 32, 32, True),
        ("Square44x44Logo.altform-unplated_targetsize-48.png", 48, 48, True),
        ("Square44x44Logo.altform-unplated_targetsize-256.png", 256, 256, True),

        # Square 150x150 Logo
        ("Square150x150Logo.png", 150, 150, True),
        ("Square150x150Logo.scale-100.png", 150, 150, True),
        ("Square150x150Logo.scale-125.png", 188, 188, True),
        ("Square150x150Logo.scale-150.png", 225, 225, True),
        ("Square150x150Logo.scale-200.png", 300, 300, True),
        ("Square150x150Logo.scale-400.png", 600, 600, True),

        # Wide 310x150 Logo
        ("Wide310x150Logo.png", 310, 150, True),
        ("Wide310x150Logo.scale-100.png", 310, 150, True),
        ("Wide310x150Logo.scale-125.png", 388, 188, True),
        ("Wide310x150Logo.scale-150.png", 465, 225, True),
        ("Wide310x150Logo.scale-200.png", 620, 300, True),
        ("Wide310x150Logo.scale-400.png", 1240, 600, True),

        # SplashScreen
        ("SplashScreen.png", 620, 300, True),
        ("SplashScreen.scale-100.png", 620, 300, True),
        ("SplashScreen.scale-125.png", 775, 375, True),
        ("SplashScreen.scale-150.png", 930, 450, True),
        ("SplashScreen.scale-200.png", 1240, 600, True),
        ("SplashScreen.scale-400.png", 2480, 1200, True),
    ]

    print(f"Generating {len(specs)} Store assets in {OUTPUT_DIR}...")
    for filename, w, h, center in specs:
        out_file = OUTPUT_DIR / filename
        pad = 0.6 if ("Wide" in filename or "SplashScreen" in filename) else 0.88
        img = make_centered_image(src, w, h, pad_ratio=pad)
        img.save(out_file, format="PNG")
        print(f"  [+] {filename} ({w}x{h})")

    print("All Microsoft Store assets generated successfully!")


if __name__ == "__main__":
    main()
