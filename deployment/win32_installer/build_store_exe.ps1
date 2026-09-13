<#
.SYNOPSIS
    Compiles the Inno Setup installer configured for Microsoft Store Win32 (.exe) submission.

.DESCRIPTION
    1. Checks/builds the PyInstaller executable (dist\QRCodeGenerator.exe).
    2. Invokes Inno Setup (ISCC.exe) to create the Windows setup installer.
    3. Outputs the installer path and exact silent installation parameters required by Microsoft Partner Center.

.PARAMETER Rebuild
    Force PyInstaller rebuild of QRCodeGenerator.exe before compiling setup.

.EXAMPLE
    .\deployment\win32_installer\build_store_exe.ps1
    .\deployment\win32_installer\build_store_exe.ps1 -Rebuild
#>

[CmdletBinding()]
param(
    [switch]$Rebuild
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$DistExe = Join-Path $ProjectRoot "dist\QRCodeGenerator.exe"
$IssPath = Join-Path $ProjectRoot "installer.iss"
$OutputDir = Join-Path $ProjectRoot "installer\Output"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " QR Code Generator -- Store Win32 (.exe) Packager" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate Inno Setup ISCC.exe
$IsccPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)

$Iscc = $null
foreach ($path in $IsccPaths) {
    if (Test-Path $path) {
        $Iscc = $path
        break
    }
}

if (-not $Iscc) {
    $found = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($found) {
        $Iscc = $found.Source
    }
}

if (-not $Iscc) {
    throw "Inno Setup 6 (ISCC.exe) was not found. Please install Inno Setup 6 from https://jrsoftware.org/isdl.php"
}
Write-Host "  Found Inno Setup compiler: $Iscc" -ForegroundColor Green

# 2. Check / Build Dist Executable
Write-Host "`nChecking standalone executable ($DistExe)..." -ForegroundColor Yellow
if ($Rebuild -or -not (Test-Path $DistExe)) {
    Write-Host "  Building QRCodeGenerator.exe via PyInstaller..." -ForegroundColor Cyan
    Push-Location $ProjectRoot
    try {
        & uv run pyinstaller --noconfirm build.spec
    } finally {
        Pop-Location
    }
    if (-not (Test-Path $DistExe)) {
        throw "Build failed: $DistExe not found."
    }
}
Write-Host "  Executable ready: $DistExe" -ForegroundColor Green

# 3. Compile Inno Setup Script
Write-Host "`nCompiling Inno Setup script ($IssPath)..." -ForegroundColor Yellow
Push-Location $ProjectRoot
try {
    & $Iscc $IssPath
} finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed."
}

$Installer = Get-ChildItem -Path $OutputDir -Filter "*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $Installer) {
    throw "Installer executable not found in $OutputDir"
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " SUCCESS! Win32 Installer ready for Store submission:" -ForegroundColor Green
Write-Host " $($Installer.FullName)" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "`nPartner Center Win32 Installer Settings:" -ForegroundColor Yellow
Write-Host "  Installer type:               EXE"
Write-Host "  Silent install parameters:    /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
Write-Host "  Silent uninstall parameters:  /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
Write-Host "  Install return codes:         0 (Success)"
