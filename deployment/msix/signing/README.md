# QR Code Generator — MSIX Signing & Test Distribution Guide

This directory contains the scripts and assets for **signing** the QR Code Generator MSIX package with a developer self-signed certificate and **distributing** test builds for sideloading.

---

## Which script do I run?

| Goal | Script | Context |
|---|---|---|
| Sign MSIX **and** produce shareable test zip | `sign_and_bundle.bat` | Build PC |
| Sign MSIX **and install locally** | `sign_msix_test.ps1` | Build PC |
| Install a test build on another PC | `install_msix_sideload.bat` | Tester PC |
| Deep signature & package validation | `..\sign_and_validate.bat` | Build PC |

---

## Scripts Overview

### 1. `sign_and_bundle.bat`
- Signs `output\QRCodeGenerator.msix` using `msix_certificate\MSIXDevCert.pfx`.
- Verifies the signature with `signtool verify /pa` before bundling.
- Packages `output\QRCodeGenerator_TestInstall.zip` containing the MSIX, `MSIXDevCert.cer`, and `install_msix_sideload.bat`.

### 2. `sign_msix_test.ps1`
- Signs the MSIX package.
- Automatically trusts the certificate in `TrustedPeople` (LocalMachine or CurrentUser).
- Installs or updates the app via `Add-AppxPackage`.

### 3. `install_msix_sideload.bat` / `.ps1`
- One-click installer for testers.
- Self-elevates via UAC, enables Windows Sideloading/Developer Mode, imports `MSIXDevCert.cer`, and registers the MSIX.
- Resolves paths whether run from repo or extracted zip.

---

## Certificate Details

- **Subject**: `CN=LocalAiLab` (matches `AppxManifest.xml` Publisher)
- **Password**: `Dara2006@`
- **Location**: `msix_certificate\MSIXDevCert.pfx` (private key) and `MSIXDevCert.cer` (public key)

> **Store Publishing Note**: For Microsoft Store releases, upload the unsigned or test-signed package directly to Microsoft Partner Center. Microsoft automatically re-signs the app with a globally trusted Microsoft Store certificate.
