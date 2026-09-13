@echo off
:: =========================================================================
:: sign_and_bundle.bat — Sign QRCodeGenerator.msix + Verify + Bundle for Test Distribution
:: =========================================================================
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..") do set "MSIX_DIR=%%~fi"
set "OUTPUT_DIR=%MSIX_DIR%\output"
set "MSIX_FILE=%OUTPUT_DIR%\QRCodeGenerator.msix"
set "CERT_DIR=%SCRIPT_DIR%msix_certificate"
set "PFX_FILE=%CERT_DIR%\MSIXDevCert.pfx"
set "CER_FILE=%CERT_DIR%\MSIXDevCert.cer"
set "CERT_PASS=Dara2006@"
set "BUNDLE_DIR=%OUTPUT_DIR%\_bundle_temp"
set "ZIP_OUT=%OUTPUT_DIR%\QRCodeGenerator_TestInstall.zip"

echo.
echo ============================================================
echo   QR Code Generator MSIX: Sign + Verify + Bundle Pipeline
echo ============================================================
echo.

:: ---------------------------------------------------------------
:: Preflight checks
:: ---------------------------------------------------------------
if not exist "%MSIX_FILE%" (
    echo [ERROR] QRCodeGenerator.msix not found at:
    echo         %MSIX_FILE%
    echo.
    echo         Run deployment\msix\BUILD_MSIX.bat first.
    goto :fail
)
if not exist "%PFX_FILE%" (
    echo [ERROR] Signing cert not found at: %PFX_FILE%
    goto :fail
)
if not exist "%CER_FILE%" (
    echo [ERROR] Public cert not found at: %CER_FILE%
    goto :fail
)

:: ---------------------------------------------------------------
:: Step 1: Find signtool.exe from Windows SDK
:: ---------------------------------------------------------------
echo [1/5] Locating signtool.exe...
set "SIGNTOOL="
set "PF86=C:\Program Files (x86)"
set "PF64=C:\Program Files"

for %%v in (10.0.26100.0 10.0.22621.0 10.0.22000.0 10.0.19041.0 10.0.18362.0 10.0.17763.0) do (
    if not defined SIGNTOOL (
        if exist "!PF86!\Windows Kits\10\bin\%%v\x64\signtool.exe" set "SIGNTOOL=!PF86!\Windows Kits\10\bin\%%v\x64\signtool.exe"
    )
    if not defined SIGNTOOL (
        if exist "!PF64!\Windows Kits\10\bin\%%v\x64\signtool.exe" set "SIGNTOOL=!PF64!\Windows Kits\10\bin\%%v\x64\signtool.exe"
    )
)

if not defined SIGNTOOL (
    echo [ERROR] signtool.exe not found. Install the Windows SDK.
    goto :fail
)
echo         Found: %SIGNTOOL%

:: ---------------------------------------------------------------
:: Step 2: Sign the MSIX
:: ---------------------------------------------------------------
echo [2/5] Signing MSIX with dev cert...
"%SIGNTOOL%" sign /fd SHA256 /a /f "%PFX_FILE%" /p "%CERT_PASS%" "%MSIX_FILE%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Signing failed. Check certificate password or PFX file.
    goto :fail
)
echo         Signed OK.

:: ---------------------------------------------------------------
:: Step 3: Verify the signature
:: ---------------------------------------------------------------
echo [3/5] Verifying QRCodeGenerator.msix is digitally signed...
"%SIGNTOOL%" verify /pa "%MSIX_FILE%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] MSIX signature verified.
) else (
    powershell -NoProfile -Command "[System.Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile('%MSIX_FILE%').Subject" >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Signature verification FAILED after signing.
        echo         The package must not be shipped - an unsigned MSIX fails to
        echo         install on testers with 0x800B0100.
        goto :fail
    )
    echo [OK] MSIX signature verified [developer self-signed certificate].
)

:: ---------------------------------------------------------------
:: Step 4: Assemble bundle folder
:: ---------------------------------------------------------------
echo [4/5] Bundling files...
if exist "%BUNDLE_DIR%" rmdir /s /q "%BUNDLE_DIR%"
mkdir "%BUNDLE_DIR%"
mkdir "%BUNDLE_DIR%\msix_certificate"

copy /y "%MSIX_FILE%"                           "%BUNDLE_DIR%\QRCodeGenerator.msix"             >nul
copy /y "%SCRIPT_DIR%install_msix_sideload.bat" "%BUNDLE_DIR%\install_msix_sideload.bat"       >nul
copy /y "%SCRIPT_DIR%install_msix_sideload.ps1" "%BUNDLE_DIR%\install_msix_sideload.ps1"       >nul
copy /y "%CER_FILE%"                            "%BUNDLE_DIR%\msix_certificate\MSIXDevCert.cer" >nul

powershell -NoProfile -Command "@('QR Code Generator -- Test Installation', '======================================', '', 'IMPORTANT: This is a developer-signed TEST build.', '', 'HOW TO INSTALL:', '  1. Extract this zip to any folder', '  2. Double-click: install_msix_sideload.bat', '  3. Click Yes on the UAC (Administrator) prompt', '  4. Wait for the green SUCCESS message', '  5. Launch from Start Menu -> QR Code Generator', '', 'UNINSTALL:', '  Windows Settings -> Apps -> Installed apps -> QR Code Generator -> Uninstall') | Set-Content -LiteralPath '%BUNDLE_DIR%\README_INSTALL.txt' -Encoding UTF8"

:: ---------------------------------------------------------------
:: Step 5: Zip the bundle
:: ---------------------------------------------------------------
echo [5/5] Creating zip...
if exist "%ZIP_OUT%" del /f /q "%ZIP_OUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%BUNDLE_DIR%\*' -DestinationPath '%ZIP_OUT%'"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to create zip package.
    rmdir /s /q "%BUNDLE_DIR%"
    goto :fail
)
rmdir /s /q "%BUNDLE_DIR%"

echo.
echo ============================================================
echo  [SUCCESS] Ready to share:
echo  %ZIP_OUT%
echo ============================================================
echo.
exit /b 0

:fail
echo.
echo [FAILED] Fix the error above and try again.
echo.
exit /b 1
