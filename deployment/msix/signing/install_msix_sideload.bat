@echo off
setlocal
title Installing QR Code Generator MSIX...
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_msix_sideload.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if %EXIT_CODE% NEQ 0 (
    echo.
    echo [!] Sideload installation failed with code %EXIT_CODE%.
    pause
    exit /b %EXIT_CODE%
)
exit /b 0
