using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using QRCodeGeneratorNative.Services;
using QRCoder;
using Windows.Storage;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace QRCodeGeneratorNative;

public sealed partial class MainPage : Page
{
    private QrGenerationResult? _currentResult;

    public MainPage()
    {
        this.InitializeComponent();
        this.Loaded += MainPage_Loaded;
    }

    private async void MainPage_Loaded(object sender, RoutedEventArgs e)
    {
        // Subscribe to license updates
        StoreMonetizationService.Instance.LicenseStatusChanged += OnLicenseStatusChanged;
        await StoreMonetizationService.Instance.InitializeAndCheckLicenseAsync();

        // Initial default QR
        TxtInput.Text = "https://github.com/aidgcreator-prog/qrcode_gen";
        RegenerateQr();
    }

    private void OnLicenseStatusChanged(object? sender, bool isPro)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            if (isPro)
            {
                // Suppress Ads
                AdBannerContainer.Visibility = Visibility.Collapsed;
                TxtTierBadge.Text = "⭐ Pro Edition (No Ads)";
                TxtStatus.Text = "Pro Edition active. Thank you for your support!";
            }
            else
            {
                AdBannerContainer.Visibility = Visibility.Visible;
                TxtTierBadge.Text = "Standard (Ad-supported)";
            }
        });
    }

    private async void BtnUpgradePro_Click(object sender, RoutedEventArgs e)
    {
        TxtStatus.Text = "Opening Microsoft Store checkout...";
        bool success = await StoreMonetizationService.Instance.RequestProPurchaseAsync();
        if (success)
        {
            TxtStatus.Text = "Upgraded to Pro! Ads removed.";
        }
        else
        {
            TxtStatus.Text = "Purchase canceled or not available.";
        }
    }

    private void TxtInput_TextChanged(object sender, TextChangedEventArgs e) => RegenerateQr();
    private void CmbErrorCorrection_SelectionChanged(object sender, SelectionChangedEventArgs e) => RegenerateQr();
    private void SldModuleSize_ValueChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e) => RegenerateQr();
    private void Color_TextChanged(object sender, TextChangedEventArgs e) => RegenerateQr();

    private void RegenerateQr()
    {
        if (ImgPreview == null || TxtInput == null) return;

        string payload = TxtInput.Text;
        if (string.IsNullOrWhiteSpace(payload))
        {
            ImgPreview.Source = null;
            TxtStatus.Text = "Enter text or link to generate";
            return;
        }

        QRCodeGenerator.ECCLevel ecc = QRCodeGenerator.ECCLevel.M;
        if (CmbErrorCorrection?.SelectedItem is ComboBoxItem item && item.Tag is string tag)
        {
            ecc = tag switch
            {
                "L" => QRCodeGenerator.ECCLevel.L,
                "Q" => QRCodeGenerator.ECCLevel.Q,
                "H" => QRCodeGenerator.ECCLevel.H,
                _ => QRCodeGenerator.ECCLevel.M
            };
        }

        int moduleSize = SldModuleSize != null ? (int)SldModuleSize.Value : 12;
        string dark = string.IsNullOrWhiteSpace(TxtDarkColor?.Text) ? "#000000" : TxtDarkColor.Text;
        string light = string.IsNullOrWhiteSpace(TxtLightColor?.Text) ? "#FFFFFF" : TxtLightColor.Text;

        try
        {
            _currentResult = QrService.Generate(payload, ecc, moduleSize, dark, light);

            if (_currentResult.PngBytes.Length > 0)
            {
                var bitmapImage = new BitmapImage();
                using var ms = new MemoryStream(_currentResult.PngBytes);
                using var ras = ms.AsRandomAccessStream();
                bitmapImage.SetSource(ras);
                ImgPreview.Source = bitmapImage;
                TxtStatus.Text = $"Generated QR for {payload.Length} characters.";
            }
        }
        catch (Exception ex)
        {
            TxtStatus.Text = $"Error: {ex.Message}";
        }
    }

    private async void BtnSavePng_Click(object sender, RoutedEventArgs e)
    {
        if (_currentResult == null || _currentResult.PngBytes.Length == 0) return;

        try
        {
            var savePicker = new FileSavePicker();
            AttachWindowHandle(savePicker);

            savePicker.SuggestedStartLocation = PickerLocationId.PicturesLibrary;
            savePicker.FileTypeChoices.Add("PNG Image", new[] { ".png" });
            savePicker.SuggestedFileName = "qrcode";

            StorageFile file = await savePicker.PickSaveFileAsync();
            if (file != null)
            {
                await FileIO.WriteBytesAsync(file, _currentResult.PngBytes);
                TxtStatus.Text = $"Saved to {file.Path}";
            }
        }
        catch (Exception ex)
        {
            TxtStatus.Text = $"Save error: {ex.Message}";
        }
    }

    private async void BtnSaveSvg_Click(object sender, RoutedEventArgs e)
    {
        if (_currentResult == null || string.IsNullOrWhiteSpace(_currentResult.SvgContent)) return;

        try
        {
            var savePicker = new FileSavePicker();
            AttachWindowHandle(savePicker);

            savePicker.SuggestedStartLocation = PickerLocationId.PicturesLibrary;
            savePicker.FileTypeChoices.Add("Scalable Vector Graphics (SVG)", new[] { ".svg" });
            savePicker.SuggestedFileName = "qrcode";

            StorageFile file = await savePicker.PickSaveFileAsync();
            if (file != null)
            {
                await FileIO.WriteTextAsync(file, _currentResult.SvgContent);
                TxtStatus.Text = $"Saved vector SVG to {file.Path}";
            }
        }
        catch (Exception ex)
        {
            TxtStatus.Text = $"Save error: {ex.Message}";
        }
    }

    private void AttachWindowHandle(object picker)
    {
        // Interop helper to attach Win32 HWND to WinRT FileSavePicker in WinUI 3
        IntPtr hwnd = WindowNative.GetWindowHandle(App.CurrentWindow);
        WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);
    }
}
