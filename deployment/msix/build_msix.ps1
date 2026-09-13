<#
.SYNOPSIS
    Automated build and packaging script for Microsoft Store MSIX distribution.

.DESCRIPTION
    1. Ensures visual assets exist (runs generate_assets.py).
    2. Builds the executable via PyInstaller (build.spec) if needed.
    3. Prepares the MSIX staging layout.
    4. Compiles the MSIX package using the Windows SDK MakeAppx.exe.
    5. Optionally signs the package with a local self-signed certificate for test sideloading.

.PARAMETER Rebuild
    Force PyInstaller rebuild of QRCodeGenerator.exe even if it already exists in dist/.

.PARAMETER Sign
    Create and apply a local self-signed certificate for local sideloading testing.
    (Not needed for Microsoft Store submissions; Microsoft Store re-signs upon submission).

.EXAMPLE
    .\deployment\msix\build_msix.ps1
    .\deployment\msix\build_msix.ps1 -Rebuild
    .\deployment\msix\build_msix.ps1 -Sign
#>

[CmdletBinding()]
param(
    [switch]$Rebuild,
    [switch]$Sign
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$StagingDir = Join-Path $ScriptDir "staging"
$OutputDir = Join-Path $ScriptDir "output"
$ManifestPath = Join-Path $ScriptDir "AppxManifest.xml"
$AssetsDir = Join-Path $ScriptDir "Assets"
$DistExe = Join-Path $ProjectRoot "dist\QRCodeGenerator.exe"
$OutputMsix = Join-Path $OutputDir "QRCodeGenerator.msix"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " QR Code Generator -- Microsoft Store (MSIX) Packager" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate Windows SDK MakeAppx.exe
Write-Host "`n[1/5] Locating Windows SDK MakeAppx.exe..." -ForegroundColor Yellow
$WindowsKits = @(
    "C:\Program Files (x86)\Windows Kits\10\bin",
    "C:\Program Files\Windows Kits\10\bin"
)

$MakeAppx = $null
foreach ($kit in $WindowsKits) {
    if (Test-Path $kit) {
        $found = Get-ChildItem -Path $kit -Recurse -Filter "makeappx.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\x64\\makeappx\.exe$" } |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1

        if ($found) {
            $MakeAppx = $found.FullName
            break
        }
    }
}

if (-not $MakeAppx) {
    throw "MakeAppx.exe was not found. Please install the Windows 10/11 SDK or Visual Studio Desktop development tools."
}
Write-Host "  Found MakeAppx: $MakeAppx" -ForegroundColor Green

# 2. Generate Store Visual Assets
Write-Host "`n[2/5] Checking visual assets in $AssetsDir..." -ForegroundColor Yellow
$StoreLogo = Join-Path $AssetsDir "StoreLogo.png"
if (-not (Test-Path $StoreLogo)) {
    Write-Host "  Generating visual assets via generate_assets.py..." -ForegroundColor Cyan
    & uv run python "$ScriptDir\generate_assets.py"
} else {
    Write-Host "  Visual assets found." -ForegroundColor Green
}

# 3. Check / Build Dist Executable
Write-Host "`n[3/5] Checking standalone executable ($DistExe)..." -ForegroundColor Yellow
if ($Rebuild -or -not (Test-Path $DistExe)) {
    Write-Host "  Building QRCodeGenerator.exe with PyInstaller (build.spec)..." -ForegroundColor Cyan
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

# 4. Prepare Staging Directory
Write-Host "`n[4/5] Prepping MSIX layout in $StagingDir..." -ForegroundColor Yellow
if (Test-Path $StagingDir) {
    Remove-Item $StagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $StagingDir "Assets") -Force | Out-Null

Copy-Item $ManifestPath -Destination (Join-Path $StagingDir "AppxManifest.xml")
Copy-Item "$AssetsDir\*" -Destination (Join-Path $StagingDir "Assets") -Recurse
Copy-Item $DistExe -Destination (Join-Path $StagingDir "QRCodeGenerator.exe")
Write-Host "  Staged manifest, assets, and executable." -ForegroundColor Green

# 5. Package MSIX
Write-Host "`n[5/5] Compiling MSIX package with MakeAppx..." -ForegroundColor Yellow
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

& $MakeAppx pack /d $StagingDir /p $OutputMsix /o /v
if ($LASTEXITCODE -ne 0) {
    throw "MakeAppx failed to package MSIX."
}
Write-Host "  [+] MSIX built successfully:" -ForegroundColor Green
Write-Host "      $OutputMsix" -ForegroundColor White

# Optional Local Test Signing & Validation
if ($Sign) {
    Write-Host "`n[Optional] Signing and validating MSIX package..." -ForegroundColor Yellow
    & "$ScriptDir\sign_and_validate.ps1" -MsixPath $OutputMsix -InstallCert -SkipAppTests
    if ($LASTEXITCODE -ne 0) {
        throw "MSIX signing & validation failed."
    }
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " SUCCESS! MSIX package ready for Microsoft Store upload:" -ForegroundColor Green
Write-Host " $OutputMsix" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
Write-Host 'Next steps:'
Write-Host ' 1. Update AppxManifest.xml with your Partner Center identity (Name, Publisher).'
Write-Host " 2. Upload $OutputMsix to Microsoft Partner Center."
Write-Host ' 3. See deployment/MICROSOFT_STORE_GUIDE.md for step-by-step submission instructions.'
