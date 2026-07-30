import XCTest
@testable import SocialBrain

final class AIExtractionContractsTests: XCTestCase {
    func testCanonicalValidFixtureDecodesStrictly() throws {
        let result = try AIExtractionResult.decodeStrict(from: fixture(named: "ai-extraction.valid"))

        XCTAssertEqual(result.people.first?.name, "Michelle")
        XCTAssertEqual(result.events.first?.resolvedDate, "2026-06-13")
        XCTAssertEqual(result.memories.first?.memoryType, .lifeUpdate)
        XCTAssertEqual(result.relationships.first?.relationshipType, .friend)
    }

    func testInvalidSnakeCaseFixtureIsRejected() {
        XCTAssertThrowsError(try AIExtractionResult.decodeStrict(from: fixture(named: "ai-extraction.invalid"))) { error in
            XCTAssertEqual(error as? AIClientError, .invalidContract)
        }
    }

    func testUnknownFieldsAndInvalidDatesAreRejected() {
        let unknownField = """
        {"people":[],"events":[],"memories":[],"relationships":[],"reminders":[],"extra":true}
        """
        XCTAssertThrowsError(try AIExtractionResult.decodeStrict(from: unknownField))

        let invalidDate = """
        {"people":[],"events":[{"title":"Dinner","resolvedDate":"2026-02-30","confidenceState":"suggested","evidence":"Dinner."}],"memories":[],"relationships":[],"reminders":[]}
        """
        XCTAssertThrowsError(try AIExtractionResult.decodeStrict(from: invalidDate))
    }

    func testRequestLimitsMatchCallableContract() throws {
        XCTAssertThrowsError(try AIExtractionRequest(prompt: " ")) { error in
            XCTAssertEqual(error as? AIClientError, .invalidRequest)
        }

        let tooLargePrompt = String(repeating: "a", count: AIRequestLimits.maxPromptBytes + 1)
        XCTAssertThrowsError(try AIExtractionRequest(prompt: tooLargePrompt))

        let request = try AIExtractionRequest(prompt: "A reviewed local note")
        XCTAssertEqual(request.callablePayload["responseMimeType"] as? String, "application/json")
    }

    private func fixture(named name: String) -> String {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            XCTFail("Missing shared contract fixture \(name).json in the test bundle.")
            return "{}"
        }
        return text
    }
}
