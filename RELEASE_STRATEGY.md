# Git Push Strategy & Release Workflow

This document outlines the version control, branching, and release publishing strategy for **QR Code Generator** (`aidgcreator-prog/qrcode_gen`).

---

## 1. Branching & Push Strategy

```
[Local Changes] ──(test via run.bat)──> [Commit] ──(build via build.bat)──> [Push to main] ──(Tag & Release)
```

- **Main Branch (`main`)**: The production-ready codebase.
- **Commit Style**: Use conventional commit messages:
  - `feat: ...` for new features
  - `fix: ...` for bug fixes
  - `chore: ...` for maintenance or config updates
  - `release: vX.Y.Z` for version releases

### Pushing to GitHub:
```powershell
# Set default branch to main and push
git branch -M main
git push -u origin main
```

---

## 2. Release Preparation Checklist

Before creating a new release, follow these 3 steps:

### Step 1: Synchronize Version Numbers
Ensure the version matches across both configuration files:
1. **`run_app.py`**:
   ```python
   APP_VERSION = "0.5.1"
   ```
2. **`installer.iss`**:
   ```pascal
   #define MyAppVersion "0.5.1"
   ```

### Step 2: Build the Release Binaries
Run the one-click build script:
```powershell
.\build.bat
```
This runs the validation self-test and produces:
- Portable executable: `dist\QRCodeGenerator.exe`
- Windows installer: `installer\Output\QR-Code-Generator-Setup-0.5.1.exe`

### Step 3: Commit and Push
```powershell
git add run_app.py installer.iss
git commit -m "release: v0.5.1"
git push origin main
```

---

## 3. Publishing the Release on GitHub

### Option A: Using the GitHub Web Interface (Recommended)
1. Go to: [https://github.com/aidgcreator-prog/qrcode_gen/releases/new](https://github.com/aidgcreator-prog/qrcode_gen/releases/new)
2. Click **Choose a tag**, type `v0.5.1`, and select **Create new tag: v0.5.1**.
3. Set **Release title**: `v0.5.1 — QR Code Generator`
4. In the release notes description, paste the contents of `RELEASE_NOTES.md`.
5. Drag and drop the binary files into the **Attach binaries** section:
   - `installer\Output\QR-Code-Generator-Setup-0.5.1.exe` *(Windows Installer - Recommended)*
   - `dist\QRCodeGenerator.exe` *(Portable Standalone)*
6. Click **Publish release**.

---

### Option B: Using GitHub CLI (`gh`)
```powershell
# 1. Authenticate once
gh auth login

# 2. Create the Git tag and push it
git tag -a v0.5.1 -m "Release v0.5.1"
git push origin v0.5.1

# 3. Create the GitHub release with attached binaries
gh release create v0.5.1 "installer\Output\QR-Code-Generator-Setup-0.5.1.exe" "dist\QRCodeGenerator.exe" --title "v0.5.1 — QR Code Generator" --notes "Release v0.5.1: Automatic saving to outputs, Windows tray launcher, top-bar tutorials, and blank initial input."
```

---

## 4. How the Auto-Update System Works

`run_app.py` is configured with:
```python
GITHUB_REPO = "aidgcreator-prog/qrcode_gen"
```

- When users have the app running in the Windows system tray, the app periodically queries the GitHub Releases API (`https://api.github.com/repos/aidgcreator-prog/qrcode_gen/releases/latest`).
- When you publish a newer release (e.g. `v0.5.2`), the system tray menu automatically displays:
  ```
  ⬇ Update available: v0.5.2 — open release
  ```
- Clicking it opens your GitHub release download page in the user's default browser.
