using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Windows.Services.Store;

namespace QRCodeGeneratorNative.Services;

/// <summary>
/// Service to communicate with Microsoft Store In-App Purchases (StoreContext)
/// and license verification for the Pro tier.
/// </summary>
public class StoreMonetizationService
{
    private static StoreMonetizationService? _instance;
    public static StoreMonetizationService Instance => _instance ??= new StoreMonetizationService();

    // Microsoft Partner Center In-App Product (Durable Add-on) Store ID
    public const string ProAddOnStoreId = "pro_unlock";

    public bool IsProUser { get; private set; } = false;
    public event EventHandler<bool>? LicenseStatusChanged;

    private StoreContext? _storeContext;

    public StoreMonetizationService()
    {
    }

    /// <summary>
    /// Checks the user's active licenses from Microsoft Store.
    /// If Pro addon license is active, IsProUser becomes true and ads should be suppressed.
    /// </summary>
    public async Task InitializeAndCheckLicenseAsync()
    {
        try
        {
            _storeContext ??= StoreContext.GetDefault();
            StoreAppLicense license = await _storeContext.GetAppLicenseAsync();

            if (license != null)
            {
                // Check if user has purchased the Pro Add-On
                if (license.AddOnLicenses.TryGetValue(ProAddOnStoreId, out StoreLicense? addOnLicense))
                {
                    IsProUser = addOnLicense.IsActive;
                }
                else
                {
                    IsProUser = false;
                }
            }
        }
        catch (Exception)
        {
            // When running in unpackaged debug mode outside Store environment, default to standard tier
            IsProUser = false;
        }

        LicenseStatusChanged?.Invoke(this, IsProUser);
    }

    /// <summary>
    /// Prompts the native Microsoft Store In-App Purchase modal to buy Pro.
    /// </summary>
    public async Task<bool> RequestProPurchaseAsync()
    {
        try
        {
            _storeContext ??= StoreContext.GetDefault();
            StorePurchaseResult result = await _storeContext.RequestPurchaseAsync(ProAddOnStoreId);

            if (result.Status == StorePurchaseStatus.Succeeded || result.Status == StorePurchaseStatus.AlreadyPurchased)
            {
                IsProUser = true;
                LicenseStatusChanged?.Invoke(this, true);
                return true;
            }
        }
        catch (Exception)
        {
            // Store context might fail if running unpackaged
        }

        return false;
    }
}
