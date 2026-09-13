# install_msix_sideload.ps1 — One-click sideload of QRCodeGenerator.msix on ANY Windows PC
# =========================================================================
# Fixes the install error seen on machines that never trusted the dev cert:
#   "The root certificate and all immediate certificates of the signature in
#    the app package must be verified (0x800B010A)"
#
# Sideload workflow:
#   1. Self-elevates to Administrator (no manual admin shell needed)
#   2. Enables Developer Mode / sideloading (AppModelUnlock registry keys)
#   3. Imports MSIXDevCert.cer into LocalMachine TrustedPeople + TrustedRoot
#   4. Installs (or updates) QRCodeGenerator.msix
# =========================================================================

$ErrorActionPreference = "Stop"
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallerDir = Split-Path -Parent $ScriptDir
$AppName      = "LocalAiLab.QRCodeGen"

# --- Step 0: Self-elevate so a double-click is enough ----------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[*] This script needs Administrator rights - relaunching elevated..."
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -PassThru -Wait
    exit $proc.ExitCode
}

# --- Resolve package & certificate paths (supports flat zip bundle + repo) ---
$msixCandidates = @(
    (Join-Path $ScriptDir "QRCodeGenerator.msix"),
    (Join-Path $InstallerDir "output\QRCodeGenerator.msix"),
    (Join-Path $ScriptDir "output\QRCodeGenerator.msix"),
    (Join-Path $ScriptDir "..\output\QRCodeGenerator.msix")
)
$MsixPath = $msixCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $MsixPath) {
    $MsixPath = Join-Path $InstallerDir "output\QRCodeGenerator.msix"
}

$certCandidates = @(
    (Join-Path $ScriptDir "msix_certificate\MSIXDevCert.cer"),
    (Join-Path $ScriptDir "MSIXDevCert.cer"),
    (Join-Path $ScriptDir "..\signing\msix_certificate\MSIXDevCert.cer")
)
$CerPath = $certCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $CerPath) {
    $CerPath = Join-Path $ScriptDir "msix_certificate\MSIXDevCert.cer"
}

try {
    # --- Preflight checks ----------------------------------------------------
    if (-not (Test-Path -LiteralPath $MsixPath)) {
        throw "MSIX not found: $MsixPath`nMake sure QRCodeGenerator.msix is present or run deployment\msix\BUILD_MSIX.bat."
    }
    if (-not (Test-Path -LiteralPath $CerPath)) {
        throw "Certificate not found: $CerPath"
    }

    # --- Preflight: verify digital signature ---------------------------------
    try {
        $signedCert = [System.Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile($MsixPath)
        if (-not $signedCert -or -not $signedCert.Subject) {
            throw "Signature missing"
        }
        Write-Host "      [OK] MSIX is digitally signed ($($signedCert.Subject))."
    } catch {
        throw "The MSIX is NOT digitally signed (error 0x800B0100). Please sign it first before distributing."
    }

    # --- Step 1: Enable Developer Mode / sideloading ------------------------
    Write-Host "[1/4] Enabling Developer Mode / sideloading..."
    $unlockKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    New-Item -Path $unlockKey -Force | Out-Null
    Set-ItemProperty -Path $unlockKey -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $unlockKey -Name "AllowAllTrustedApps" -Value 1 -Type DWord -Force
    Write-Host "      [OK] Sideloading enabled."

    # --- Step 2: Trust the certificate --------------------------------------
    Write-Host "[2/4] Trusting the LocalAiLab certificate..."
    $cert = Import-Certificate -FilePath $CerPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" -ErrorAction Stop
    try {
        Import-Certificate -FilePath $CerPath -CertStoreLocation "Cert:\LocalMachine\Root" -ErrorAction SilentlyContinue | Out-Null
    } catch {
        $null = $_
    }
    Write-Host "      [OK] Certificate '$($cert.Subject)' trusted (TrustedPeople + Root)."

    # --- Step 3: Install (or update) the package -----------------------------
    Write-Host "[3/4] Installing QR Code Generator..."
    if (Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue) {
        Write-Host "      Package already present - updating..."
        Add-AppxPackage -Path $MsixPath -ForceUpdateFromAnyVersion -ErrorAction Stop
    } else {
        Add-AppxPackage -Path $MsixPath -ErrorAction Stop
    }

    if (-not (Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue)) {
        throw "Add-AppxPackage reported success but '$AppName' is not registered."
    }

    # --- Step 4: Done ---------------------------------------------------------
    Write-Host "[4/4] Done."
    Write-Host ""
    Write-Host "============================================================"
    Write-Host " [SUCCESS] QR Code Generator installed on this PC!"
    Write-Host " Launch from: Start Menu -> QR Code Generator"
    Write-Host "============================================================"
    if (-not $env:NONINTERACTIVE) {
        Write-Host ""
        Write-Host "Press Enter to exit..."
        [void][Console]::ReadLine()
    }
    exit 0
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check the Windows Event Log (AppXDeployment-Server/Operational) for details."
    if (-not $env:NONINTERACTIVE) {
        Write-Host ""
        Write-Host "Press Enter to exit..."
        [void][Console]::ReadLine()
    }
    exit 1
}
