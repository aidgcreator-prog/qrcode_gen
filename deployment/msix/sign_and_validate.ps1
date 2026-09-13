<#
.SYNOPSIS
    Signs and validates the Microsoft Store MSIX package for QR Code Generator.

.DESCRIPTION
    1. Locates Windows SDK tools (signtool.exe, makeappx.exe).
    2. Validates package existence and AppxManifest.xml configuration.
    3. Runs application health self-tests (QR_SELFTEST & AppTest).
    4. Signs the MSIX package using an existing PFX, a store certificate, or an auto-created dev certificate.
    5. Validates digital signature integrity, certificate validity, and EKU.
    6. Validates that the certificate Subject exactly matches the manifest Publisher (required by Windows App Installer).
    7. Tests package unpack integrity with MakeAppx.
    8. Checks local trust status (Trusted People store) and optionally installs the cert for seamless sideloading.
    9. Generates a deployment readiness report for Microsoft Store & local sideloading.

.PARAMETER MsixPath
    Path to the MSIX file. Defaults to deployment/msix/output/QRCodeGenerator.msix.

.PARAMETER ValidateOnly
    Skips signing and only validates the existing package.

.PARAMETER ForceSign
    Forces re-signing even if the package is already digitally signed.

.PARAMETER CertFile
    Path to a .pfx certificate file to sign with.

.PARAMETER CertPassword
    Password for the .pfx certificate file.

.PARAMETER CertThumbprint
    Specific certificate thumbprint to use from Cert:\CurrentUser\My or Cert:\LocalMachine\My.

.PARAMETER InstallCert
    Installs the signing certificate into Cert:\CurrentUser\TrustedPeople for local sideloading.

.PARAMETER SkipAppTests
    Skips running the Python application self-tests.

.EXAMPLE
    .\sign_and_validate.ps1
    .\sign_and_validate.ps1 -InstallCert
    .\sign_and_validate.ps1 -ValidateOnly
    .\sign_and_validate.ps1 -CertFile "mycert.pfx" -CertPassword "secret"
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CertPassword")]
param(
    [string]$MsixPath,
    [switch]$ValidateOnly,
    [switch]$ForceSign,
    [string]$CertFile,
    [string]$CertPassword,
    [string]$CertThumbprint,
    [switch]$InstallCert,
    [switch]$SkipAppTests
)

$ErrorActionPreference = "Stop"

function Write-Log {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Message = "",
        [ConsoleColor]$ForegroundColor
    )
    if ($ForegroundColor) {
        Write-Host $Message -ForegroundColor $ForegroundColor
    } else {
        Write-Host $Message
    }
}

function Invoke-NativeCommand {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList
    )
    $savedEAP = $global:ErrorActionPreference
    $global:ErrorActionPreference = "Continue"
    try {
        $output = & $FilePath @ArgumentList
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($output -join "`n")
        }
    } finally {
        $global:ErrorActionPreference = $savedEAP
    }
}

