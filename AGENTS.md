# QR Code Generator — Development & Architectural Guidelines

This guide provides technical rules, testing procedures, and architectural constraints for developing **QR Code Generator**.

---

## 1. Application Overview

- **`main.py`**: Streamlit application UI for customizable QR code generation (PNG, JPEG, SVG) and saving to `outputs/`.
- **`run_app.py`**: Windows system-tray launcher that starts the Streamlit server headless in the background.
- **`run.bat`**: One-click local launcher for Windows.
- **`image/`**: Application icons and branding assets (`logo_round.png`, `logo.ico`, `logo.jpg`).
- **`outputs/`**: User directory where generated QR codes are exported and saved.

---

## 2. Environment Prerequisites

- **Python Environment**: Managed via [uv](https://docs.astral.sh/uv/) (`>=3.13`).
- **Runtime Dependencies**:
  - `streamlit>=1.63.0`
  - `qrcode[pil]>=8.2`
  - `pystray>=0.19.5`
  - `Pillow`

---

## 3. Development & Testing Workflow

Run all commands from the project root (`e:\qrcode_gen`):

### Running the App
```powershell
# Run plain Streamlit development server
uv run streamlit run main.py

# Run tray launcher in desktop session
uv run python run_app.py

# Run one-click Windows launcher
.\run.bat
```

### Validation & Self-Tests
Run the built-in self-test to verify that Streamlit, QRCode, and Pillow render PNG, JPEG, and SVG without issues:

```powershell
$env:QR_SELFTEST='1'; uv run python run_app.py
```
Ensure it outputs `SELFTEST OK`.

Run the UI test suite:
```powershell
uv run python -c "from streamlit.testing.v1 import AppTest; at = AppTest.from_file('main.py'); at.run(); assert not at.exception; print('AppTest passed successfully!')"
```

---

## 4. Architectural Rules & Gotchas

1. **Path Resolution**:
   - In development and local execution, user files are saved to `outputs/` located at the project root (`APP_DIR / "outputs"`).
   - Application assets (`image/logo_round.png`) remain loaded relative to `APP_DIR / "image"`.

2. **Streamlit AppTest Ordering**:
   - `run_app.py`'s self-test expects `at.selectbox[0]` in the main container to be the format picker (`Download format`).
   - Do not add new `st.selectbox` widgets in the main page above `Download format`. Use `st.text_input`, `st.radio`, or sidebar controls instead.

3. **Git Hygiene**:
   - Build scripts, installer specifications, output directories (`build/`, `dist/`, `installer/`, `*.exe`, `*.msi`, `*.spec`, `*.iss`), and scratch files are ignored by `.gitignore`.
   - User outputs in `outputs/` are ignored by `.gitignore`, but `outputs/.gitkeep` preserves the folder structure.
