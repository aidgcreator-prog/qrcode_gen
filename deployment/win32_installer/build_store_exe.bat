@echo off
setlocal EnableDelayedExpansion
title Building Microsoft Store Win32 (.exe) Installer...

echo ========================================================
echo  QR Code Generator -- Store Win32 (.exe) Packager
echo ========================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_store_exe.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Build failed with exit code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

echo.
echo [+] Store Win32 installer build completed successfully.
exit /b 0
