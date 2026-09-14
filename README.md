# QR Code Generator 🔳

A fast, lightweight application that turns any link or text into a QR code. It ships with a system-tray launcher and supports pre-compiled Windows releases (standalone executable & Windows installer), so end users need **no Python installed**.

---

## 📥 Downloads (Windows)

Download pre-built releases directly from the [GitHub Releases](https://github.com/aidgcreator-prog/qrcode_gen/releases) page:

| File | Type | Description |
| :--- | :--- | :--- |
| **`QR-Code-Generator-Setup-<version>.exe`** | **Windows Installer** *(Recommended)* | Installs the app per-user into `%LOCALAPPDATA%\Programs\QR Code Generator`, creates Start Menu & Desktop shortcuts, enables auto-start at login, and includes an uninstaller in Windows Settings. |
| **`QRCodeGenerator.exe`** | **Portable Standalone** | Zero installation required. Simply double-click to run immediately. Ideal for USB drives or restricted school/work computers. |

---

## Features

- Encode any URL or text (starts with clean blank input)
- Live PNG preview with input-length stats
- Options: error correction (L/M/Q/H), box size, quiet-zone border, foreground and background colors
- Download as **PNG**, **JPEG**, or **SVG**
- **Save to outputs/** folder automatically or with a single click
- Custom output file naming with full international/Khmer support
- Direct **Tutorials & Support** links to [YouTube](https://www.youtube.com/@LocalAiLabKh) and [Facebook](https://www.facebook.com/profile.php?id=61591432885068)
- System tray app: runs in the background. Tray menu: *Open in browser*, *Copy app URL*, *About*, *YouTube Tutorials*, *Facebook Page*, *Start with Windows*, *Update check*, and *Quit*

## Project layout

| Path | Purpose |
| --- | --- |
| `main.py` | The Streamlit app itself (QR generation + UI) |
| `run_app.py` | Tray launcher: runs the server headless in the background |
| `run.bat` | One-click script to launch the app locally on Windows |
| `image/` | Logo assets (`logo_round.png`, `logo.ico`, …) |
| `outputs/` | Local directory where generated QR codes are saved |

## Development setup

The project is managed with [uv](https://docs.astral.sh/uv/).

```bash
uv sync                 # install dependencies into .venv
uv run streamlit run main.py      # plain Streamlit dev server
uv run python run_app.py          # tray-launcher version (desktop session)
```

You can also double-click **`run.bat`** on Windows to automatically start the app.

Set `QR_NO_TRAY=1` to run the launcher attached to the console with logs
instead of the tray icon.

From the tray menu you can tick **Start with Windows** to launch the app at
login (registered in `HKCU\...\CurrentVersion\Run`). Auto-started instances
skip the browser popup — open the app from the tray instead. **Copy app URL**
puts the local app address on the clipboard (handy for phones). **About**
shows the running version and, once `GITHUB_REPO` is set, links to the
repository page.

### Update check (GitHub Releases)

`run_app.py` checks `https://api.github.com/repos/aidgcreator-prog/qrcode_gen/releases/latest`
on startup and shows the result as a tray menu item: it becomes
*“⬇ Update available: vX.Y.Z — open release”* when a newer release exists
(click to open the download page), and clicking it while up to date re-checks.

The constant at the top of `run_app.py` is configured as:
`GITHUB_REPO = "aidgcreator-prog/qrcode_gen"`. Keep `APP_VERSION` updated
when preparing a new release. Version comparison is semver-aware (`packaging`).

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

## Running the Desktop Tray Launcher

`run_app.py` picks the first free port, starts the Streamlit server headless on
`127.0.0.1`, and shows a tray icon. When running, stdout/stderr logs are kept
in `%TEMP%\qrcode-generator.log` for diagnostics.

- **Test environment overrides**:
  - `QR_NO_TRAY=1`: Run with console logs instead of system tray icon.
  - `QR_NO_BROWSER=1`: Do not open the browser window automatically on startup.
  - `QR_PORT=8501`: Specify a fixed local port.
  - `QR_SELFTEST=1`: Run the internal validation flow via Streamlit AppTest for PNG, JPEG, and SVG generation.
- **Command-line flag**:
  - `--autostart`: Used by the *Start with Windows* option (suppresses browser popup).

## Environment notes

- Python `>=3.13` (see `.python-version`)
- Runtime dependencies: `streamlit`, `qrcode[pil]`, `Pillow`, `pystray`
- Managed with [uv](https://docs.astral.sh/uv/)

---

<a id="privacy"></a>
## 🔒 Privacy Policy

**QRCodeGen** is designed as a 100% offline, privacy-first desktop utility:

1. **Zero Data Collection**: No personal data, usage telemetry, or device identifiers are collected or tracked.
2. **Local Processing**: All QR code generation (PNG, JPEG, SVG) runs entirely on your local machine.
3. **No Network Transmission**: User input and generated codes are never transmitted to external servers.
4. **Local File Storage**: Output files are saved only to your local disk (e.g. `outputs/` or `Pictures/QR Codes`).

For full details, please see our formal [Privacy Policy](PRIVACY.md).