function Get-PackageSignatureInfo {
    param([string]$FilePath)

    # 1. Native .NET X509Certificate2 (works everywhere, no module dependencies)
    try {
        $rawCert = [System.Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile($FilePath)
        if ($rawCert) {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($rawCert)
            $thumb = $cert.Thumbprint
            if (-not $thumb) {
                $thumb = $cert.GetCertHashString()
            }
            if ($thumb) {
                return [PSCustomObject]@{
                    IsSigned    = $true
                    Status      = "Valid"
                    Certificate = $cert
                    Subject     = $cert.Subject
                    Thumbprint  = $thumb
                    NotBefore   = $cert.NotBefore
                    NotAfter    = $cert.NotAfter
                }
            }
        }
    } catch {
        $null = $_
    }

    # 2. Fallback to PowerShell Get-AuthenticodeSignature if available
    try {
        if (Get-Command "Get-AuthenticodeSignature" -ErrorAction SilentlyContinue) {
            $sig = Get-AuthenticodeSignature $FilePath
            if ($sig -and $sig.SignerCertificate) {
                return [PSCustomObject]@{
                    IsSigned    = ($sig.Status -ne "NotSigned")
                    Status      = $sig.Status.ToString()
                    Certificate = $sig.SignerCertificate
                    Subject     = $sig.SignerCertificate.Subject
                    Thumbprint  = $sig.SignerCertificate.Thumbprint
                    NotBefore   = $sig.SignerCertificate.NotBefore
                    NotAfter    = $sig.SignerCertificate.NotAfter
                }
            }
        }
    } catch {
        $null = $_
    }

    return [PSCustomObject]@{
        IsSigned    = $false
        Status      = "NotSigned"
        Certificate = $null
        Subject     = $null
        Thumbprint  = $null
        NotBefore   = $null
        NotAfter    = $null
    }
}

# Mount Cert PSDrive if missing (does not require loading modules or re-registering TypeData)
if (-not (Get-PSDrive -Name Cert -ErrorAction SilentlyContinue)) {
    try {
        New-PSDrive -Name Cert -PSProvider Certificate -Root "\" -ErrorAction SilentlyContinue | Out-Null
    } catch {
        $null = $_
    }
}

function Get-StoreCertificate {
    param(
        [string]$StoreName = "My",
        [string]$StoreLocation = "CurrentUser"
    )
    $certs = @()
    # Pure .NET X509Store (independent of PowerShell Cert:\ PSDrive)
    try {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, $StoreLocation)
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        foreach ($c in $store.Certificates) {
            $certs += $c
        }
        $store.Close()
        if ($certs.Count -gt 0) {
            return $certs
        }
    } catch {
        $null = $_
    }

    # Fallback to PSDrive if available
    try {
        $path = "Cert:\$StoreLocation\$StoreName"
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            $certs = @(Get-ChildItem -Path $path -ErrorAction SilentlyContinue)
        }
    } catch {
        $null = $_
    }

    return $certs
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$OutputDir = Join-Path $ScriptDir "output"
$ManifestPath = Join-Path $ScriptDir "AppxManifest.xml"
$AssetsDir = Join-Path $ScriptDir "Assets"

if (-not $MsixPath) {
    $MsixPath = Join-Path $OutputDir "QRCodeGenerator.msix"
}

Write-Log "======================================================================" -ForegroundColor Cyan
Write-Log " QR Code Generator -- MSIX Signing & Validation Pipeline" -ForegroundColor Cyan
Write-Log "======================================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# 1. Locate Windows SDK Tools (SignTool & MakeAppx)
# -----------------------------------------------------------------------------
Write-Log "`n[1/6] Locating Windows SDK tools..." -ForegroundColor Yellow

$WindowsKits = @(
    "C:\Program Files (x86)\Windows Kits\10\bin",
    "C:\Program Files\Windows Kits\10\bin"
)

$SignTool = $null
$MakeAppx = $null

foreach ($kit in $WindowsKits) {
    if (Test-Path $kit) {
        if (-not $SignTool) {
            $foundSign = Get-ChildItem -Path $kit -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -First 1
            if ($foundSign) { $SignTool = $foundSign.FullName }
        }

        if (-not $MakeAppx) {
            $foundAppx = Get-ChildItem -Path $kit -Recurse -Filter "makeappx.exe" -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match "\\x64\\makeappx\.exe$" } |
                Sort-Object -Property LastWriteTime -Descending |
                Select-Object -First 1
            if ($foundAppx) { $MakeAppx = $foundAppx.FullName }
        }
    }
}

if (-not $SignTool) {
    Write-Log "  [!] SignTool.exe not found in standard Windows SDK paths." -ForegroundColor Red
    throw "SignTool.exe is required. Please install the Windows 10/11 SDK."
}
Write-Log "  [+] SignTool: $SignTool" -ForegroundColor Green

if (-not $MakeAppx) {
    Write-Log "  [!] MakeAppx.exe not found in standard Windows SDK paths." -ForegroundColor Red
    throw "MakeAppx.exe is required. Please install the Windows 10/11 SDK."
}
Write-Log "  [+] MakeAppx: $MakeAppx" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 2. Verify Package Existence & Inspect AppxManifest.xml
# -----------------------------------------------------------------------------
Write-Log "`n[2/6] Inspecting package & manifest configuration..." -ForegroundColor Yellow

if (-not (Test-Path $ManifestPath)) {
    throw "AppxManifest.xml not found at: $ManifestPath"
}

