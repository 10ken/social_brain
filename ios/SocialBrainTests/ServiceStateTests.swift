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

    func testCalendarExportOwnershipMarkerRoundTrips() {
        let ownerID = UUID()
        let notes = CalendarEventOwnership.notes("Dinner with Alex", ownerID: ownerID)

        XCTAssertEqual(CalendarEventOwnership.ownerID(in: notes), ownerID)
        XCTAssertNil(CalendarEventOwnership.ownerID(in: "Dinner with Alex"))
        XCTAssertTrue(notes?.contains(CalendarEventOwnership.marker(for: ownerID)) == true)
    }

    func testCaptureInputTextIsTrimmedAndBoundedBeforeEncryption() throws {
        let input = LocalCaptureInputPreparationService()

        XCTAssertEqual(try input.normalizedText("  private note  "), "private note")
        XCTAssertThrowsError(
            try input.normalizedText(String(repeating: "x", count: CaptureInputLimits.maximumTextCharacters + 1))
        ) { error in
            XCTAssertEqual(
                error as? CaptureInputPreparationError,
                .textTooLong(limit: CaptureInputLimits.maximumTextCharacters)
            )
        }
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
