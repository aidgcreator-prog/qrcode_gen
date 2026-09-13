<#
.SYNOPSIS
    Runs all Microsoft Store deployment and packaging steps in sequence.

.DESCRIPTION
    1. Validates the app (QR_SELFTEST and Streamlit AppTest).
    2. Generates all 40+ Microsoft Store visual assets.
    3. Builds the PyInstaller standalone executable (QRCodeGenerator.exe).
    4. Compiles the native Microsoft Store MSIX package (QRCodeGenerator.msix).
    5. Compiles the Inno Setup Win32 installer (QR-Code-Generator-Setup-*.exe).

.PARAMETER Sign
    Signs the MSIX with a local test certificate for sideload testing.

.PARAMETER SkipTests
    Skips the automated validation self-tests.

.EXAMPLE
    .\deployment\build_all.ps1
    .\deployment\build_all.ps1 -Sign
    .\deployment\build_all.ps1 -SkipTests
#>

[CmdletBinding()]
param(
    [switch]$Sign,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\.."

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " QR Code Generator -- Complete Store Build and Package" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Step 1: Tests
if (-not $SkipTests) {
    Write-Host "`n[Step 1/5] Running validation self-tests..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    try {
        $env:QR_SELFTEST = "1"
        & uv run python run_app.py
        if ($LASTEXITCODE -ne 0) { throw "QR_SELFTEST failed." }
        $env:QR_SELFTEST = $null

        & uv run python -c "from streamlit.testing.v1 import AppTest; at = AppTest.from_file('main.py'); at.run(timeout=15); assert not at.exception; print('AppTest passed!')"
        if ($LASTEXITCODE -ne 0) { throw "Streamlit AppTest failed." }
    } finally {
        $env:QR_SELFTEST = $null
        Pop-Location
    }
    Write-Host "  [+] Tests passed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n[Step 1/5] Skipping validation self-tests (-SkipTests specified)." -ForegroundColor DarkGray
}

# Step 2: Store Visual Assets
Write-Host "`n[Step 2/5] Generating Microsoft Store visual assets..." -ForegroundColor Yellow
& uv run python "$ScriptDir\msix\generate_assets.py"
if ($LASTEXITCODE -ne 0) { throw "Asset generation failed." }
Write-Host "  [+] Assets ready in deployment/msix/Assets/" -ForegroundColor Green

# Step 3: Standalone Executable (PyInstaller)
Write-Host "`n[Step 3/5] Compiling PyInstaller standalone executable..." -ForegroundColor Yellow
Push-Location $ProjectRoot
try {
    & uv run pyinstaller --noconfirm build.spec
    if ($LASTEXITCODE -ne 0) { throw "PyInstaller compilation failed." }
} finally {
    Pop-Location
}
Write-Host "  [+] Executable ready: dist\QRCodeGenerator.exe" -ForegroundColor Green

# Step 4: MSIX Package
Write-Host "`n[Step 4/5] Packaging native Microsoft Store MSIX package..." -ForegroundColor Yellow
$msixParams = @{}
if ($Sign) { $msixParams["Sign"] = $true }
& "$ScriptDir\msix\build_msix.ps1" @msixParams
if ($LASTEXITCODE -ne 0) { throw "MSIX packaging failed." }

# Step 5: Win32 Installer (Inno Setup)
Write-Host "`n[Step 5/5] Compiling Win32 Inno Setup installer..." -ForegroundColor Yellow
& "$ScriptDir\win32_installer\build_store_exe.ps1"
if ($LASTEXITCODE -ne 0) { throw "Win32 installer compilation failed." }

# Final Summary
$MsixFile = Get-Item "$ScriptDir\msix\output\QRCodeGenerator.msix" -ErrorAction SilentlyContinue
$ExeInstaller = Get-ChildItem "$ProjectRoot\installer\Output\*.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ALL STEPS COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Produced packages ready for Microsoft Store:"
if ($MsixFile) {
    $sizeMB = [math]::Round($MsixFile.Length / 1MB, 2)
    Write-Host "  [MSIX Package]   $($MsixFile.FullName) ($sizeMB MB)" -ForegroundColor White
}
if ($ExeInstaller) {
    $sizeMB = [math]::Round($ExeInstaller.Length / 1MB, 2)
    Write-Host "  [Win32 Setup]    $($ExeInstaller.FullName) ($sizeMB MB)" -ForegroundColor White
}
Write-Host "`nNext: Follow deployment/MICROSOFT_STORE_GUIDE.md to upload to Microsoft Partner Center."
