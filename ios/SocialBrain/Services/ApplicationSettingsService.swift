import UIKit

/// Small boundary around the Settings deep link so permission screens remain
/// testable and never need to reach into UIApplication directly.
@MainActor
protocol ApplicationSettingsOpening: AnyObject {
    func openApplicationSettings()
}

@MainActor
final class SystemApplicationSettingsOpener: ApplicationSettingsOpening {
    func openApplicationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        UIApplication.shared.open(url)
    }
}