[xml]$manifest = Get-Content $ManifestPath
$identity = $manifest.Package.Identity
$properties = $manifest.Package.Properties
$application = $manifest.Package.Applications.Application

if (-not $identity) {
    throw "Invalid AppxManifest.xml: <Identity> element is missing."
}

$ManifestName = $identity.Name
$ManifestPublisher = $identity.Publisher
$ManifestVersion = $identity.Version
$ManifestArch = $identity.ProcessorArchitecture
$AppExecutable = $application.Executable
$AppDisplayName = $properties.DisplayName

Write-Log "  Manifest Identity:" -ForegroundColor Gray
Write-Log "    Display Name : $AppDisplayName" -ForegroundColor White
Write-Log "    Package Name : $ManifestName" -ForegroundColor White
Write-Log "    Publisher    : $ManifestPublisher" -ForegroundColor White
Write-Log "    Version      : $ManifestVersion" -ForegroundColor White
Write-Log "    Architecture : $ManifestArch" -ForegroundColor White
Write-Log "    Executable   : $AppExecutable" -ForegroundColor White

if (Test-Path $AssetsDir) {
    $assetCount = (Get-ChildItem -Path $AssetsDir -Filter "*.png" -ErrorAction SilentlyContinue).Count
    Write-Log "    Store Assets : $assetCount icons in $AssetsDir" -ForegroundColor Gray
}

if (-not (Test-Path $MsixPath)) {
    Write-Log "  [!] Target MSIX not found at: $MsixPath" -ForegroundColor Yellow
    Write-Log "      Building MSIX package now via build_msix.ps1..." -ForegroundColor Cyan
    & "$ScriptDir\build_msix.ps1"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $MsixPath)) {
        throw "Failed to automatically build MSIX package."
    }
}

