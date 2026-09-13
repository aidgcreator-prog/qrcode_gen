@echo off
setlocal EnableDelayedExpansion
title QR Code Generator -- Complete Store Packaging Pipeline

echo ========================================================
echo  QR Code Generator -- Complete Store Build ^& Package
echo ========================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_all.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Pipeline failed with exit code %ERRORLEVEL%.
    if "%1"=="" pause
    exit /b %ERRORLEVEL%
)

echo.
echo [+] All deployment steps completed successfully.
if "%1"=="" (
    echo.
    echo Press any key to exit...
    pause >nul
)
exit /b 0
