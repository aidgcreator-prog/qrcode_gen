# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec for QR Code Generator (single-file build).

Build with:  pyinstaller --noconfirm build.spec
Produces one portable executable: dist/QRCodeGenerator.exe

Size strategy: streamlit only imports its data/chart libraries (pandas,
pyarrow, altair, pydeck, ...) lazily when those elements are actually used.
This app only renders text/inputs/images, so those libraries are excluded here
(kept out of the bundle entirely) instead of being pulled in through
collect_all(streamlit).

NOTE: numpy must stay in the bundle: streamlit's image_to_url() (used by
st.logo, st.image and page_icon) does `import numpy` unconditionally, so a
bundle without numpy crashes as soon as the app renders any image.
"""

from PyInstaller.utils.hooks import collect_all

# Packages never imported by the code paths this app uses (verified: none are
# loaded by `import streamlit` or by the server bootstrap).
EXCLUDED_PACKAGES = [
    "pyarrow",
    "pandas",
    "altair",
    "pydeck",
    "IPython",
    "jedi",
    "debugpy",
    "matplotlib",
    "scipy",
    "plotly",
    "sympy",
    "jupyter",
    "jupyter_client",
    "jupyter_core",
    "ipykernel",
    "nbformat",
    "nbconvert",
    "notebook",
]

datas = [("main.py", "."), ("image", "image")]
binaries = []
hiddenimports = ["qrcode", "PIL", "PIL.Image", "PIL.ImageDraw", "qrcode.image.svg"]

# streamlit loads many submodules dynamically and needs its bundled static
# frontend; pystray picks its backend per-platform; watchdog is used by
# streamlit's file watcher. collect_all() gathers submodules + data for each.
for package in ("streamlit", "pystray", "watchdog"):
    pkg_datas, pkg_binaries, pkg_hidden = collect_all(package)
    datas += pkg_datas
    binaries += pkg_binaries
    hiddenimports += pkg_hidden

a = Analysis(
    ["run_app.py"],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=EXCLUDED_PACKAGES,
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="QRCodeGenerator",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    runtime_tmpdir=None,  # extract to the user's temp dir on each launch
    console=False,  # tray app: no console window
    icon="image/logo.ico",
)
