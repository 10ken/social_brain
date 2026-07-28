import XCTest
@testable import SocialBrain

final class ServiceStateTests: XCTestCase {
    func testCalendarCapabilitiesReflectPermissionScope() {
        XCTAssertTrue(CalendarAuthorizationState.fullAccess.canRead)
        XCTAssertTrue(CalendarAuthorizationState.fullAccess.canWrite)
        XCTAssertFalse(CalendarAuthorizationState.writeOnly.canRead)
        XCTAssertTrue(CalendarAuthorizationState.writeOnly.canWrite)
        XCTAssertFalse(CalendarAuthorizationState.denied.canWrite)
    }

    func testAIIsDisabledUntilAuthenticationAndAppCheckAreReady() {
        XCTAssertEqual(
            ProtectedFeatureAvailability.aiAccess(authentication: .signedOut, appCheck: .ready(expirationDate: .now)),
            .unavailable("Sign in is required before AI features can be used.")
        )
        XCTAssertEqual(
            ProtectedFeatureAvailability.aiAccess(
                authentication: .signedIn(userID: "user-1"),
                appCheck: .unavailable("Not configured")
            ),
            .unavailable("App Check must be configured before AI features can be used.")
        )
        XCTAssertEqual(
            ProtectedFeatureAvailability.aiAccess(
                authentication: .signedIn(userID: "user-1"),
                appCheck: .ready(expirationDate: .now)
            ),
            .available
        )
    }
}
