@echo off
:: =====================================================================
:: VALIDATE_MSIX.bat — Automated MSIX Validation & WACK Certification Suite
:: =====================================================================
:: End-to-End Validation Workflow:
::   1. Manifest, Assets & Filename Compliance Checks (scan_msix.py)
::   2. Package & Digital Signature Verification (SignTool)
::   3. Installed Appx Package Check (Get-AppxPackage)
::   4. Automated Windows App Certification Kit (WACK) Validation (run_wack.ps1)
::   5. Generates Report: deployment\msix\output\wack_report.xml (parse_wack_report.py)
:: =====================================================================
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
for %%i in ("%SCRIPT_DIR%..\..") do set "PROJECT_ROOT=%%~fi"

set "OUTPUT_DIR=%SCRIPT_DIR%output"
set "MSIX_FILE=%OUTPUT_DIR%\QRCodeGenerator.msix"
set "REPORT_XML=%OUTPUT_DIR%\wack_report.xml"
set "SCAN_SCRIPT=%SCRIPT_DIR%scan_msix.py"
set "PARSE_SCRIPT=%SCRIPT_DIR%parse_wack_report.py"
set "WACK_RUNNER=%SCRIPT_DIR%run_wack.ps1"
set "MANIFEST_FILE=%SCRIPT_DIR%AppxManifest.xml"
set "ASSETS_DIR=%SCRIPT_DIR%Assets"
set "PACKAGE_NAME=LocalAiLab.QRCodeGen"

set "PF86=C:\Program Files (x86)"
set "PF64=C:\Program Files"

echo.
echo ============================================================
echo   QR Code Generator: MSIX Validation ^& WACK Certification
echo ============================================================
echo.

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: ---------------------------------------------------------------
:: Step 1: Pre-packaging Hygiene & Manifest Validation
:: ---------------------------------------------------------------
echo [Step 1/4] Running Pre-Packaging ^& Manifest Checks...

if not exist "%MANIFEST_FILE%" (
    echo [ERROR] AppxManifest.xml missing at: %MANIFEST_FILE%
    exit /b 1
)
echo [+] Manifest found: %MANIFEST_FILE%

if not exist "%ASSETS_DIR%\StoreLogo.png" (
    echo [ERROR] Store visual assets missing in: %ASSETS_DIR%
    exit /b 1
)
echo [+] Store visual assets verified.

if exist "%SCAN_SCRIPT%" (
    echo [*] Scanning for MSIX-incompatible filenames...
    call uv run python "%SCAN_SCRIPT%"
    if !ERRORLEVEL! NEQ 0 (
        echo [WARNING] Filename scan found issues. Review above before packaging.
    ) else (
        echo [+] Filename scan clean.
    )
)
echo.

:: ---------------------------------------------------------------
:: Step 2: Locate Windows SDK & WACK Tools
:: ---------------------------------------------------------------
echo [Step 2/4] Locating Windows App Certification Kit ^(WACK^)...

set "APPCERT="
set "SIGNTOOL="

if exist "!PF86!\Windows Kits\10\App Certification Kit\appcert.exe" (
    set "APPCERT=!PF86!\Windows Kits\10\App Certification Kit\appcert.exe"
)
if not defined APPCERT (
    if exist "!PF64!\Windows Kits\10\App Certification Kit\appcert.exe" (
        set "APPCERT=!PF64!\Windows Kits\10\App Certification Kit\appcert.exe"
    )
)

for %%v in (10.0.26100.0 10.0.22621.0 10.0.22000.0 10.0.19041.0 10.0.18362.0 10.0.17763.0) do (
    if not defined SIGNTOOL (
        if exist "!PF86!\Windows Kits\10\bin\%%v\x64\signtool.exe" (
            set "SIGNTOOL=!PF86!\Windows Kits\10\bin\%%v\x64\signtool.exe"
        )
    )
    if not defined SIGNTOOL (
        if exist "!PF64!\Windows Kits\10\bin\%%v\x64\signtool.exe" (
            set "SIGNTOOL=!PF64!\Windows Kits\10\bin\%%v\x64\signtool.exe"
        )
    )
)

