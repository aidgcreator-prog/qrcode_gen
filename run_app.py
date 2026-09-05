"""QR Code Generator — packaged entry point.

Runs the Streamlit server in the background and lives in the system tray
(Open in browser / Quit). Also works from a terminal during development:

    python run_app.py              # tray icon (dev: needs a desktop session)
    QR_NO_TRAY=1 python run_app.py # console mode with logs, like app_launcher.py

Environment overrides (mainly for automated testing):
    QR_NO_TRAY=1     keep running attached to the console instead of using the tray
    QR_NO_BROWSER=1  do not auto-open the browser
    QR_PORT=8501     force the server port (default: first free port >= 8501)
    QR_SELFTEST=1    run the in-bundle QR generation self-test, then exit

Command-line flag:
    --autostart  launched at Windows login: no browser popup, tray only
"""

import multiprocessing
import os
import socket
import sys
import tempfile
import threading
import time
import webbrowser
from pathlib import Path

try:
    import winreg
except ImportError:  # non-Windows dev environments
    winreg = None

AUTOSTART_FLAG = "--autostart"
_AUTOSTART_RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
_AUTOSTART_VALUE = "QRCodeGenerator"

# Local app version — keep in sync with MyAppVersion in installer.iss.
APP_VERSION = "0.5.1"

GITHUB_REPO = "aidgcreator-prog/qrcode_gen"

# State shared between the background update check and the tray menu label.
_UPDATE_STATE = {"checking": False, "latest": None, "url": None, "manual": False}


def is_frozen() -> bool:
    return getattr(sys, "frozen", False)


def resource_path(rel: str) -> Path:
    """Path to a bundled file — PyInstaller _MEIPASS when frozen, project dir otherwise."""
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return base / rel


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def server_command() -> tuple[list[str], int]:
    """Build the `streamlit run` argv and pick the port to serve on."""
    port = int(os.environ.get("QR_PORT") or _free_port())
    cmd = [
        "streamlit",
        "run",
        str(resource_path("main.py")),
        "--server.headless=true",
        "--server.address=127.0.0.1",
        "--server.port=%d" % port,
        "--server.fileWatcherType=none",
        "--browser.gatherUsageStats=false",
        "--global.developmentMode=false",
    ]
    return cmd, port


def _run_streamlit(cmd: list[str]) -> None:
    """Blocking server run (main thread when running from a console)."""
    from streamlit.web import cli as stcli

    previous = sys.argv
    sys.argv = cmd
    try:
        stcli.main()
    finally:
        sys.argv = previous


def _autostart_command() -> str:
    """Command Windows runs at login — the app exe, or pythonw + this script in dev."""
    if is_frozen():
        exe = sys.executable
    else:
        exe = sys.executable
        pythonw = Path(exe).with_name("pythonw.exe")
        if pythonw.exists():
            exe = str(pythonw)
    return f'"{exe}" {AUTOSTART_FLAG}'


def is_autostart_enabled() -> bool:
    """True when this app is registered to start with Windows."""
    if winreg is None:
        return False
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, _AUTOSTART_RUN_KEY) as key:
            value, _ = winreg.QueryValueEx(key, _AUTOSTART_VALUE)
        return value == _autostart_command()
    except OSError:
        return False


def set_autostart(enabled: bool) -> None:
    """Register/unregister the app in the per-user Run key (HKCU)."""
    if winreg is None:
        return
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, _AUTOSTART_RUN_KEY) as key:
        if enabled:
            winreg.SetValueEx(key, _AUTOSTART_VALUE, 0, winreg.REG_SZ, _autostart_command())
        else:
            try:
                winreg.DeleteValue(key, _AUTOSTART_VALUE)
            except OSError:
                pass


def _disable_signal_handler() -> None:
    """Streamlit installs a SIGTERM handler which only works in the main thread.

    When the server runs in a background thread (tray mode) that call would
    raise, so replace it with a no-op. Process exit still stops the server.
    """
    from streamlit.web import bootstrap

    bootstrap._set_up_signal_handler = lambda server: None


