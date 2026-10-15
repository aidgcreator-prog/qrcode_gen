# Native Windows (WinUI 3) QR Code Generator with Microsoft Store Monetization

This is the native C# / WinUI 3 (Windows App SDK) desktop client for **QR Code Generator**, built for direct **Microsoft Store** distribution and monetization.

---

## 💎 Monetization Architecture

The native application implements a **Dual-Earning Model**:

### 1. In-App Purchase (IAP) via Microsoft Store Services
- Implemented in `Services/StoreMonetizationService.cs` using `Windows.Services.Store.StoreContext`.
- **Add-on Store ID**: `pro_unlock` (Durable Product).
- When a user purchases the Pro add-on ($1.99):
  - The native Ad / Promoted banner automatically collapses (`Visibility = Collapsed`).
  - The status badge updates to `⭐ Pro Edition (No Ads)`.
  - The user's license persists across all Windows devices linked to their Microsoft Account.

### 2. Native Ad Banner Placement
- Displayed prominently at the top of `MainPage.xaml`.
- **Free Tier**: Renders the sponsored promotion card with an upgrade button (`⭐ Remove Ads ($1.99)`).
- Can be bound directly to native ad SDKs (such as Pubfinity or Microsoft In-App Advertising) without browser-container restrictions.

---

## 🛠️ Build & Development Commands

From the project root:

```powershell
# Restore dependencies (net8.0-windows + QRCoder)
dotnet restore src_native/QRCodeGeneratorNative/QRCodeGeneratorNative.csproj -r win-x64

# Build native binary
& "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" "src_native/QRCodeGeneratorNative/QRCodeGeneratorNative.csproj" /p:Platform=x64 /p:Configuration=Release

# Package for Microsoft Store (.msixupload)
& "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" "src_native/QRCodeGeneratorNative/QRCodeGeneratorNative.csproj" /p:Platform=x64 /p:Configuration=Release /p:GenerateAppxPackageOnBuild=true /p:AppxPackageDir="AppPackages"
```

---

## 📋 Microsoft Partner Center Configuration

To activate the in-app purchase in your Microsoft Store listing:
1. Go to **Partner Center** -> your app **`QRCodeGen`** (`LocalAiLab.QRCodeGen`).
2. Navigate to **Add-ons** -> **Create a new add-on**.
3. Select **Durable** product type.
4. Set the **Product ID**: `pro_unlock`.
5. Set the price (e.g. Tier 1 $0.99 or Tier 2 $1.99) and submit with your package.
