# QR Code Generator — Build & Installer Guidelines

This guide provides step-by-step instructions and technical rules for building the portable executable and the Windows installer for **QR Code Generator**.

---

## 1. Overview of the Build Pipeline

The application build pipeline consists of two stages:

```
[Source Code]
 main.py (Streamlit UI)
 run_app.py (Tray launcher)
 image/ (Icons & assets)
      │
      ▼  (Stage 1: PyInstaller)
 dist/QRCodeGenerator.exe (Portable single-file bundle)
      │
      ▼  (Stage 2: Inno Setup 6)
 installer/Output/QR-Code-Generator-Setup-<version>.exe (Windows installer)
```

1. **Stage 1 — Executable Compilation (`PyInstaller`)**:
   Uses `build.spec` to package Python runtime, Streamlit server, dependencies (`qrcode`, `Pillow`, `pystray`), assets, and `run_app.py` into a single standalone `.exe` (`dist\QRCodeGenerator.exe`).
2. **Stage 2 — Installer Creation (`Inno Setup 6`)**:
   Uses `installer.iss` to package `dist\QRCodeGenerator.exe` into a standard Windows setup wizard (`installer\Output\QR-Code-Generator-Setup-<version>.exe`) with Start Menu shortcuts, desktop icon option, clean uninstaller, and autostart support.

---

## 2. Environment Prerequisites

- **Python Environment**: Managed via [uv](https://docs.astral.sh/uv/) (`>=3.13`).
- **PyInstaller**: Installed in dev dependencies (`uv run pyinstaller`).
- **Inno Setup 6**: Installed on Windows at:
  ```
  C:\Program Files (x86)\Inno Setup 6\ISCC.exe
  ```

---

## 3. Version Bumping Workflow

Before building a new release, make sure the versions match in both configuration files:

1. **`run_app.py`**:
   ```python
   APP_VERSION = "0.5.1"  # Set to the target version
   ```
2. **`installer.iss`**:
   ```pascal
   #define MyAppVersion "0.5.1"  ; Set to match APP_VERSION
   ```

*(Optional)* Before public distribution, configure your GitHub repository in `run_app.py`:
```python
GITHUB_REPO = "owner/repo"  # Enables automatic tray update checks
```

---

## 4. Build Instructions

Run all commands in PowerShell from the project root (`e:\qrcode_gen`):

### Step 1: Pre-build Validation & Tests (Recommended)
Run the built-in self-test to verify that Streamlit, QRCode, and Pillow pipelines render PNG, JPEG, and SVG without issues:

```powershell
$env:QR_SELFTEST='1'; uv run python run_app.py
```
Ensure it outputs `SELFTEST OK`.

### Step 2: Build the Standalone Executable
```powershell
uv run pyinstaller --noconfirm build.spec
```
- **Output**: `dist\QRCodeGenerator.exe` (~45 MB).
- Runs headless in system tray by default without a terminal window (`console=False`).

### Step 3: Build the Windows Installer
```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```
- **Output**: `installer\Output\QR-Code-Generator-Setup-<version>.exe` (~47 MB).

### Combined One-Line Build Command (or Double-Click `build.bat`)
```powershell
.\build.bat
```
Or manually:
```powershell
uv run pyinstaller --noconfirm build.spec; if ($?) { & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss }
```

---

## 5. Architectural Rules & Gotchas

1. **Frozen Mode Path Resolution**:
   - In development, `outputs/` is located at the project root `APP_DIR / "outputs"`.
   - When frozen as an `.exe`, `Path(__file__).parent` points to a temporary folder (`%TEMP%\_MEIxxxx`).
   - For file outputs, always resolve paths relative to `Path(sys.executable).parent` when `getattr(sys, "frozen", False)` is `True`.
   - Application assets (`image/logo_round.png`) remain loaded from `_MEIPASS` via `Path(__file__).parent / "image"`.

2. **Streamlit AppTest Ordering**:
   - `run_app.py`'s self-test expects `at.selectbox[0]` in the main container to be the format picker (`Download format`).
   - Do not add new `st.selectbox` widgets in the main page above `Download format`. Use `st.text_input`, `st.radio`, or sidebar controls instead.

3. **Size Optimization in `build.spec`**:
   - Heavy data libraries (`pandas`, `pyarrow`, `altair`, `pydeck`, `matplotlib`, `scipy`) are excluded in `EXCLUDED_PACKAGES`.
   - `numpy` **must remain bundled**: Streamlit's image processing functions (`st.logo`, `st.image`, `page_icon`) import `numpy` unconditionally.

4. **Git Hygiene**:
   - Never commit `build/`, `dist/`, or `installer/Output/`.
   - User outputs in `outputs/` are ignored by `.gitignore`, but `outputs/.gitkeep` preserves the folder structure.
