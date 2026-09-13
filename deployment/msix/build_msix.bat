@echo off
:: =====================================================================
:: BUILD_MSIX.bat — All-In-One: Build, Package, Sign and Bundle QR Code Generator MSIX
:: =====================================================================
:: End-to-End Workflow:
::   1. Auto-logs all output to terminal and output\_build_log.txt
::   2. Locates Windows SDK tools (MakeAppx.exe and SignTool.exe)
::   3. Ensures Microsoft Store visual assets exist (generate_assets.py)
::   4. Builds standalone executable if missing (uv run pyinstaller build.spec)
::   5. Stages layout, runs clean_msix_stage.py and generates MakeAppx mapping file
::   6. Compiles MSIX package via MakeAppx.exe
::   7. Digitally signs MSIX with test certificate and verifies signature
::   8. Bundles signed MSIX + cert + installer into QRCodeGenerator_TestInstall.zip
:: =====================================================================
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..\..") do set "PROJECT_ROOT=%%~fi"
set "DIST_EXE=%PROJECT_ROOT%\dist\QRCodeGenerator.exe"
set "ASSETS_SRC=%SCRIPT_DIR%Assets"
set "MANIFEST_SRC=%SCRIPT_DIR%AppxManifest.xml"
set "OUTPUT_DIR=%SCRIPT_DIR%output"
set "MSIX_OUT=%OUTPUT_DIR%\QRCodeGenerator.msix"
set "STAGE_DIR=%SCRIPT_DIR%staging"

set "CERT_DIR=%SCRIPT_DIR%signing\msix_certificate"
set "PFX_FILE=%CERT_DIR%\MSIXDevCert.pfx"
set "CER_FILE=%CERT_DIR%\MSIXDevCert.cer"
set "CERT_PASS=Dara2006@"
set "BUNDLE_DIR=%OUTPUT_DIR%\_bundle_temp"
set "ZIP_OUT=%OUTPUT_DIR%\QRCodeGenerator_TestInstall.zip"

:: ---------------------------------------------------------------
:: Auto-Logging: re-invoke self so all output is BOTH shown live
:: on the console AND saved to a log file (Tee-Object pattern).
:: ---------------------------------------------------------------
if not defined BUILD_MSIX_LOG_ACTIVE (
    if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
    set "BUILD_MSIX_LOG_ACTIVE=1"
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$env:BUILD_MSIX_LOG_ACTIVE = '1';" ^
        "$ts = Get-Date -Format 'yyyyMMdd_HHmmss';" ^
        "$env:BUILD_TS = $ts;" ^
        "$latest = '%OUTPUT_DIR%\_build_log.txt';" ^
        "$archive = '%OUTPUT_DIR%\_build_log_' + $ts + '.txt';" ^
        "Write-Host ('[Log] Saving output to: ' + $latest);" ^
        "cmd.exe /c '\"%~f0\"' 2>&1 |" ^
        "  Tee-Object -FilePath $latest |" ^
        "  Tee-Object -FilePath $archive;" ^
        "exit $LASTEXITCODE"
    exit /b %ERRORLEVEL%
)

if not defined BUILD_TS (
    for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "BUILD_TS=%%I"
)
set "MSIX_TIMESTAMPED=%OUTPUT_DIR%\QRCodeGenerator_%BUILD_TS%.msix"
set "ZIP_TIMESTAMPED=%OUTPUT_DIR%\QRCodeGenerator_TestInstall_%BUILD_TS%.zip"

echo.
echo ============================================================
echo   QR Code Generator: Complete MSIX Build, Sign ^& Bundle
echo ============================================================
echo.

:: ---------------------------------------------------------------
:: Step 1: Find Windows SDK tools (MakeAppx.exe and SignTool.exe)
:: ---------------------------------------------------------------
echo [Step 1/7] Locating Windows SDK tools...
set "MAKEAPPX="
set "SIGNTOOL="
set "PF86=C:\Program Files (x86)"
set "PF64=C:\Program Files"

