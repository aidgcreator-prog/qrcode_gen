# QR Code Generator 🔳

A small Streamlit app that turns any link or text into a QR code. It ships with a
system-tray launcher and a self-contained Windows installer (built with
PyInstaller + Inno Setup), so end users need **no Python installed**.

## Features

- Encode any URL or text
- Live PNG preview with input-length stats
- Options: error correction (L/M/Q/H), box size, quiet-zone border, foreground and background colors
- Download as **PNG**, **JPEG**, or **SVG**
- System tray app: runs in the background. Tray menu: *Open in browser*,
  *Copy app URL*, *About* (version + repo link), *Start with Windows*, an
  optional *update check*, and *Quit*

## Project layout

| Path | Purpose |
| --- | --- |
| `main.py` | The Streamlit app itself (QR generation + UI) |
| `run_app.py` | Tray launcher: runs the server headless in the background |
| `build.spec` | PyInstaller spec for the self-contained single-file exe |
| `installer.iss` | Inno Setup script that wraps the exe into a Windows installer |
| `image/` | Logo assets (`logo_round.png`, `logo.ico`, …) |

## Development setup

The project is managed with [uv](https://docs.astral.sh/uv/).

```bash
uv sync                 # install dependencies into .venv
uv run streamlit run main.py      # plain Streamlit dev server
uv run python run_app.py          # tray-launcher version (desktop session)
```

Set `QR_NO_TRAY=1` to run the launcher attached to the console with logs
instead of the tray icon.

From the tray menu you can tick **Start with Windows** to launch the app at
login (registered in `HKCU\...\CurrentVersion\Run`). Auto-started instances
skip the browser popup — open the app from the tray instead. **Copy app URL**
puts the local app address on the clipboard (handy for phones). **About**
shows the running version and, once `GITHUB_REPO` is set, links to the
repository page.

### Update check (GitHub Releases)

`run_app.py` checks `https://api.github.com/repos/{owner}/{repo}/releases/latest`
on startup and shows the result as a tray menu item: it becomes
*“⬇ Update available: vX.Y.Z — open release”* when a newer release exists
(click to open the download page), and clicking it while up to date re-checks.

The check is **disabled until you publish**: set `GITHUB_REPO = "owner/repo"`
(the constant at the top of `run_app.py`) to your GitHub repository and keep
`APP_VERSION` in sync with the installer version before rebuilding. Version
comparison is semver-aware (`packaging`).

Run the UI test suite:

```bash
uv run python - <<'EOF'
from streamlit.testing.v1 import AppTest
at = AppTest.from_file("main.py")
at.run()
assert not at.exception
print("OK")
EOF
```

## Packaging (Windows)

### 1. Build the self-contained exe

```bash
uv add --dev pyinstaller   # once
uv run pyinstaller --noconfirm build.spec
```

Produces **one portable file: `dist\QRCodeGenerator.exe`** (console-free,
~33 MB). It contains the Streamlit server, the app script, its assets, and a
full Python runtime, and extracts itself to a temp folder on launch (first
start can take a few extra seconds). Nothing else needs to be installed on the
target machine — share the exe on its own if you like.

Streamlit only imports its data/chart libraries lazily, so `build.spec`
excludes `pandas`, `pyarrow`, `altair`, `pydeck`, `IPython`, `jedi`, `debugpy`,
and friends. `numpy` is deliberately kept: streamlit's image pipeline
(`st.logo`, `st.image`, `page_icon`) imports it unconditionally.

> `run_app.py` picks the first free port, starts the server headless on
> `127.0.0.1`, and shows a tray icon. When run windowed, stdout/stderr are kept
> in `%TEMP%\qrcode-generator.log` for diagnostics.
>
> Test environment overrides: `QR_NO_TRAY=1`, `QR_NO_BROWSER=1`, `QR_PORT=8501`,
> `QR_SELFTEST=1` (runs the in-bundle QR-generation flow via Streamlit's
> AppTest — executes the real script for PNG/JPEG/SVG and validates the bundled
> qrcode + Pillow output — writes `qrcode-selftest.txt` to the temp folder and
> exits 0 on success).
> Command-line flag: `--autostart` (used by the *Start with Windows* tray
> option; suppresses the browser popup).

### 2. Build the Windows installer

Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```bash
"/c/Program Files (x86)/Inno Setup 6/ISCC.exe" installer.iss
```

Produces `installer\Output\QR-Code-Generator-Setup-0.5.1.exe` (~45 MB). The
installer installs per-user into `%LOCALAPPDATA%\Programs\QR Code Generator`,
adds Start menu (and optional desktop) shortcuts, and offers to launch the app
afterwards.

## Environment notes

- Python `>=3.13` (see `.python-version`)
- Runtime dependencies: `streamlit`, `qrcode[pil]`, `Pillow`, `pystray`
- `pystray` + `pyinstaller` are only needed for packaging the tray build