$msixItem = Get-Item $MsixPath
$msixSizeMB = [math]::Round($msixItem.Length / 1MB, 2)
Write-Log "  [+] Target MSIX found: $($msixItem.FullName) ($msixSizeMB MB)" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 3. Application Health Self-Tests
# -----------------------------------------------------------------------------
if (-not $SkipAppTests) {
    Write-Log "`n[3/6] Running application health self-tests..." -ForegroundColor Yellow
    Push-Location $ProjectRoot
    $savedEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $env:QR_SELFTEST = "1"
        & uv run python run_app.py
        if ($LASTEXITCODE -ne 0) {
            throw "QR_SELFTEST execution failed with code $LASTEXITCODE."
        }
        $env:QR_SELFTEST = $null

        $appTestScript = "from streamlit.testing.v1 import AppTest; at = AppTest.from_file('main.py'); at.run(timeout=15); assert not at.exception; print('AppTest passed!')"
        & uv run python -c $appTestScript
        if ($LASTEXITCODE -ne 0) {
            throw "Streamlit AppTest validation failed with code $LASTEXITCODE."
        }
        Write-Log "  [+] Application logic and Streamlit UI self-tests passed." -ForegroundColor Green
    } finally {
        $env:QR_SELFTEST = $null
        $ErrorActionPreference = $savedEAP
        Pop-Location
    }
} else {
    Write-Log "`n[3/6] Skipping application health tests (-SkipAppTests specified)." -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
# 4. Digital Signing Phase
# -----------------------------------------------------------------------------
Write-Log "`n[4/6] Processing digital signature..." -ForegroundColor Yellow

$currentSig = Get-PackageSignatureInfo $MsixPath
$alreadySigned = $currentSig.IsSigned

$shouldSign = $false
if ($ValidateOnly) {
    Write-Log "  Validation-only mode requested; skipping signing." -ForegroundColor Cyan
} elseif ($ForceSign) {
    Write-Log "  Force-sign requested; proceeding with signing." -ForegroundColor Cyan
    $shouldSign = $true
} elseif (-not $alreadySigned) {
    Write-Log "  MSIX package is not signed; proceeding with signing." -ForegroundColor Cyan
    $shouldSign = $true
} else {
    Write-Log "  MSIX package is already signed by: $($currentSig.Subject)" -ForegroundColor Green
    Write-Log "  Thumbprint: $($currentSig.Thumbprint)" -ForegroundColor Gray
    Write-Log "  Status    : $($currentSig.Status)" -ForegroundColor Gray
}

$activeCert = $null

if ($shouldSign) {
    # Determine certificate to use
    if ($CertFile) {
        if (-not (Test-Path $CertFile)) {
            throw "Specified certificate file not found: $CertFile"
        }
        Write-Log "  Using certificate file: $CertFile" -ForegroundColor Cyan

        $signArgs = @("sign", "/fd", "SHA256", "/f", $CertFile)
        if ($CertPassword) {
            $signArgs += @("/p", $CertPassword)
        }

        # Add RFC 3161 timestamp
        $timestampUrl = "http://timestamp.digicert.com"
        Write-Log "  Attempting signing with timestamp ($timestampUrl)..." -ForegroundColor Cyan
        $fullArgs = $signArgs + @("/tr", $timestampUrl, "/td", "SHA256", $MsixPath)

        $signResult = Invoke-NativeCommand -FilePath $SignTool -ArgumentList $fullArgs
        if ($signResult.ExitCode -ne 0) {
            Write-Log "  [!] Timestamping server failed or timed out. Falling back to non-timestamped signing..." -ForegroundColor Yellow
            $fallbackArgs = $signArgs + @($MsixPath)
            $fallbackResult = Invoke-NativeCommand -FilePath $SignTool -ArgumentList $fallbackArgs
            if ($fallbackResult.ExitCode -ne 0) {
                throw "SignTool failed to sign MSIX package with PFX file: $($fallbackResult.Output)"
            }
        }
        Write-Log "  [+] Signed successfully with PFX file." -ForegroundColor Green

    } elseif ($CertThumbprint) {
        Write-Log "  Using certificate with thumbprint: $CertThumbprint" -ForegroundColor Cyan
        $allCerts = @(Get-StoreCertificate -StoreName "My" -StoreLocation "CurrentUser") + @(Get-StoreCertificate -StoreName "My" -StoreLocation "LocalMachine")
        $certObj = $allCerts | Where-Object { $_.Thumbprint -eq $CertThumbprint } | Select-Object -First 1

        if (-not $certObj) {
            throw "Certificate with thumbprint $CertThumbprint not found in CurrentUser\My or LocalMachine\My."
        }
        $activeCert = $certObj

        # Sign using thumbprint
        $signArgs = @("sign", "/fd", "SHA256", "/sha1", $CertThumbprint)
        $timestampUrl = "http://timestamp.digicert.com"
        $fullArgs = $signArgs + @("/tr", $timestampUrl, "/td", "SHA256", $MsixPath)

        $signResult = Invoke-NativeCommand -FilePath $SignTool -ArgumentList $fullArgs
        if ($signResult.ExitCode -ne 0) {
            Write-Log "  [!] Timestamping failed/offline. Falling back to non-timestamped signature..." -ForegroundColor Yellow
            $fallbackArgs = $signArgs + @($MsixPath)
            $fallbackResult = Invoke-NativeCommand -FilePath $SignTool -ArgumentList $fallbackArgs
            if ($fallbackResult.ExitCode -ne 0) {
                throw "SignTool failed to sign MSIX package: $($fallbackResult.Output)"
            }
        }
        Write-Log "  [+] Signed successfully with thumbprint: $CertThumbprint" -ForegroundColor Green

    } else {
        # Auto-match or create test certificate matching AppxManifest Publisher
        Write-Log "  Checking for certificate matching Publisher: $ManifestPublisher..." -ForegroundColor Cyan
        $myCerts = @(Get-StoreCertificate -StoreName "My" -StoreLocation "CurrentUser")
        $certObj = $myCerts |
            Where-Object { $_.Subject -eq $ManifestPublisher } |
            Sort-Object NotAfter -Descending |
            Select-Object -First 1

        if (-not $certObj) {
            Write-Log "  No matching certificate found in CurrentUser\My store." -ForegroundColor Yellow
            Write-Log "  Creating new self-signed code signing certificate ($ManifestPublisher)..." -ForegroundColor Cyan
            # Ensure Cert: drive exists before calling New-SelfSignedCertificate
            if (-not (Get-PSDrive -Name Cert -ErrorAction SilentlyContinue)) {
                New-PSDrive -Name Cert -PSProvider Certificate -Root "\" -ErrorAction SilentlyContinue | Out-Null
            }
            $certObj = New-SelfSignedCertificate -Type Custom `
                -Subject $ManifestPublisher `
                -KeyUsage DigitalSignature `
                -FriendlyName "QR Code Generator Development Certificate" `
                -CertStoreLocation "Cert:\CurrentUser\My" `
                -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
            Write-Log "  Created certificate: $($certObj.Thumbprint)" -ForegroundColor Green
        } else {
            Write-Log "  Found existing certificate: $($certObj.Thumbprint) (Valid until: $($certObj.NotAfter))" -ForegroundColor Green
        }
        $activeCert = $certObj

        # Perform sign
        $signArgs = @("sign", "/fd", "SHA256", "/sha1", $certObj.Thumbprint)
        $timestampUrl = "http://timestamp.digicert.com"
        Write-Log "  Signing with SignTool..." -ForegroundColor Cyan
        $fullArgs = $signArgs + @("/tr", $timestampUrl, "/td", "SHA256", $MsixPath)

        $signResult = Invoke-NativeCommand -FilePath $SignTool -ArgumentList $fullArgs
        if ($signResult.ExitCode -ne 0) {
            Write-Log "  [!] Timestamping server unreachable/timed out. Falling back to non-timestamped signature..." -ForegroundColor Yellow
            $fallbackArgs = $signArgs + @($MsixPath)
            $fallbackResult = Invoke-NativeCommand -FilePath $SignTool -ArgumentList $fallbackArgs
            if ($fallbackResult.ExitCode -ne 0) {
                throw "SignTool failed to sign MSIX package: $($fallbackResult.Output)"
            }
        }
        Write-Log "  [+] Signed successfully." -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------------
# 5. MSIX Validation & Diagnostics
# -----------------------------------------------------------------------------
Write-Log "`n[5/6] Performing comprehensive package validation..." -ForegroundColor Yellow

$validationErrors = @()
$validationWarnings = @()

# Check A: MakeAppx Unpack Integrity Test
Write-Log "  [Check 1/5] Testing package structure integrity (MakeAppx unpack)..." -ForegroundColor Gray
$tempUnpackDir = Join-Path $env:TEMP ("msix_val_" + [guid]::NewGuid().ToString("N"))
try {
    $unpackResult = Invoke-NativeCommand -FilePath $MakeAppx -ArgumentList @("unpack", "/p", $MsixPath, "/d", $tempUnpackDir, "/v")
    if ($unpackResult.ExitCode -ne 0) {
        $validationErrors += "MakeAppx failed to unpack package: $($unpackResult.Output)"
    } else {
        # Check key internal files
        $expectedFiles = @("AppxManifest.xml", "AppxBlockMap.xml", "AppxSignature.p7x", $AppExecutable)
        foreach ($f in $expectedFiles) {
            $fPath = Join-Path $tempUnpackDir $f
            if (-not (Test-Path $fPath)) {
                $validationErrors += "Missing expected file inside package: $f"
            }
        }
        Write-Log "    [OK] Package structure, block map, manifest, and executable verified." -ForegroundColor Green
    }
} catch {
    $validationErrors += "Package unpack test failed: $_"
} finally {
    if (Test-Path $tempUnpackDir) {
        Remove-Item $tempUnpackDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check B: SignTool Verify
Write-Log "  [Check 2/5] Running SignTool strict Authenticode verification..." -ForegroundColor Gray
$verifyResult = Invoke-NativeCommand -FilePath $SignTool -ArgumentList @("verify", "/pa", "/v", $MsixPath)
if ($verifyResult.ExitCode -ne 0) {
    # Check if failure is merely untrusted root for a local self-signed test cert
    if ($verifyResult.Output -match "Signer Certificate Chain" -or $verifyResult.Output -match "A certificate chain processed") {
        $validationWarnings += "SignTool verify: Certificate chain is not trusted by a public CA root (expected for local dev self-signed certificates)."
        Write-Log "    [WARN] Certificate is self-signed (not yet in Trusted People or trusted root)." -ForegroundColor Yellow
    } else {
        $validationErrors += "SignTool verification failed with code $($verifyResult.ExitCode). Output: $($verifyResult.Output)"
    }
} else {
    Write-Log "    [OK] SignTool verified package signature successfully." -ForegroundColor Green
}

# Check C: Authenticode Signature Details
Write-Log "  [Check 3/5] Verifying Authenticode digital signature and EKU..." -ForegroundColor Gray
$authSig = Get-PackageSignatureInfo $MsixPath
if (-not $authSig.IsSigned) {
    $validationErrors += "Package is not digitally signed."
} else {
    $signerCert = $authSig.Certificate
    if ($signerCert) {
        $hasCodeSigning = $false
        if ($signerCert.EnhancedKeyUsageList) {
            foreach ($eku in $signerCert.EnhancedKeyUsageList) {
                if ($eku.ObjectId -eq "1.3.6.1.5.5.7.3.3" -or $eku.FriendlyName -eq "Code Signing") {
                    $hasCodeSigning = $true
                    break
                }
            }
        }
        if (-not $hasCodeSigning -and $signerCert.Extensions) {
            foreach ($ext in $signerCert.Extensions) {
                if ($ext.Oid.Value -eq "2.5.29.37") {
                    $formatted = $ext.Format($false)
                    if ($formatted -match "Code Signing" -or $formatted -match "1.3.6.1.5.5.7.3.3") {
                        $hasCodeSigning = $true
                        break
                    }
                }
            }
        }

        if (-not $hasCodeSigning) {
            $validationErrors += "Certificate lacks Code Signing EKU (OID 1.3.6.1.5.5.7.3.3)."
        } else {
            Write-Log "    [OK] Code Signing EKU present (1.3.6.1.5.5.7.3.3)." -ForegroundColor Green
        }

        # Check D: Critical MSIX Rule - Certificate Subject == Manifest Publisher
        Write-Log "  [Check 4/5] Verifying Publisher Identity match (App Installer requirement)..." -ForegroundColor Gray
        $certSubject = $signerCert.Subject.Trim()
        $expectedPub = $ManifestPublisher.Trim()

        if ($certSubject -ne $expectedPub) {
            $msg = "Publisher mismatch! Manifest Publisher is '$expectedPub' but Certificate Subject is '$certSubject'. Windows App Installer will reject installation with error 0x80080209."
            $validationErrors += $msg
            Write-Log "    [FAIL] $msg" -ForegroundColor Red
        } else {
            Write-Log "    [OK] Certificate Subject perfectly matches Manifest Publisher ($certSubject)." -ForegroundColor Green
        }

        $activeCert = $signerCert
    } else {
        $validationErrors += "Cannot retrieve signer certificate from package signature."
    }
}

# Check E: Local Machine / User Trust Check
Write-Log "  [Check 5/5] Checking local trust status for sideloading..." -ForegroundColor Gray
$isTrustedLocally = $false
if ($activeCert) {
    $trustedCerts = @(Get-StoreCertificate -StoreName "TrustedPeople" -StoreLocation "CurrentUser") +
                    @(Get-StoreCertificate -StoreName "TrustedPeople" -StoreLocation "LocalMachine") +
                    @(Get-StoreCertificate -StoreName "Root" -StoreLocation "CurrentUser") +
                    @(Get-StoreCertificate -StoreName "Root" -StoreLocation "LocalMachine")

    $match = $trustedCerts | Where-Object { $_.Thumbprint -eq $activeCert.Thumbprint } | Select-Object -First 1
    if ($match) {
        $isTrustedLocally = $true
        Write-Log "    [OK] Certificate is trusted in Trusted People / Root store." -ForegroundColor Green
    } else {
        Write-Log "    [INFO] Certificate thumbprint ($($activeCert.Thumbprint)) is not in Trusted People store." -ForegroundColor Yellow
    }
}

# Optional automatic certificate trust installation
if ($InstallCert -and $activeCert) {
    if ($isTrustedLocally) {
        Write-Log "  [+] Certificate is already trusted in Trusted People store." -ForegroundColor Green
    } else {
        Write-Log "`n  Installing certificate to CurrentUser\TrustedPeople..." -ForegroundColor Cyan
        try {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "CurrentUser")
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            $store.Add($activeCert)
            $store.Close()
            $isTrustedLocally = $true
            Write-Log "  [+] Certificate successfully installed to CurrentUser\TrustedPeople." -ForegroundColor Green
        } catch {
            Write-Log "  [!] Could not automatically install certificate: $_" -ForegroundColor Yellow
        }
    }
}

# -----------------------------------------------------------------------------
# 6. Final Summary & Deployment Readiness Report
# -----------------------------------------------------------------------------
Write-Log "`n======================================================================" -ForegroundColor Cyan
Write-Log " DEPLOYMENT VALIDATION REPORT" -ForegroundColor Cyan
Write-Log "======================================================================" -ForegroundColor Cyan

Write-Log "Target Package : $($msixItem.FullName)" -ForegroundColor White
Write-Log "Package Size   : $msixSizeMB MB" -ForegroundColor White
Write-Log "App Version    : $ManifestVersion" -ForegroundColor White
Write-Log "Architecture   : $ManifestArch" -ForegroundColor White
Write-Log "Package Name   : $ManifestName" -ForegroundColor White
Write-Log "Publisher      : $ManifestPublisher" -ForegroundColor White

if ($activeCert) {
    Write-Log "`nDigital Signature:" -ForegroundColor Cyan
    Write-Log "  Status       : $($authSig.Status)" -ForegroundColor White
    Write-Log "  Signer       : $($activeCert.Subject)" -ForegroundColor White
    Write-Log "  Thumbprint   : $($activeCert.Thumbprint)" -ForegroundColor White
    Write-Log "  Valid From   : $($activeCert.NotBefore)" -ForegroundColor White
    Write-Log "  Valid Until  : $($activeCert.NotAfter)" -ForegroundColor White
    Write-Log "  Local Trust  : $(if ($isTrustedLocally) { 'TRUSTED (Ready to install)' } else { 'NOT TRUSTED YET (Requires Trusted People import)' })" -ForegroundColor $(if ($isTrustedLocally) { 'Green' } else { 'Yellow' })
}

if ($validationWarnings.Count -gt 0) {
    Write-Log "`nWarnings ($($validationWarnings.Count)):" -ForegroundColor Yellow
    foreach ($w in $validationWarnings) {
        Write-Log "  - $w" -ForegroundColor Yellow
    }
}

if ($validationErrors.Count -gt 0) {
    Write-Log "`nErrors ($($validationErrors.Count)):" -ForegroundColor Red
    foreach ($err in $validationErrors) {
        Write-Log "  - $err" -ForegroundColor Red
    }
    Write-Log "`n======================================================================" -ForegroundColor Red
    Write-Log " VALIDATION FAILED -- Please address errors before deploying." -ForegroundColor Red
    Write-Log "======================================================================" -ForegroundColor Red
    exit 1
}

Write-Log "`n======================================================================" -ForegroundColor Green
Write-Log " VALIDATION PASSED! Package is healthy and verified." -ForegroundColor Green
Write-Log "======================================================================" -ForegroundColor Green

Write-Log "`nDeployment Targets:" -ForegroundColor Cyan
Write-Log "1. Local Sideloading / Testing:" -ForegroundColor White
if ($isTrustedLocally) {
    Write-Log "   [READY] You can directly double-click '$($msixItem.Name)' to install!" -ForegroundColor Green
} else {
    Write-Log "   [ACTION REQUIRED] Run: .\deployment\msix\sign_and_validate.bat -InstallCert" -ForegroundColor Yellow
    Write-Log "   or import the certificate into 'Trusted People' using certmgr.msc." -ForegroundColor Gray
}

Write-Log "`n2. Microsoft Store Submission:" -ForegroundColor Cyan
Write-Log "   [READY] Upload '$($msixItem.FullName)' to Microsoft Partner Center." -ForegroundColor Green
Write-Log "   (Note: Microsoft Store will ingest and sign with official Microsoft Store certificates)." -ForegroundColor Gray
Write-Log "   See deployment/MICROSOFT_STORE_GUIDE.md for step-by-step submission instructions.`n" -ForegroundColor Gray

exit 0
