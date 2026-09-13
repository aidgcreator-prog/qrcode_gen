import io
from pathlib import Path
import sys

import qrcode
import streamlit as st
from PIL import Image as PILImage
from qrcode.constants import ERROR_CORRECT_H, ERROR_CORRECT_L, ERROR_CORRECT_M, ERROR_CORRECT_Q
from qrcode.image.svg import SvgPathImage

APP_DIR = Path(__file__).resolve().parent
LOGO_PATH = APP_DIR / "image" / "logo_round.png"
# In dev mode, save to project root outputs/; when frozen as an exe, save next to the executable
BASE_DIR = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else APP_DIR


def _get_outputs_dir() -> Path:
    """Resolve a writable directory for saving generated QR codes.

    Prefers `outputs/` next to the executable (or in dev root). If that path
    is not writable (e.g. installed under Program Files or WindowsApps MSIX container),
    falls back gracefully to ~/Pictures/QR Codes.
    """
    candidate = BASE_DIR / "outputs"
    try:
        candidate.mkdir(parents=True, exist_ok=True)
        test_file = candidate / ".write_test"
        test_file.touch()
        test_file.unlink(missing_ok=True)
        return candidate
    except (PermissionError, OSError):
        fallback = Path.home() / "Pictures" / "QR Codes"
        fallback.mkdir(parents=True, exist_ok=True)
        return fallback


OUTPUTS_DIR = _get_outputs_dir()


def sanitize_filename(name: str, default: str = "qrcode") -> str:
    """Sanitize a filename by removing characters not allowed by filesystem."""
    cleaned = "".join(c for c in name if c not in r'\/:*?"<>|').strip()
    return cleaned or default


def save_to_outputs(data: bytes, filename: str) -> Path:
    """Save raw QR code bytes into the outputs directory."""
    OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)
    target_path = OUTPUTS_DIR / filename
    target_path.write_bytes(data)
    return target_path


ERROR_CORRECTION_OPTIONS = {
    "L (≈7%)": ERROR_CORRECT_L,
    "M (≈15%)": ERROR_CORRECT_M,
    "Q (≈25%)": ERROR_CORRECT_Q,
    "H (≈30%)": ERROR_CORRECT_H,
}

DOWNLOAD_FORMATS = {
    "PNG": {"ext": "png", "mime": "image/png"},
    "JPEG": {"ext": "jpg", "mime": "image/jpeg"},
    "SVG": {"ext": "svg", "mime": "image/svg+xml"},
}

st.set_page_config(page_title="QR Code Generator", page_icon=str(LOGO_PATH), layout="centered")

if LOGO_PATH.exists() and hasattr(st, "logo"):
    st.logo(str(LOGO_PATH))

# --- Top Bar: Tutorials & Support ---
top_bar, col_yt, col_fb = st.columns([2.6, 1.2, 1.2], vertical_alignment="center")
with top_bar:
    st.markdown("📚 **Tutorials & Support**")
with col_yt:
    st.link_button("▶️ YouTube", "https://www.youtube.com/@LocalAiLabKh", help="Video tutorials on YouTube", width="stretch")
with col_fb:
    st.link_button("🌐 Facebook", "https://www.facebook.com/profile.php?id=61591432885068", help="Community & updates on Facebook", width="stretch")

st.divider()

st.title("🔳 QR Code Generator")
st.caption("Generate a QR code for any link or text, right in your browser.")


def build_qr(data: str, error_correction, box_size: int, border: int):
    """Build a qrcode.QRCode for `data` with automatic size."""
    qr = qrcode.QRCode(
        version=None,  # automatic size
        error_correction=error_correction,
        box_size=box_size,
        border=border,
    )
    qr.add_data(data)
    qr.make(fit=True)
    return qr


def styled_svg_factory(fill_color: str, back_color: str):
    """Return a SvgPathImage subclass tinted with the chosen colors."""

    class StyledSvgPathImage(SvgPathImage):
        QR_PATH_STYLE = {**SvgPathImage.QR_PATH_STYLE, "fill": fill_color}
        background = back_color

    return StyledSvgPathImage


def render_raster_bytes(qr, fmt: str, fill_color: str, back_color: str) -> bytes:
    """Render the QR code as PNG or JPEG bytes."""
    img = qr.make_image(fill_color=fill_color, back_color=back_color)
    if fmt == "JPEG":
        # JPEG has no alpha channel: flatten transparency onto white.
        if img.mode in ("RGBA", "LA"):
            img = img.convert("RGBA")
            flat = PILImage.new("RGB", img.size, (255, 255, 255))
            flat.paste(img.convert("RGB"), mask=img.getchannel("A"))
            img = flat
        else:
            img = img.convert("RGB")
    buffer = io.BytesIO()
    img.save(buffer, format=fmt)
    return buffer.getvalue()


def render_svg_bytes(qr, fill_color: str, back_color: str) -> bytes:
    """Render the QR code as SVG bytes (scales losslessly)."""
    img = qr.make_image(image_factory=styled_svg_factory(fill_color, back_color))
    buffer = io.BytesIO()
    img.save(buffer)
    return buffer.getvalue()


