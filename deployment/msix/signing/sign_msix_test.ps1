# sign_msix_test.ps1 — Sign QRCodeGenerator.msix with dev cert + install locally
# =========================================================================

$ScriptDir     = Split-Path -LiteralPath $MyInvocation.MyCommand.Path
$InstallerDir  = Split-Path -Parent $ScriptDir
$MsixPath      = Join-Path $InstallerDir "output\QRCodeGenerator.msix"
$CertDir       = Join-Path $ScriptDir "msix_certificate"
$CertPath      = Join-Path $CertDir "MSIXDevCert.pfx"
$CertPassword  = "Dara2006@"
$AppName       = "LocalAiLab.QRCodeGen"

if (-not (Test-Path -LiteralPath $MsixPath)) {
    Write-Error "MSIX not found at: $MsixPath`nRun deployment\msix\BUILD_MSIX.bat first."
    exit 1
}
if (-not (Test-Path -LiteralPath $CertPath)) {
    Write-Error "Cert not found at: $CertPath"
    exit 1
}

# Find SignTool from Windows SDK
$WindowsKits = @(
    "C:\Program Files (x86)\Windows Kits\10\bin",
    "C:\Program Files\Windows Kits\10\bin"
)
$SignTool = $null
foreach ($kit in $WindowsKits) {
    if (Test-Path $kit) {
        $found = Get-ChildItem -Path $kit -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1
        if ($found) { $SignTool = $found.FullName; break }
    }
}

if (-not $SignTool) {
    Write-Error "signtool.exe not found. Install Windows SDK."
    exit 1
}
Write-Host "[+] Found SignTool: $SignTool"

# Load cert
try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $CertPassword)
} catch {
    $SecurePass = ConvertTo-SecureString $CertPassword -AsPlainText -Force
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $SecurePass)
}
Write-Host "[+] Using cert: $($cert.Subject) (expires $($cert.NotAfter.ToShortDateString()))"

# Trust cert locally
Write-Host "[*] Installing cert into Trusted People store..."
$imported = $false
try {
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "LocalMachine")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
    $imported = $true
    Write-Host "[OK] Certificate trusted in LocalMachine\TrustedPeople."
} catch {
    try {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "CurrentUser")
        $store.Open("ReadWrite")
        $store.Add($cert)
        $store.Close()
        $imported = $true
        Write-Host "[OK] Certificate trusted in CurrentUser\TrustedPeople."
    } catch {
        Write-Warning "Could not import certificate: $($_.Exception.Message)"
    }
}

# Sign MSIX
Write-Host "[*] Signing MSIX..."
& $SignTool sign /fd SHA256 /a /f $CertPath /p $CertPassword $MsixPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "Signing failed."
    exit 1
}
Write-Host "[OK] MSIX signed successfully."

# Install
Write-Host "`n[*] Installing MSIX locally..."
try {
    Add-AppxPackage -Path $MsixPath -ErrorAction Stop
} catch {
    try {
        Add-AppxPackage -Path $MsixPath -ForceUpdateFromAnyVersion -ErrorAction Stop
    } catch {
        Write-Error "Failed to install MSIX: $($_.Exception.Message)"
        exit 1
    }
}

$pkg = Get-AppxPackage -Name $AppName
if ($pkg) {
    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host " [SUCCESS] QR Code Generator installed!" -ForegroundColor Green
    Write-Host " Launch from: Start Menu -> QR Code Generator" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
} else {
    Write-Error "Package not found after installation."
    exit 1
}
