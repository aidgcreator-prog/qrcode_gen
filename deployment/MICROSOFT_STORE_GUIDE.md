# Microsoft Store Deployment & Submission Master Guide

This guide provides a comprehensive, end-to-end reference for publishing **QRCodeGen** to the **Microsoft Store** via Microsoft Partner Center. It documents the entire deployment architecture, technical gotchas and solutions, and field-by-field instructions for completing Partner Center submission forms.

---

## Table of Contents
1. [Submission Identity & Credentials](#1-submission-identity--credentials)
2. [Deployment Toolchain Architecture](#2-deployment-toolchain-architecture)
3. [Building the MSIX Package](#3-building-the-msix-package)
4. [Step-by-Step Partner Center Submission](#4-step-by-step-partner-center-submission)
   - [4.1 Packages Page](#41-packages-page)
   - [4.2 Properties Page](#42-properties-page)
   - [4.3 Submission Options Page](#43-submission-options-page)
   - [4.4 Store Listing — English (United States) Page](#44-store-listing--english-united-states-page)
5. [Local Testing & Sideloading](#5-local-testing--sideloading)
6. [Technical Gotchas & Solutions Log](#6-technical-gotchas--solutions-log)

---

## 1. Submission Identity & Credentials

The Microsoft Store requires that `deployment/msix/AppxManifest.xml` strictly match the identity assigned to your reserved product name in Microsoft Partner Center:

| Identity Field | Production Value | Manifest XML Element |
|---|---|---|
| **Package Identity Name** | `LocalAiLab.QRCodeGen` | `<Identity Name="LocalAiLab.QRCodeGen" ... />` |
| **Publisher** | `CN=6990C152-BACA-44D8-B56F-C0E2D8E49CBD` | `<Identity Publisher="CN=6990C152-BACA-44D8-B56F-C0E2D8E49CBD" ... />` |
| **Package Family Name** | `LocalAiLab.QRCodeGen_dc13tc4h2s0ba` | *(Automatically computed by Windows from Name + Publisher)* |
| **Display Name** | `QRCodeGen` | `<DisplayName>QRCodeGen</DisplayName>` and `<uap:VisualElements DisplayName="QRCodeGen" ...>` |
| **Publisher Display Name** | `LocalAiLab` | `<PublisherDisplayName>LocalAiLab</PublisherDisplayName>` |
| **Version** | `0.5.1.0` | `<Identity Version="0.5.1.0" ... />` |
| **Architecture** | `x64` | `<Identity ProcessorArchitecture="x64" />` |

---

## 2. Deployment Toolchain Architecture

Adapted from production MSIX pipelines, the deployment directory structure provides complete build automation, sanitization, certification testing, and distribution tools:

```
deployment/
├── BUILD_MSIX.bat                     <- Master one-click builder with auto-logging & timestamping
├── VALIDATE_MSIX.bat                  <- Master pre-scan, signature verify & WACK runner
├── STORE_LISTING_METADATA.md          <- Copy-paste submission data reference
├── MICROSOFT_STORE_GUIDE.md           <- This master guide
├── screenshots/                       <- High-resolution 1920x1080 Store screenshots
│   ├── Screenshot_1_Main_QR_Code.png
│   └── Screenshot_2_Customization_and_SVG.png
├── msix/
│   ├── AppxManifest.xml               <- Verified package manifest
│   ├── Assets/                        <- 40+ generated Store scale icons & splash screens
│   ├── generate_assets.py             <- Generates all standard asset sizes from image/logo_round.png
│   ├── clean_msix_stage.py            <- Sanitizes staging tree (strips dotfiles, pycache, OPC forbidden chars)
│   ├── generate_msix_map.py           <- Generates MakeAppx mapping file (/f) for reproducible packaging
│   ├── scan_msix.py                   <- Pre-scans staged files for bad characters, dot-files, and long paths
│   ├── run_wack.ps1                   <- Self-elevating automated Windows App Certification Kit runner
│   ├── parse_wack_report.py           <- XML parser distinguishing Desktop Bridge info from mandatory fails
│   ├── BUILD_MSIX.bat                 <- All-in-one packaging engine
│   ├── VALIDATE_MSIX.bat              <- Validation console
│   ├── output/                        <- Compiled outputs, test bundles, and logs
│   │   ├── QRCodeGenerator.msix       <- Latest signed MSIX
│   │   ├── QRCodeGenerator_[timestamp].msix <- Timestamped MSIX for Partner Center upload
│   │   ├── QRCodeGenerator_TestInstall_[timestamp].zip <- Shareable test bundle
│   │   ├── _build_log.txt             <- Continuous build log (Tee-Object)
│   │   └── wack_report.xml            <- Certification Kit report
│   └── signing/                       <- Test certificate & sideload distribution suite
│       ├── install_msix_sideload.bat  <- One-click tester installer (self-elevating)
│       ├── install_msix_sideload.ps1  <- Sideload engine (enables Developer Mode, trusts cert, registers app)
│       ├── sign_and_bundle.bat        <- Signs MSIX, verifies Authenticode, and packages test bundle zip
│       ├── sign_msix_test.ps1         <- Direct test-signing on build machine
│       └── msix_certificate/
│           ├── MSIXDevCert.cer        <- Public certificate for testers
│           └── MSIXDevCert.pfx        <- Developer private signing key
```

---

## 3. Building the MSIX Package

Run the master builder from CMD or PowerShell:

```cmd
.\deployment\BUILD_MSIX.bat
```

### Build Pipeline Steps:
1. **Auto-Logging**: Uses PowerShell `Tee-Object` to show output live on the console while recording to `output/_build_log.txt` and a timestamped log.
2. **SDK Discovery**: Locates `makeappx.exe` and `signtool.exe` in Windows SDK directories.
3. **Visual Assets**: Ensures all 40+ scale variants exist in `deployment/msix/Assets/`.
4. **Standalone Binary**: Verifies `dist/QRCodeGenerator.exe` (or builds it via `uv run pyinstaller --noconfirm build.spec`).
5. **Clean Staging**: Stages files into `deployment/msix/staging` and runs `clean_msix_stage.py` to strip OPC forbidden characters (`[]#%+<>:"|?*`), dotfiles, and bytecode caches.
6. **Package Compilation**: Generates mapping via `generate_msix_map.py` and compiles using `makeappx.exe pack /o /f ... /p ... /nv`.
7. **Authenticode Signing**: Signs with `signtool.exe` and `MSIXDevCert.pfx`, then verifies signature integrity via native .NET cryptography.
8. **Artifact Generation**: Outputs both the timestamped and latest files:
   - `deployment/msix/output/QRCodeGenerator_[timestamp].msix`
   - `deployment/msix/output/QRCodeGenerator_TestInstall_[timestamp].zip`

---

## 4. Step-by-Step Partner Center Submission

Navigate to [Microsoft Partner Center](https://partner.microsoft.com/dashboard) ➔ **Apps and games** ➔ **QRCodeGen**.

---

### 4.1 Packages Page

1. Drag and drop the timestamped package:
   👉 **`E:\qrcode_gen\deployment\msix\output\QRCodeGenerator_20260912_141443.msix`**
   *(or the latest `E:\qrcode_gen\deployment\msix\output\QRCodeGenerator.msix`)*
2. Partner Center will inspect the package and validate:
   - Name: `LocalAiLab.QRCodeGen`
   - Version: `0.5.1.0`
   - Architecture: `x64`
   - Capability: `runFullTrust`
3. Click **Save**.

> [!NOTE]
> Do NOT upload `.zip`, `.cer`, `.pfx`, or batch scripts. Partner Center only accepts the `.msix` binary. Microsoft automatically re-signs the package with a globally trusted Microsoft Store certificate upon certification.

---

### 4.2 Properties Page

| Form Field | Selection / Value to Enter |
|---|---|
| **Category** | `Utilities + tools` |
| **Subcategory** | `File managers` *(or `Backup + manage`)* |
| **Secondary Category** | `Developer tools` *(or `Productivity`)* |
| **Personal Information Question** | Select: **No, my product doesn't use any personal information** |
| **Privacy Policy URL** | `https://github.com/aidgcreator-prog/qrcode_gen/blob/main/README.md#privacy` |
| **Support Contact Info / Website** | `https://github.com/aidgcreator-prog/qrcode_gen/issues` |
| **Display Mode (Mixed Reality)** | Leave unchecked / default (standard 2D desktop app) |
| **Product Declarations** | Leave all checkboxes unchecked |
| **System Requirements — Keyboard** | ☑ Minimum & ☑ Recommended |
| **System Requirements — Mouse** | ☑ Minimum & ☑ Recommended |
| **System Requirements — Memory** | Minimum `1 GB`, Recommended `2 GB` |
| **Other Hardware (Touch, Camera, etc.)** | Unchecked / Not specified |

#### Privacy Policy Text (if text box selected):
```text
QRCodeGen Privacy Policy

QRCodeGen is a 100% offline desktop application.
1. No Personal Data Collection: QRCodeGen does not collect, store, track, or share any personal information, telemetry, usage statistics, or device identifiers.
2. Offline Operation: All QR code generation and image processing (PNG, JPEG, SVG) takes place entirely locally on your Windows PC.
3. No Network Transmission: The application does not transmit any user inputs, created QR codes, or network requests to external servers or third parties.
4. File Storage: Generated QR code images are saved exclusively to the local folder selected by the user on their own device.

For questions or support, visit: https://github.com/aidgcreator-prog/qrcode_gen/issues
```

---

### 4.3 Submission Options Page

#### Publishing Hold Options:
Select: **Publish this submission as soon as it passes certification**

#### Restricted Capabilities (`runFullTrust`):
> *Why do you need the runFullTrust capability, and how will it be used in your product?*

Copy and paste this exact 254-character explanation:
```text
QRCodeGen is a desktop app packaged via Desktop Bridge. The runFullTrust capability is required to run the local application process, integrate with the Windows system tray icon, and save generated QR code images (PNG, JPEG, SVG) to the user's local disk.
```

#### Notes for Certification:
```text
QRCodeGen is a desktop offline QR code generator utility.
- No login or credentials are required.
- Launching the app opens the local desktop interface in the default browser and places an icon in the Windows system tray.
- Testers can enter any text or URL in the input field to generate a QR code and test downloading in PNG, JPEG, or SVG format.
- The app operates 100% offline and requires no internet connection.
```

---

### 4.4 Store Listing — English (United States) Page

#### Product Name:
Select: **`QRCodeGen`**

#### Description:
```markdown
QRCodeGen is a fast, lightweight, and fully offline desktop utility designed for creating customizable QR codes in seconds.

Whether you need quick web links, contact cards, Wi-Fi credentials, or vector graphics for print materials, QRCodeGen delivers crisp, high-resolution results with zero bloat.

KEY FEATURES:
• Multi-Format Export: Save your QR codes in PNG, JPEG, or scalable SVG vector format for print and web.
• Flexible Customization: Customize fill colors, background colors, module box sizing, and border padding.
• Error Correction Control: Choose from Low (7%), Medium (15%), Quartile (25%), or High (30%) error correction to guarantee readability even if partially obscured or printed with logos.
• 100% Offline & Private: Generation is performed entirely locally on your PC. No data is ever sent to third-party servers.
• Windows Tray Integration: Lives quietly in your Windows system tray for instant one-click access whenever you need it.
• Auto-Save & Manual Save: Automatically saves your exports to your local Pictures/QR Codes folder, with customizable filenames.
```

#### What's New in this Version:
```text
Initial release: offline QR code generation with custom colors, sizing, error correction, SVG/PNG/JPEG export, and Windows system tray integration.
```

#### Product Features (Click "Add more"):
1. `Multi-format export: PNG, JPEG, and scalable SVG vector graphics`
2. `100% offline generation with zero network transmission`
3. `Custom foreground and background color pickers`
4. `Adjustable module box sizing and border padding`
5. `Configurable error correction levels (L, M, Q, H)`
6. `Windows system tray background integration`

#### Screenshots (At least 1 required, 1920x1080 PNG):
Upload both images located at:
- `E:\qrcode_gen\deployment\screenshots\Screenshot_1_Main_QR_Code.png`
- `E:\qrcode_gen\deployment\screenshots\Screenshot_2_Customization_and_SVG.png`

#### Store Logos & Store Display Images:
Leave blank. The Store automatically pulls the required icons from the MSIX package.

#### Supplemental Fields:
- **Short title**: `QRCodeGen`
- **Short description** *(202 characters)*:
  ```text
  Fast, lightweight, and customizable offline QR code generator. Export crisp PNG, JPEG, and SVG vector images with custom colors, sizing, error correction, and Windows system tray integration.
  ```

#### Additional Information:
- **Keywords** *(enter individually)*:
  `qr code`, `qr code generator`, `offline qr`, `svg qr code`, `vector qr`, `qr maker`
- **Copyright and trademark info**: `Copyright © 2026 LocalAiLab`
- **Developed by**: `LocalAiLab`

---

## 5. Local Testing & Sideloading

Before submitting or when sharing test builds with external testers:

### Sideloading on Any Windows PC:
1. Copy `E:\qrcode_gen\deployment\msix\output\QRCodeGenerator_TestInstall_[timestamp].zip`.
2. Extract the zip on the target PC.
3. Double-click `install_msix_sideload.bat`.
4. Click **Yes** on the UAC prompt.
   The script automatically:
   - Enables Windows Developer Mode / Sideloading via registry (`HKLM:\...\AppModelUnlock`).
   - Imports `MSIXDevCert.cer` into `Cert:\LocalMachine\TrustedPeople`.
   - Validates the Authenticode signature to prevent error `0x800B0100`.
   - Installs or updates the app using `Add-AppxPackage`.

### Windows App Certification Kit (WACK) Validation:
Run the automated WACK test suite locally:
```cmd
.\deployment\VALIDATE_MSIX.bat
```
- Performs pre-packaging filename scan (`scan_msix.py`).
- Verifies Authenticode digital signature.
- Elevates and runs `appcert.exe test -packagefullname LocalAiLab.QRCodeGen...`.
- Summarizes `wack_report.xml` with `parse_wack_report.py`.
- **Result**: `0 Mandatory Failed` (PASSED STORE COMPLIANCE).

---

## 6. Technical Gotchas & Solutions Log

During development and testing, several critical Windows packaging and SDK behaviors were resolved:

### 1. CMD Batch Parenthesis Bug (`... was unexpected at this time`)
- **Problem**: Unescaped parentheses inside `if (...)` or `for (...)` blocks (such as `echo [Step 3/7] ... (build.spec)...`) prematurely close the block in `cmd.exe`, causing syntax crashes.
- **Solution**: Replaced parentheses with brackets (`[...]`) or escaped them as `^(...^)`.

### 2. PowerShell Security Module Conflict (`CouldNotAutoloadMatchingModule`)
- **Problem**: Calling `Get-AuthenticodeSignature` in Windows batch scripts or host sessions triggers PowerShell's module autoload for `Microsoft.PowerShell.Security`. In sessions where security types are already initialized, this throws:
  `FormatXmlUpdateException: The member AuditToString is already present`.
- **Solution**: Replaced `Get-AuthenticodeSignature` with pure .NET runtime calls that do not load the PowerShell Security module:
  ```powershell
  [System.Security.Cryptography.X509Certificates.X509Certificate]::CreateFromSignedFile($MsixPath).Subject
  ```

### 3. Publisher Identity Strict Matching
- **Problem**: SignTool enforces that the Certificate Subject must strictly equal the manifest `<Identity Publisher="...">`. A self-signed cert with `CN=LocalAiLab` signing a manifest with `Publisher="CN=6990C152-BACA-44D8-B56F-C0E2D8E49CBD"` causes SignTool error `0x80080209` (Publisher mismatch).
- **Solution**: Generated and deployed a matching certificate in `deployment/msix/signing/msix_certificate/` with Subject `CN=6990C152-BACA-44D8-B56F-C0E2D8E49CBD`.

### 4. Partner Center Reserved Display Name Enforcement
- **Problem**: Partner Center rejected `QR Code Generator` with error: `Package/Properties/DisplayName uses a display name that you have not reserved`.
- **Solution**: Updated `AppxManifest.xml` `<DisplayName>` and `<uap:VisualElements DisplayName="...">` to match the exact reserved name: `QRCodeGen`.