def generate_qr_bytes(
    data: str,
    fmt: str = "PNG",
    error_correction=ERROR_CORRECT_M,
    box_size: int = 10,
    border: int = 4,
    fill_color: str = "black",
    back_color: str = "white",
) -> bytes:
    """Generate a QR code for `data` and return the image as bytes in `fmt`."""
    qr = build_qr(data, error_correction=error_correction, box_size=box_size, border=border)
    if fmt == "SVG":
        return render_svg_bytes(qr, fill_color=fill_color, back_color=back_color)
    return render_raster_bytes(qr, fmt=fmt, fill_color=fill_color, back_color=back_color)


with st.sidebar:
    st.header("⚙️ Options")

    error_correction_label = st.selectbox(
        "Error correction",
        options=list(ERROR_CORRECTION_OPTIONS),
        index=1,
        help="How much damage the QR code can survive and still be scanned. Higher = more robust but denser.",
    )
    box_size = st.slider(
        "Box size (px per module)",
        min_value=1,
        max_value=30,
        value=10,
        help="Size of each square in pixels. Only affects PNG/JPEG output; SVG is vector and scales freely.",
    )
    border = st.slider(
        "Border (modules of quiet zone)",
        min_value=0,
        max_value=10,
        value=4,
        help="Whitespace around the QR code. 4 is the minimum recommended by the spec.",
    )
    fill_color = st.color_picker("Foreground color", value="#000000")
    back_color = st.color_picker("Background color", value="#FFFFFF")
    st.divider()
    auto_save = st.checkbox(
        "Auto-save to outputs/",
        value=True,
        help="Automatically save generated QR code images into the outputs/ directory.",
    )

    st.divider()
    st.markdown("### 📚 Tutorials & Support")
    st.markdown("▶️ [YouTube (@LocalAiLabKh)](https://www.youtube.com/@LocalAiLabKh)")
    st.markdown("🌐 [Facebook Page](https://www.facebook.com/profile.php?id=61591432885068)")

data = st.text_area(
    "Link or text to encode",
    value="",
    height=90,
    placeholder="https://example.com or any text…",
)

st.write("")
generate = st.button("Generate QR code", type="primary", width="stretch")

if generate or data:
    content = data.strip()
    if not content:
        st.info("Enter a link or some text above to see your QR code.")
    else:
        try:
            qr = build_qr(
                content,
                error_correction=ERROR_CORRECTION_OPTIONS[error_correction_label],
                box_size=box_size,
                border=border,
            )
            preview_png = render_raster_bytes(qr, "PNG", fill_color=fill_color, back_color=back_color)
        except Exception as exc:  # e.g. text too long for the chosen settings
            st.error(f"Could not generate the QR code: {exc}")
            st.stop()

        col1, col2 = st.columns([2, 1])
        with col1:
            st.image(preview_png, caption=f"QR code for: {content[:60]}", width="content")
        with col2:
            st.markdown("##### Details")
            st.write(f"- **Input length:** {len(content)} chars")
            st.write(f"- **Error correction:** {error_correction_label.split(' ')[0]}")
            st.write(f"- **Box size:** {box_size} px")
            st.write(f"- **Border:** {border} modules")

        fmt_label = st.selectbox(
            "Download format",
            options=list(DOWNLOAD_FORMATS),
            help=(
                "PNG/JPEG are pixel images. JPEG is smaller but has no transparency. "
                "SVG is a vector image that scales to any size without losing quality."
            ),
        )
        fmt = DOWNLOAD_FORMATS[fmt_label]

        filename_input = st.text_input(
            "File name",
            value="qrcode",
            help="File name (without extension) for saving to outputs/ or downloading.",
        )
        target_filename = f"{sanitize_filename(filename_input)}.{fmt['ext']}"

        try:
            if fmt_label == "SVG":
                download_bytes = render_svg_bytes(qr, fill_color=fill_color, back_color=back_color)
            elif fmt_label == "PNG":
                download_bytes = preview_png
            else:
                download_bytes = render_raster_bytes(qr, "JPEG", fill_color=fill_color, back_color=back_color)
        except Exception as exc:
            st.error(f"Could not render the {fmt_label} file: {exc}")
            st.stop()

        col_dl, col_save = st.columns(2)
        with col_dl:
            st.download_button(
                f"⬇️ Download {fmt_label}",
                data=download_bytes,
                file_name=target_filename,
                mime=fmt["mime"],
                type="primary",
                width="stretch",
            )
        with col_save:
            save_clicked = st.button("💾 Save to outputs/", width="stretch")

        if save_clicked:
            saved_path = save_to_outputs(download_bytes, target_filename)
            st.success(f"Saved to `outputs/{saved_path.name}`")
        elif auto_save:
            saved_path = save_to_outputs(download_bytes, target_filename)
            st.caption(f"📁 Auto-saved to `outputs/{saved_path.name}`")