for %%v in (10.0.26100.0 10.0.22621.0 10.0.22000.0 10.0.19041.0 10.0.18362.0 10.0.17763.0) do (
    if not defined MAKEAPPX (
        if exist "!PF86!\Windows Kits\10\bin\%%v\x64\makeappx.exe" set "MAKEAPPX=!PF86!\Windows Kits\10\bin\%%v\x64\makeappx.exe"
    )
    if not defined SIGNTOOL (
        if exist "!PF86!\Windows Kits\10\bin\%%v\x64\signtool.exe" set "SIGNTOOL=!PF86!\Windows Kits\10\bin\%%v\x64\signtool.exe"
    )
    if not defined MAKEAPPX (
        if exist "!PF64!\Windows Kits\10\bin\%%v\x64\makeappx.exe" set "MAKEAPPX=!PF64!\Windows Kits\10\bin\%%v\x64\makeappx.exe"
    )
    if not defined SIGNTOOL (
        if exist "!PF64!\Windows Kits\10\bin\%%v\x64\signtool.exe" set "SIGNTOOL=!PF64!\Windows Kits\10\bin\%%v\x64\signtool.exe"
    )
)

if not defined MAKEAPPX (
    echo [ERROR] MakeAppx.exe not found. Install Windows SDK.
    exit /b 1
)
if not defined SIGNTOOL (
    echo [ERROR] SignTool.exe not found. Install Windows SDK.
    exit /b 1
)
echo [+] Found MakeAppx : %MAKEAPPX%
echo [+] Found SignTool : %SIGNTOOL%

:: Stop any running instance
taskkill /F /IM QRCodeGenerator.exe >nul 2>&1

:: ---------------------------------------------------------------
:: Step 2: Ensure visual assets exist
:: ---------------------------------------------------------------
echo.
echo [Step 2/7] Checking visual assets in %ASSETS_SRC%...
if not exist "%ASSETS_SRC%\StoreLogo.png" (
    echo [*] Generating visual assets...
    call uv run python "%SCRIPT_DIR%generate_assets.py"
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to generate visual assets.
        exit /b 1
    )
) else (
    echo [+] Visual assets verified.
)

:: ---------------------------------------------------------------
:: Step 3: Check / Build standalone executable
:: ---------------------------------------------------------------
echo.
echo [Step 3/7] Checking standalone executable: %DIST_EXE%...
if not exist "%DIST_EXE%" (
    echo [*] Building executable with PyInstaller [build.spec]...
    pushd "%PROJECT_ROOT%"
    call uv run pyinstaller --noconfirm build.spec
    set "BUILD_EXIT=!ERRORLEVEL!"
    popd
    if !BUILD_EXIT! NEQ 0 (
        echo [ERROR] PyInstaller build failed.
        exit /b 1
    )
)
if not exist "%DIST_EXE%" (
    echo [ERROR] Dist executable not found: %DIST_EXE%
    exit /b 1
)
echo [+] Standalone executable ready.

:: ---------------------------------------------------------------
:: Step 4: Prepare staging layout & clean
:: ---------------------------------------------------------------
echo.
echo [Step 4/7] Staging package files in %STAGE_DIR%...
if exist "%STAGE_DIR%" rmdir /S /Q "%STAGE_DIR%"
mkdir "%STAGE_DIR%"
mkdir "%STAGE_DIR%\Assets"

copy /Y "%MANIFEST_SRC%" "%STAGE_DIR%\AppxManifest.xml" >nul
xcopy /Y /Q /E "%ASSETS_SRC%\*" "%STAGE_DIR%\Assets\" >nul
copy /Y "%DIST_EXE%" "%STAGE_DIR%\QRCodeGenerator.exe" >nul

echo [*] Sanitizing staging layout...
call uv run python "%SCRIPT_DIR%clean_msix_stage.py" "%STAGE_DIR%"
if !ERRORLEVEL! NEQ 0 (
    echo [ERROR] clean_msix_stage.py reported fatal issues.
    exit /b 1
)
echo [+] Staging directory ready and sanitized.

:: ---------------------------------------------------------------
:: Step 5: Generate mapping file & Pack MSIX
:: ---------------------------------------------------------------
echo.
echo [Step 5/7] Compiling MSIX package with MakeAppx...
set "MAP_FILE=%TEMP%\qrcodegen_msix_%RANDOM%.map"
call uv run python "%SCRIPT_DIR%generate_msix_map.py" "%STAGE_DIR%" "%MAP_FILE%"
if !ERRORLEVEL! NEQ 0 (
    echo [ERROR] Failed to generate mapping file.
    exit /b 1
)

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if exist "%MSIX_OUT%" del /F /Q "%MSIX_OUT%"

"%MAKEAPPX%" pack /o /f "%MAP_FILE%" /p "%MSIX_OUT%" /nv
set "PACK_EXIT=!ERRORLEVEL!"
del /F /Q "%MAP_FILE%" >nul 2>&1

if !PACK_EXIT! NEQ 0 (
    echo [ERROR] MakeAppx failed to package MSIX.
    exit /b 1
)
echo [+] Package created: %MSIX_OUT%

