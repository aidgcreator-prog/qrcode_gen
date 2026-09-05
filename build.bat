@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

title Building QR Code Generator

echo =======================================================
echo            Building QR Code Generator
echo =======================================================
echo.

:: 1. Locate Inno Setup Compiler (ISCC)
set "ISCC="
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
) else (
    where iscc >nul 2>nul
    if !errorlevel! equ 0 (
        for /f "delims=" %%i in ('where iscc') do set "ISCC=%%i"
    )
)

:: 2. Pre-build self-test
echo [1/3] Running pre-build validation self-test...
set "QR_SELFTEST=1"
where uv >nul 2>nul
if %errorlevel% equ 0 (
    uv run python run_app.py
) else if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" run_app.py
) else (
    python run_app.py
)
set "QR_SELFTEST="

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Self-test failed. Aborting build.
    echo.
    pause
    exit /b %errorlevel%
)
echo      Self-test passed!
echo.

:: 3. Stage 1: Build Portable Executable (PyInstaller)
echo [2/3] Compiling standalone executable with PyInstaller...
where uv >nul 2>nul
if %errorlevel% equ 0 (
    uv run pyinstaller --noconfirm build.spec
) else if exist ".venv\Scripts\pyinstaller.exe" (
    ".venv\Scripts\pyinstaller.exe" --noconfirm build.spec
) else (
    pyinstaller --noconfirm build.spec
)

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] PyInstaller build failed.
    echo.
    pause
    exit /b %errorlevel%
)

if not exist "dist\QRCodeGenerator.exe" (
    echo.
    echo [ERROR] dist\QRCodeGenerator.exe was not created.
    echo.
    pause
    exit /b 1
)
echo      Executable ready: dist\QRCodeGenerator.exe
echo.

:: 4. Stage 2: Build Windows Installer (Inno Setup)
echo [3/3] Compiling Windows Setup Installer with Inno Setup...
if not defined ISCC (
    echo.
    echo [WARNING] Inno Setup 6 compiler (ISCC.exe) was not found.
    echo Install Inno Setup 6 from: https://jrsoftware.org/isinfo.php
    echo The portable executable dist\QRCodeGenerator.exe is ready to use.
    echo.
    pause
    exit /b 0
)

"%ISCC%" installer.iss

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Inno Setup installer build failed.
    echo.
    pause
    exit /b %errorlevel%
)

echo.
echo =======================================================
echo                 BUILD SUCCESSFUL!
echo =======================================================
echo.
echo  - Standalone Exe: dist\QRCodeGenerator.exe
echo  - Setup Installer: installer\Output\
echo.
pause
