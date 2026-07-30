import FirebaseAppCheck
import FirebaseCore
import GoogleSignIn
import UIKit

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // A checked-in source build intentionally has no Firebase credentials.
        // Configure only when the environment-specific plist is present so the
        // local-only app can still launch while Firebase setup is pending.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            installAppCheckProviderFactory()
            FirebaseApp.configure()
        }
        return true
    }

    /// App Check must be installed before Firebase configuration. The provider
    /// is controlled by the non-secret build setting so Local has no provider,
    /// Firebase Debug uses debug tokens, and signed builds use App Attest with
    /// DeviceCheck as the availability fallback.
    private func installAppCheckProviderFactory() {
        switch FirebaseBuildConfiguration.appCheckProvider {
        case "debug":
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        case "devicecheck":
            AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
        case "appattest":
            if #available(iOS 14.0, *) {
                AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
            } else {
                AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
            }
        default:
            // Local builds intentionally omit any App Check provider.
            break
        }
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