def _redirect_output() -> None:
    """Windowed (tray) builds have no console: keep stdout/stderr in a log file."""
    if not is_frozen() or os.environ.get("QR_NO_TRAY") == "1":
        return
    log_path = Path(tempfile.gettempdir()) / "qrcode-generator.log"
    log_file = open(log_path, "a", encoding="utf-8", buffering=1)
    sys.stdout = log_file
    sys.stderr = log_file


def _tray_image():
    from PIL import Image

    logo_path = resource_path("image") / "logo_round.png"
    if logo_path.exists():
        return Image.open(logo_path).convert("RGBA").resize((64, 64))
    # Fallback: simple dark square so the tray icon is never blank.
    return Image.new("RGBA", (64, 64), (33, 33, 33, 255))


def _open_in_browser(url: str) -> None:
    webbrowser.open(url)


def _selftest() -> int:
    """Run the QR-generation flow against the bundled app, then exit.

    Uses Streamlit's in-process AppTest on the bundled main.py: executes the
    real    script, renders the preview, and produces PNG/JPEG/SVG download bytes
    with the bundled qrcode + Pillow. Writes a report to
    qrcode-selftest.txt in the user temp folder and returns 0 on success,
    1 on failure.
    """
    import io
    from PIL import Image

    report_path = Path(tempfile.gettempdir()) / "qrcode-selftest.txt"
    lines: list[str] = []

    def log(msg: str) -> None:
        lines.append(msg)
        print(msg, file=sys.stderr if is_frozen() else sys.stdout)

    def verify_bytes(fmt: str, data: bytes) -> None:
        """Check magic bytes + (for raster) PIL-decodes to a valid image."""
        expected = {
            "PNG": b"\x89PNG\r\n\x1a\n",
            "JPEG": b"\xff\xd8\xff",
            "SVG": b"<?xml",
        }
        if not data.startswith(expected[fmt]):
            raise RuntimeError(f"{fmt}: bad magic {data[:8]!r}")
        if fmt in ("PNG", "JPEG"):
            image = Image.open(io.BytesIO(data))
            image.verify()
            log(f"{fmt}: {len(data)} bytes, valid {fmt}")
        else:
            if b"<svg" not in data:
                raise RuntimeError("SVG: missing <svg> element")
            log(f"{fmt}: {len(data)} bytes, valid SVG")

    try:
        from streamlit.testing.v1 import AppTest

        # 1) Run the real bundled script through Streamlit's runtime and switch
        #    the app through every download format. Any QR-generation failure
        #    inside main.py surfaces here as a script exception.
        at = AppTest.from_file(str(resource_path("main.py")), default_timeout=60)
        at.run()
        if at.exception:
            raise RuntimeError(f"app exception: {at.exception}")
        if at.get("text_area") and not at.get("text_area")[0].value:
            at.get("text_area")[0].set_value("https://example.com").run()
        content = at.get("text_area")[0].value if at.get("text_area") else "https://example.com"

        for fmt in ("PNG", "JPEG", "SVG"):
            at.selectbox[0].set_value(fmt).run()
            if at.exception:
                raise RuntimeError(f"{fmt} run exception: {at.exception}")
            button = at.get("download_button")[0]
            if not button.proto.url:
                raise RuntimeError(f"{fmt}: download not wired to media manager")
            log(f"{fmt}: script executed, download URL set ({content!r})")

        # 2) Byte-level check of the bundled qrcode + Pillow pipeline (same libs
        #    main.py uses) producing each format from the app's own input.
        import qrcode
        from qrcode.constants import ERROR_CORRECT_M
        from qrcode.image.svg import SvgPathImage

        qr = qrcode.QRCode(error_correction=ERROR_CORRECT_M, box_size=10, border=4)
        qr.add_data(content)
        qr.make(fit=True)

        raster = qr.make_image(fill_color="#000000", back_color="#FFFFFF")
        png_buf, jpeg_buf = io.BytesIO(), io.BytesIO()
        raster.save(png_buf, format="PNG")
        verify_bytes("PNG", png_buf.getvalue())
        raster.convert("RGB").save(jpeg_buf, format="JPEG")
        verify_bytes("JPEG", jpeg_buf.getvalue())

        svg_buf = io.BytesIO()
        qr.make_image(image_factory=SvgPathImage).save(svg_buf)
        verify_bytes("SVG", svg_buf.getvalue())

        log("SELFTEST OK")
    except Exception as exc:
        report = "\n".join(lines) + f"\nSELFTEST FAILED: {exc}"
        report_path.write_text(report, encoding="utf-8")
        return 1

    report_path.write_text("\n".join(lines), encoding="utf-8")
    return 0


