# run_wack.ps1 — Automated Windows App Certification Kit runner with UAC self-elevation
param(
    [string]$AppCertPath,
    [string]$PackageFullName,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"

if (-not $AppCertPath) {
    $candidates = @(
        "C:\Program Files (x86)\Windows Kits\10\App Certification Kit\appcert.exe",
        "C:\Program Files\Windows Kits\10\App Certification Kit\appcert.exe"
    )
    $AppCertPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $AppCertPath -or -not (Test-Path -LiteralPath $AppCertPath)) {
    Write-Error "appcert.exe not found. Please install Windows App Certification Kit from Windows SDK."
    exit 1
}

if (-not $PackageFullName) {
    $pkg = Get-AppxPackage -Name "LocalAiLab.QRCodeGen" -ErrorAction SilentlyContinue
    if ($pkg) {
        $PackageFullName = $pkg.PackageFullName
    } else {
        Write-Error "Package LocalAiLab.QRCodeGen is not installed. Please install or test-sideload the package first."
        exit 1
    }
}

if (-not $ReportPath) {
    $ScriptDir = Split-Path -LiteralPath $MyInvocation.MyCommand.Path
    $ReportPath = Join-Path $ScriptDir "output\wack_report.xml"
}

# Ensure output directory exists
$reportDir = Split-Path -Parent $ReportPath
if ($reportDir -and -not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
if (Test-Path -LiteralPath $ReportPath) {
    Remove-Item -LiteralPath $ReportPath -Force
}

# Check administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[*] WACK requires Administrator rights. Relaunching elevated..." -ForegroundColor Cyan
    $argsList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -AppCertPath `"$AppCertPath`" -PackageFullName `"$PackageFullName`" -ReportPath `"$ReportPath`""
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argsList -Verb RunAs -PassThru -Wait
    exit $proc.ExitCode
}

Write-Host "[+] Running WACK on: $PackageFullName" -ForegroundColor Green
Write-Host "[+] Report path   : $ReportPath" -ForegroundColor Green
Write-Host "[*] Executing tests (this may take 2-4 minutes)..." -ForegroundColor Yellow

$logFile = Join-Path $env:TEMP "wack_execution.log"
try {
    # For MSIX / Appx packages, appcert test accepts -packagefullname directly
    & $AppCertPath test -packagefullname $PackageFullName -reportoutputpath $ReportPath *>&1 | Tee-Object -FilePath $logFile
} catch {
    Write-Warning "Direct execution exception: $($_.Exception.Message)"
}

$exitCode = $LASTEXITCODE

if (Test-Path -LiteralPath $ReportPath) {
    Write-Host "[SUCCESS] WACK report generated at: $ReportPath" -ForegroundColor Green
    exit 0
} else {
    Write-Warning "WACK report was not created. Review log below or at: $logFile"
    if (Test-Path -LiteralPath $logFile) {
        Get-Content -LiteralPath $logFile -ErrorAction SilentlyContinue | Select-Object -Last 30 | Write-Host
    }
    if ($exitCode -ne 0) {
        exit $exitCode
    } else {
        exit 1
    }
}
