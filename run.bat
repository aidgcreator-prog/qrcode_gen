@echo off
setlocal
cd /d "%~dp0"

title QR Code Generator

echo Starting QR Code Generator...

:: 1. Check for uv
where uv >nul 2>nul
if %errorlevel% equ 0 (
    uv run python run_app.py %*
    goto :eof
)

:: 2. Check for local virtualenv
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" run_app.py %*
    goto :eof
)


:: 4. Fallback to system Python
where python >nul 2>nul
if %errorlevel% equ 0 (
    python run_app.py %*
    goto :eof
)

echo.
echo [ERROR] Could not find 'uv', Python in '.venv', or system Python.
echo Please install uv (https://docs.astral.sh/uv/) or Python to run the app.
echo.
pause
