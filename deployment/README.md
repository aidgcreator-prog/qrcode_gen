# QR Code Generator — Store Deployment & Packaging

This directory contains enterprise packaging automation, manifest specifications, visual assets, certification testing, and submission guidelines for deploying **QR Code Generator** to the **Microsoft Store** and distributing test builds for sideloading.

---

## Directory Overview

```
deployment/
├── README.md                          <- This overview document
├── MICROSOFT_STORE_GUIDE.md           <- Step-by-step Partner Center submission walkthrough
├── BUILD_MSIX.bat                     <- Master shortcut: Build, sanitize, pack, sign, and bundle
├── VALIDATE_MSIX.bat                  <- Master shortcut: Hygiene check, SignTool verify, & WACK certification
├── build_all.bat                      <- Master batch runner (MSIX + Win32 installer)
├── build_all.ps1                      <- Master PowerShell runner (MSIX + Win32 installer)
├── sign_and_validate_msix.bat         <- Shortcut to deep MSIX signing & validation pipeline
├── msix/                              <- Native Windows Store App Package (.msix)
│   ├── AppxManifest.xml               <- Package identity, capabilities, and visual elements
│   ├── Assets/                        <- 40+ pre-generated Microsoft Store icons & splash screens
│   ├── generate_assets.py             <- Generator script to re-create store assets from logo_round.png
│   ├── BUILD_MSIX.bat                 <- All-in-one packaging, signing & test bundle pipeline (Tee-Object log)
│   ├── VALIDATE_MSIX.bat              <- Automated pre-scan, signature check, and WACK certification suite
│   ├── clean_msix_stage.py            <- Sanitizes staging layout (strips dotfiles, pycache, OPC forbidden chars)
│   ├── generate_msix_map.py           <- Generates MakeAppx mapping file (/f) for reproducible packaging
│   ├── scan_msix.py                   <- Pre-scans staged files for bad characters, dot-files, long paths (>200)
│   ├── run_wack.ps1                   <- Automated Windows App Certification Kit runner (self-elevating)
│   ├── parse_wack_report.py           <- Parses WACK XML report (separates Desktop Bridge info from failures)
│   ├── sign_and_validate.bat          <- Interactive & CLI batch script to sign & validate .msix
│   ├── sign_and_validate.ps1          <- 6-phase signing, Authenticode cryptography, and validation engine
│   ├── output/                        <- Output directory for .msix, test bundles, logs, and WACK reports
│   │   ├── QRCodeGenerator.msix       <- Signed MSIX package
│   │   ├── QRCodeGenerator_TestInstall.zip <- Shareable test distribution bundle
│   │   ├── _build_log.txt             <- Continuous build log
│   │   └── wack_report.xml            <- WACK certification test results
│   └── signing/                       <- Sideloading and test distribution suite
│       ├── README.md                  <- Sideloading and certificate guide
│       ├── install_msix_sideload.bat  <- One-click tester installer (self-elevating)
│       ├── install_msix_sideload.ps1  <- Enables sideloading, trusts cert in TrustedPeople, & registers MSIX
│       ├── sign_and_bundle.bat        <- Signs MSIX, verifies Authenticode, and packages test bundle zip
│       ├── sign_msix_test.ps1         <- Signs MSIX and installs locally on the build PC
│       └── msix_certificate/          <- Developer test certificate (CN=LocalAiLab)
│           ├── MSIXDevCert.cer        <- Public certificate for testers
│           └── MSIXDevCert.pfx        <- Private key for signing (password: Dara2006@)
└── win32_installer/                   <- Win32 (.exe) Installer Pathway
    ├── build_store_exe.bat            <- One-click batch launcher
    └── build_store_exe.ps1            <- Automated build script using Inno Setup for Store submission
```

---

## Workflows

### 1. All-in-One Build, Sign, and Bundle (Recommended for Development)
Runs clean PyInstaller build, sanitizes the staging tree (`clean_msix_stage.py`), generates MakeAppx mapping (`generate_msix_map.py`), compiles the `.msix`, digitally signs with `MSIXDevCert.pfx`, verifies signature, and bundles into `QRCodeGenerator_TestInstall.zip`:

```cmd
.\deployment\BUILD_MSIX.bat
# or
.\deployment\msix\BUILD_MSIX.bat
```

### 2. Validation & Windows App Certification Kit (WACK)
Validates manifest/asset hygiene (`scan_msix.py`), checks Authenticode signature (`signtool verify`), verifies package installation, runs the official Windows App Certification Kit elevated (`run_wack.ps1`), and parses results (`parse_wack_report.py`):

```cmd
.\deployment\VALIDATE_MSIX.bat
# or
.\deployment\msix\VALIDATE_MSIX.bat
```

### 3. Share Test Builds with External Testers
When sharing with testers whose machines do not have your developer certificate:
1. Run `deployment\msix\signing\sign_and_bundle.bat`.
2. Send `deployment\msix\output\QRCodeGenerator_TestInstall.zip` to the tester.
3. Tester extracts the zip and double-clicks `install_msix_sideload.bat` (which automatically enables Developer Mode / Sideloading, installs the certificate into `TrustedPeople`, and registers the app).

### 4. Interactive Signing & Validation Console
Interactive 5-option menu to test-sign, install to `TrustedPeople`, validate only, or force re-sign:

```cmd
.\deployment\sign_and_validate_msix.bat
# or
.\deployment\msix\sign_and_validate.bat
```

---

## Publishing to the Microsoft Store

When publishing to Microsoft Store:
1. Update `deployment/msix/AppxManifest.xml` with your Partner Center identity (`Name`, `Publisher`, `DisplayName`).
2. Run `.\deployment\BUILD_MSIX.bat` to generate the fresh `QRCodeGenerator.msix`.
3. Upload `deployment/msix/output/QRCodeGenerator.msix` directly to Microsoft Partner Center. (Microsoft automatically re-signs the package with a globally trusted Microsoft Store certificate upon certification).
4. See **[MICROSOFT_STORE_GUIDE.md](file:///e:/qrcode_gen/deployment/MICROSOFT_STORE_GUIDE.md)** for detailed screenshots and step-by-step submission instructions.