:: ---------------------------------------------------------------
:: Step 6: Digitally sign MSIX and verify
:: ---------------------------------------------------------------
echo.
echo [Step 6/7] Digitally signing MSIX package...
if exist "%PFX_FILE%" (
    "%SIGNTOOL%" sign /fd SHA256 /a /f "%PFX_FILE%" /p "%CERT_PASS%" "%MSIX_OUT%"
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] SignTool signing failed.
        exit /b 1
    )
) else (
    echo [*] Calling sign_and_validate.ps1 to apply local certificate...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%sign_and_validate.ps1" -MsixPath "%MSIX_OUT%" -ForceSign -SkipAppTests
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Certificate signing failed.
        exit /b 1
    )
)

echo [*] Verifying digital signature...
"%SIGNTOOL%" verify /pa "%MSIX_OUT%" >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    echo [+] Digital signature successfully verified!
) else (
    powershell -NoProfile -Command "[System.Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile('%MSIX_OUT%').Subject" >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Signature verification FAILED. Package is not digitally signed.
        exit /b 1
    )
    echo [+] Digital signature verified [developer self-signed certificate].
)

copy /Y "%MSIX_OUT%" "%MSIX_TIMESTAMPED%" >nul
echo [+] Saved timestamped copy: %MSIX_TIMESTAMPED%

:: ---------------------------------------------------------------
:: Step 7: Bundle for Test Distribution (.zip)
:: ---------------------------------------------------------------
echo.
echo [Step 7/7] Assembling shareable test bundle zip...
if exist "%BUNDLE_DIR%" rmdir /S /Q "%BUNDLE_DIR%"
mkdir "%BUNDLE_DIR%"
mkdir "%BUNDLE_DIR%\msix_certificate"

copy /Y "%MSIX_OUT%"                                    "%BUNDLE_DIR%\QRCodeGenerator.msix"             >nul
copy /Y "%SCRIPT_DIR%signing\install_msix_sideload.bat" "%BUNDLE_DIR%\install_msix_sideload.bat"       >nul
copy /Y "%SCRIPT_DIR%signing\install_msix_sideload.ps1" "%BUNDLE_DIR%\install_msix_sideload.ps1"       >nul
if exist "%CER_FILE%" (
    copy /Y "%CER_FILE%"                                "%BUNDLE_DIR%\msix_certificate\MSIXDevCert.cer" >nul
)

powershell -NoProfile -Command "@('QR Code Generator -- Test Installation', '======================================', '', 'IMPORTANT: This is a developer-signed TEST build.', '', 'HOW TO INSTALL:', '  1. Extract this zip to any folder', '  2. Double-click: install_msix_sideload.bat', '  3. Click Yes on the UAC (Administrator) prompt', '  4. Wait for the green SUCCESS message', '  5. Launch from Start Menu -> QR Code Generator', '', 'UNINSTALL:', '  Windows Settings -> Apps -> Installed apps -> QR Code Generator -> Uninstall') | Set-Content -LiteralPath '%BUNDLE_DIR%\README_INSTALL.txt' -Encoding UTF8"

if exist "%ZIP_TIMESTAMPED%" del /F /Q "%ZIP_TIMESTAMPED%"
if exist "%ZIP_OUT%" del /F /Q "%ZIP_OUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%BUNDLE_DIR%\*' -DestinationPath '%ZIP_TIMESTAMPED%'"
set "ZIP_EXIT=!ERRORLEVEL!"
copy /Y "%ZIP_TIMESTAMPED%" "%ZIP_OUT%" >nul
rmdir /S /Q "%BUNDLE_DIR%"

if !ZIP_EXIT! NEQ 0 (
    echo [ERROR] Failed to create test bundle zip.
    exit /b 1
)

echo.
echo ============================================================
echo  [SUCCESS] All steps completed successfully!
echo ============================================================
echo.
echo  1. MSIX Package [Signed with Timestamp]:
echo     %MSIX_TIMESTAMPED%
echo     (Copy maintained at: %MSIX_OUT%)
echo.
echo  2. Test Distribution Zip [Share with testers]:
echo     %ZIP_TIMESTAMPED%
echo     (Copy maintained at: %ZIP_OUT%)
echo.
echo  Next Steps:
echo    - TEST locally: Double-click deployment\msix\signing\install_msix_sideload.bat
echo    - VALIDATE: Run deployment\msix\VALIDATE_MSIX.bat
echo    - SUBMIT to Store: Upload %MSIX_TIMESTAMPED% to Microsoft Partner Center
echo ============================================================
echo.
exit /b 0