def _copy_to_clipboard(text: str) -> bool:
    """Put `text` on the Windows clipboard (UTF-16). Returns False on failure."""
    if sys.platform != "win32":
        return False
    import ctypes
    from ctypes import wintypes

    CF_UNICODETEXT = 13
    GMEM_MOVEABLE = 0x0002

    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    # Explicit signatures prevent 64-bit handles from being truncated to 32-bit.
    user32.OpenClipboard.argtypes = [wintypes.HWND]
    user32.OpenClipboard.restype = wintypes.BOOL
    user32.EmptyClipboard.argtypes = []
    user32.EmptyClipboard.restype = wintypes.BOOL
    user32.SetClipboardData.argtypes = [wintypes.UINT, wintypes.HANDLE]
    user32.SetClipboardData.restype = wintypes.HANDLE
    user32.CloseClipboard.argtypes = []
    user32.CloseClipboard.restype = wintypes.BOOL
    kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
    kernel32.GlobalAlloc.restype = wintypes.HGLOBAL
    kernel32.GlobalLock.argtypes = [wintypes.HGLOBAL]
    kernel32.GlobalLock.restype = wintypes.LPVOID
    kernel32.GlobalUnlock.argtypes = [wintypes.HGLOBAL]
    kernel32.GlobalUnlock.restype = wintypes.BOOL
    kernel32.GlobalFree.argtypes = [wintypes.HGLOBAL]
    kernel32.GlobalFree.restype = wintypes.HGLOBAL

    if not user32.OpenClipboard(None):
        return False
    try:
        user32.EmptyClipboard()
        payload = text.encode("utf-16-le") + b"\x00\x00"
        handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(payload))
        if not handle:
            return False
        locked = kernel32.GlobalLock(handle)
        if not locked:
            kernel32.GlobalFree(handle)
            return False
        ctypes.memmove(locked, payload, len(payload))
        kernel32.GlobalUnlock(handle)
        if not user32.SetClipboardData(CF_UNICODETEXT, handle):
            kernel32.GlobalFree(handle)
            return False
        return True
    finally:
        user32.CloseClipboard()


def update_check_enabled() -> bool:
    """True once GITHUB_REPO points at a real repo (not the placeholder)."""
    return bool(GITHUB_REPO) and not GITHUB_REPO.startswith("owner/")


