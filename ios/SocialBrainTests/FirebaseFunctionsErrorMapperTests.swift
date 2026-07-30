import XCTest
@testable import SocialBrain

final class FirebaseFunctionsErrorMapperTests: XCTestCase {
    func testCallableFailuresMapToSafeClientStates() {
        XCTAssertEqual(FirebaseFunctionsErrorMapper.clientError(code: 16), .unauthenticated)
        XCTAssertEqual(FirebaseFunctionsErrorMapper.clientError(code: 7), .appCheck)
        XCTAssertEqual(FirebaseFunctionsErrorMapper.clientError(code: 8), .rateLimited)
        XCTAssertEqual(FirebaseFunctionsErrorMapper.clientError(code: 9), .invalidContract)
        XCTAssertEqual(
            FirebaseFunctionsErrorMapper.clientError(code: 9, accountDeletion: true),
            .accountDeletionRequiresRecentSignIn
        )
        XCTAssertEqual(FirebaseFunctionsErrorMapper.clientError(code: 14), .unavailable)
    }
}