if not defined APPCERT (
    echo [ERROR] appcert.exe ^(Windows App Certification Kit^) was not found.
    echo         Please install the Windows App Certification Kit from Windows SDK.
    exit /b 1
)
echo [+] Found WACK     : !APPCERT!

if defined SIGNTOOL (
    echo [+] Found SignTool : !SIGNTOOL!
)
echo.

:: ---------------------------------------------------------------
:: Step 3: Package & Digital Signature Check
:: ---------------------------------------------------------------
echo [Step 3/4] Verifying MSIX Package ^& Digital Signature...

if not exist "%MSIX_FILE%" (
    echo [WARNING] %MSIX_FILE% not found.
    echo           Please run BUILD_MSIX.bat first to build and package the MSIX.
    exit /b 1
)

if defined SIGNTOOL (
    echo [*] Verifying Authenticode signature...
    "!SIGNTOOL!" verify /pa /v "%MSIX_FILE%" >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo [+] Digital signature valid.
    ) else (
        echo [WARN] Digital signature verification failed or cert not trusted.
        echo        Run deployment\msix\sign_and_validate.bat to sign and trust.
    )
)
echo.

:: ---------------------------------------------------------------
:: Step 4: Run Windows App Certification Kit (WACK)
:: ---------------------------------------------------------------
echo [Step 4/4] Executing WACK Automated Tests...
echo [*] Checking if %PACKAGE_NAME% is installed...

set "TEMP_PKG=%TEMP%\msix_pkg_%RANDOM%.txt"
powershell -NoProfile -Command ^
    "$pkg = (Get-AppxPackage -Name %PACKAGE_NAME%).PackageFullName;" ^
    "if ($pkg) { Set-Content -LiteralPath '%TEMP_PKG%' -Value $pkg }"

set "PKG_FULLNAME="
if exist "%TEMP_PKG%" (
    for /f "usebackq delims=" %%p in ("%TEMP_PKG%") do set "PKG_FULLNAME=%%p"
    del /f /q "%TEMP_PKG%" >nul 2>&1
)

if not defined PKG_FULLNAME (
    echo [INFO] Package '%PACKAGE_NAME%' is not currently installed.
    echo [*] Attempting to test-sign and install package...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%signing\sign_msix_test.ps1"
    
    powershell -NoProfile -Command ^
        "$pkg = (Get-AppxPackage -Name %PACKAGE_NAME%).PackageFullName;" ^
        "if ($pkg) { Set-Content -LiteralPath '%TEMP_PKG%' -Value $pkg }"
    if exist "%TEMP_PKG%" (
        for /f "usebackq delims=" %%p in ("%TEMP_PKG%") do set "PKG_FULLNAME=%%p"
        del /f /q "%TEMP_PKG%" >nul 2>&1
    )
)

if not defined PKG_FULLNAME (
    echo [ERROR] Could not install or find package '%PACKAGE_NAME%'.
    echo         Please run deployment\msix\signing\install_msix_sideload.bat as Administrator first.
    exit /b 1
)

echo [+] Target Package: !PKG_FULLNAME!
echo [*] Launching WACK certification runner...
echo [*] Report output path: %REPORT_XML%

powershell -NoProfile -ExecutionPolicy Bypass -File "%WACK_RUNNER%" -AppCertPath "!APPCERT!" -PackageFullName "!PKG_FULLNAME!" -ReportPath "%REPORT_XML%"

echo.
echo ============================================================
echo   Validation Results ^& Summary
echo ============================================================

if exist "%REPORT_XML%" (
    echo [+] Report generated: %REPORT_XML%
    echo [*] Parsing test results summary...
    call uv run python "%PARSE_SCRIPT%" "%REPORT_XML%"
) else (
    echo [WARN] Report file not found at: %REPORT_XML%
)

echo.
echo Validation process complete.
exit /b 0