def _github_latest_release(repo: str) -> tuple[str, str]:
    """Fetch (tag_name, html_url) of the newest release; raises on any failure."""
    import json
    import urllib.request

    url = f"https://api.github.com/repos/{repo}/releases/latest"
    request = urllib.request.Request(
        url,
        headers={"Accept": "application/vnd.github+json", "User-Agent": "QRCodeGenerator/updater"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        data = json.load(response)
    return data.get("tag_name", "") or "", data.get("html_url", "") or ""


def _is_newer_version(tag: str) -> bool:
    """True when the release tag is newer than the running APP_VERSION."""
    from packaging.version import InvalidVersion, Version

    try:
        return Version(tag.lstrip("vV")) > Version(APP_VERSION)
    except InvalidVersion:
        return False


def run_update_check() -> None:
    """Background check: fills _UPDATE_STATE (never raises)."""
    state = _UPDATE_STATE
    state["checking"] = True
    try:
        if not update_check_enabled():
            return
        tag, url = _github_latest_release(GITHUB_REPO)
        state["latest"] = tag.lstrip("vV") if tag and _is_newer_version(tag) else None
        state["url"] = url if state["latest"] else None
        state["manual"] = True
    except Exception:
        state["latest"] = None
        state["url"] = None
    finally:
        state["checking"] = False


def _build_tray(url: str):
    import pystray

    def on_open(icon, item):
        _open_in_browser(url)

    def on_copy_url(icon, item):
        _copy_to_clipboard(url)

    def on_open_repo(icon, item):
        _open_in_browser(f"https://github.com/{GITHUB_REPO}")

    def on_open_youtube(icon, item):
        _open_in_browser("https://www.youtube.com/@LocalAiLabKh")

    def on_open_facebook(icon, item):
        _open_in_browser("https://www.facebook.com/profile.php?id=61591432885068")

    repo_configured = update_check_enabled()
    about_menu = pystray.Menu(
        pystray.MenuItem(f"QR Code Generator v{APP_VERSION}", None),
        pystray.MenuItem(
            f"GitHub: {GITHUB_REPO}" if repo_configured else "GitHub: not configured",
            on_open_repo if repo_configured else None,
        ),
        pystray.MenuItem("YouTube Tutorials", on_open_youtube),
        pystray.MenuItem("Facebook Page", on_open_facebook),
    )

    def on_toggle_autostart(icon, item):
        set_autostart(not is_autostart_enabled())

    def on_update_item(icon, item):
        if _UPDATE_STATE["latest"]:
            _open_in_browser(_UPDATE_STATE["url"])
        elif not _UPDATE_STATE["checking"]:
            def _check_and_refresh():
                run_update_check()
                icon.update_menu()

            threading.Thread(target=_check_and_refresh, daemon=True).start()

    def _update_label(item):
        state = _UPDATE_STATE
        if state["checking"]:
            return "Checking for updates…"
        if state["latest"]:
            return f"⬇ Update available: v{state['latest']} — open release"
        if state["manual"]:
            return f"Up to date (v{APP_VERSION}) — check again"
        return "Check for updates"

    def on_quit(icon, item):
        icon.stop()

    items = [
        pystray.MenuItem("Open in browser", on_open, default=True),
        pystray.MenuItem("Copy app URL", on_copy_url),
        pystray.MenuItem("About", about_menu),
        pystray.MenuItem(
            "Start with Windows",
            on_toggle_autostart,
            checked=lambda item: is_autostart_enabled(),
        ),
    ]
    if update_check_enabled():
        items.append(pystray.MenuItem(_update_label, on_update_item))
    items += [pystray.Menu.SEPARATOR, pystray.MenuItem("Quit", on_quit)]

    return pystray.Icon("qrcode-generator", _tray_image(), "QR Code Generator", pystray.Menu(*items))


def _open_when_ready(url: str) -> None:
    """Poll the health endpoint, then open the app in the browser once it serves."""
    import urllib.request

    deadline = time.monotonic() + 45
    health_url = url.rstrip("/") + "/_stcore/health"
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(health_url, timeout=2) as response:
                if response.status == 200:
                    _open_in_browser(url)
                    return
        except Exception:
            pass
        time.sleep(1)


def _schedule_browser_open(url: str) -> None:
    if os.environ.get("QR_NO_BROWSER") != "1":
        threading.Thread(target=_open_when_ready, args=(url,), daemon=True).start()


def main() -> None:
    if is_frozen():
        multiprocessing.freeze_support()

    if os.environ.get("QR_SELFTEST") == "1":
        sys.exit(_selftest())

    _redirect_output()

    started_at_login = AUTOSTART_FLAG in sys.argv
    cmd, port = server_command()
    url = f"http://localhost:{port}"

    if os.environ.get("QR_NO_TRAY") == "1":
        # Console/dev mode: run the server in the main thread so Ctrl+C and
        # signal handling behave normally.
        _schedule_browser_open(url)
        _run_streamlit(cmd)
        return

    # Tray mode: server in a background thread (signals patched out),
    # tray icon message loop on the main thread.
    _disable_signal_handler()
    threading.Thread(target=_run_streamlit, args=(cmd,), daemon=True).start()

    # Auto-starting at login shouldn't hijack the browser; the tray icon stays
    # available for opening the app.
    if not started_at_login:
        _schedule_browser_open(url)

    icon = _build_tray(url)

    # Silent check at startup; the result shows up in the tray menu label.
    if update_check_enabled():
        def _initial_check():
            run_update_check()
            icon.update_menu()

        threading.Thread(target=_initial_check, daemon=True).start()

    icon.run()  # blocks until Quit is selected
    os._exit(0)  # tear down the daemon server thread immediately


if __name__ == "__main__":
    main()
