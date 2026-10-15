using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.UI.Xaml.Media.Imaging;
using QRCoder;

namespace QRCodeGeneratorNative.Services;

public class QrGenerationResult
{
    public byte[] PngBytes { get; set; } = Array.Empty<byte>();
    public string SvgContent { get; set; } = string.Empty;
    public BitmapImage? PreviewImage { get; set; }
}

public class QrService
{
    public static QrGenerationResult Generate(
        string payload,
        QRCodeGenerator.ECCLevel eccLevel = QRCodeGenerator.ECCLevel.M,
        int pixelsPerModule = 10,
        string darkColorHex = "#000000",
        string lightColorHex = "#FFFFFF")
    {
        if (string.IsNullOrWhiteSpace(payload))
        {
            return new QrGenerationResult();
        }

        using var qrGenerator = new QRCodeGenerator();
        using var qrCodeData = qrGenerator.CreateQrCode(payload, eccLevel);

        // Render PNG bytes using PngByteQRCode
        var pngQr = new PngByteQRCode(qrCodeData);
        byte[] darkColorRgba = HexToRgba(darkColorHex);
        byte[] lightColorRgba = HexToRgba(lightColorHex);

        byte[] pngBytes = pngQr.GetGraphic(pixelsPerModule, darkColorRgba, lightColorRgba);

        // Render SVG using SvgQRCode
        var svgQr = new SvgQRCode(qrCodeData);
        string svg = svgQr.GetGraphic(pixelsPerModule, darkColorHex, lightColorHex, drawQuietZones: true);

        return new QrGenerationResult
        {
            PngBytes = pngBytes,
            SvgContent = svg
        };
    }

    private static byte[] HexToRgba(string hex)
    {
        hex = hex.TrimStart('#');
        if (hex.Length == 6)
        {
            byte r = Convert.ToByte(hex.Substring(0, 2), 16);
            byte g = Convert.ToByte(hex.Substring(2, 2), 16);
            byte b = Convert.ToByte(hex.Substring(4, 2), 16);
            return new byte[] { r, g, b, 255 };
        }
        return new byte[] { 0, 0, 0, 255 };
    }
}
