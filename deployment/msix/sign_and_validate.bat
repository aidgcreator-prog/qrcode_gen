@echo off
title QR Code Generator -- MSIX Sign and Validate

echo ========================================================
echo  QR Code Generator -- MSIX Signing and Validation Tool
echo ========================================================
echo.

rem If arguments are provided on command line, pass them directly
if not "%~1"=="" goto run_with_args

rem Interactive menu when launched without command-line arguments
echo Select operation mode:
echo   [1] Sign and Validate [Auto-detect or generate test cert]
echo   [2] Sign, Validate, and Install Test Cert to Trusted People [Recommended for local install]
echo   [3] Validate Only [Do not modify or re-sign current package]
echo   [4] Force Re-sign and Validate
echo   [5] Exit
echo.
set "CHOICE="
set /p "CHOICE=Enter choice [1-5] (default is 1): "

if "%CHOICE%"=="" set "CHOICE=1"
if "%CHOICE%"=="1" goto run_mode_1
if "%CHOICE%"=="2" goto run_mode_2
if "%CHOICE%"=="3" goto run_mode_3
if "%CHOICE%"=="4" goto run_mode_4
if "%CHOICE%"=="5" goto run_mode_exit

echo [WARN] Invalid selection "%CHOICE%". Running default Sign and Validate...
goto run_mode_1

:run_mode_1
echo.
echo [*] Running Sign and Validate...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sign_and_validate.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
goto finish_interactive

:run_mode_2
echo.
echo [*] Running Sign, Validate, and Install Certificate...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sign_and_validate.ps1" -InstallCert
set "EXIT_CODE=%ERRORLEVEL%"
goto finish_interactive

:run_mode_3
echo.
echo [*] Running Validation Only...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sign_and_validate.ps1" -ValidateOnly
set "EXIT_CODE=%ERRORLEVEL%"
goto finish_interactive

:run_mode_4
echo.
echo [*] Running Force Re-sign and Validate...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sign_and_validate.ps1" -ForceSign
set "EXIT_CODE=%ERRORLEVEL%"
goto finish_interactive

:run_mode_exit
echo Operation cancelled.
exit /b 0

:run_with_args
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sign_and_validate.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
if %EXIT_CODE% NEQ 0 (
    echo.
    echo [ERROR] Process failed with exit code %EXIT_CODE%.
    exit /b %EXIT_CODE%
)
exit /b 0

:finish_interactive
echo.
if %EXIT_CODE% NEQ 0 (
    echo [ERROR] Process completed with errors - exit code %EXIT_CODE%.
) else (
    echo [+] Process completed successfully.
)
echo.
echo Press any key to exit...
pause >nul
exit /b %EXIT_CODE%
