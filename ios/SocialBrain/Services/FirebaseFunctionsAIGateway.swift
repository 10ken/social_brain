import Foundation

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

enum FirebaseBuildConfiguration {
    static var functionsRegion: String {
        (Bundle.main.object(forInfoDictionaryKey: "FUNCTIONS_REGION") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "us-central1"
    }

    static var appCheckProvider: String {
        ((Bundle.main.object(forInfoDictionaryKey: "APP_CHECK_PROVIDER") as? String) ?? "disabled")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

@MainActor
protocol AIExtracting: AnyObject {
    func extract(_ request: AIExtractionRequest) async throws -> AIExtractionResult
    func recall(_ request: AIExtractionRequest) async throws -> String
    func deleteAccountData() async throws
}

/// Pure transport-code mapping kept outside the Firebase import gate so unit
/// tests can verify that content-free errors remain actionable in Local CI.
enum FirebaseFunctionsErrorMapper {
    static func clientError(code: Int, accountDeletion: Bool = false) -> AIClientError {
        switch code {
        case 3: return .invalidRequest
        case 7: return .appCheck
        case 16: return .unauthenticated
        case 8: return .rateLimited
        case 9: return accountDeletion ? .accountDeletionRequiresRecentSignIn : .invalidContract
        case 14: return .unavailable
        default: return .unavailable
        }
    }
}

@MainActor
final class LocalOnlyAIGateway: AIExtracting {
    func extract(_ request: AIExtractionRequest) async throws -> AIExtractionResult {
        throw AIClientError.disabled
    }

    func recall(_ request: AIExtractionRequest) async throws -> String {
        throw AIClientError.disabled
    }

    func deleteAccountData() async throws {
        throw AIClientError.disabled
    }
}

/// Firebase may be configured by the application delegate after SwiftUI has
/// constructed its root environment. Resolve the concrete gateway at call time
/// so a Firebase Debug build does not become permanently local-only because of
/// that launch ordering.
@MainActor
final class AdaptiveAIGateway: AIExtracting {
    func extract(_ request: AIExtractionRequest) async throws -> AIExtractionResult {
#if canImport(FirebaseFunctions)
        guard FirebaseRuntime.isConfigured else { throw AIClientError.disabled }
        return try await FirebaseFunctionsAIGateway().extract(request)
#else
        throw AIClientError.disabled
#endif
    }

    func recall(_ request: AIExtractionRequest) async throws -> String {
#if canImport(FirebaseFunctions)
        guard FirebaseRuntime.isConfigured else { throw AIClientError.disabled }
        return try await FirebaseFunctionsAIGateway().recall(request)
#else
        throw AIClientError.disabled
#endif
    }

    func deleteAccountData() async throws {
#if canImport(FirebaseFunctions)
        guard FirebaseRuntime.isConfigured else { throw AIClientError.disabled }
        try await FirebaseFunctionsAIGateway().deleteAccountData()
#else
        throw AIClientError.disabled
#endif
    }
}

#if canImport(FirebaseFunctions)
@MainActor
final class FirebaseFunctionsAIGateway: AIExtracting {
    private let functions: Functions

    init(region: String = FirebaseBuildConfiguration.functionsRegion) {
        functions = Functions.functions(region: region)
    }

    func extract(_ request: AIExtractionRequest) async throws -> AIExtractionResult {
        try request.validate()
        guard FirebaseRuntime.isConfigured else { throw AIClientError.disabled }
        do {
            let result = try await functions
                .httpsCallable("generateAIContent")
                .call(request.callablePayload)
            let text = try responseText(from: result.data)
            guard request.responseMimeType == .json else { throw AIClientError.invalidRequest }
            return try AIExtractionResult.decodeStrict(from: text)
        } catch let error as AIClientError {
            throw error
        } catch {
            throw map(error)
        }
    }

    func recall(_ request: AIExtractionRequest) async throws -> String {
        try request.validate()
        guard FirebaseRuntime.isConfigured else { throw AIClientError.disabled }
        do {
            let result = try await functions
                .httpsCallable("generateAIContent")
                .call(request.callablePayload)
            let text = try responseText(from: result.data)
            guard text.lengthOfBytes(using: .utf8) <= AIRequestLimits.maxResponseBytes else {
                throw AIClientError.responseTooLarge
            }
            return text
        } catch let error as AIClientError {
            throw error
        } catch {
            throw map(error)
        }
    }

    func deleteAccountData() async throws {
        guard FirebaseRuntime.isConfigured else { throw AIClientError.disabled }
        do {
            let result = try await functions
                .httpsCallable("deleteAccountData")
                .call([String: Any]())
            guard let response = result.data as? [String: Any],
                  response.count == 1,
                  response["deleted"] as? Bool == true
            else {
                throw AIClientError.unavailable
            }
        } catch let error as AIClientError {
            throw error
        } catch {
            throw map(error, accountDeletion: true)
        }
    }

    private func responseText(from data: Any?) throws -> String {
        guard let response = data as? [String: Any],
              response.count == 1,
              let text = response["text"] as? String,
              text.lengthOfBytes(using: .utf8) <= AIRequestLimits.maxResponseBytes
        else {
            throw AIClientError.invalidContract
        }
        return text
    }

    /// Firebase Functions maps callable codes to their gRPC integer values.
    /// Keep mapping content-free: neither server error details nor prompts are
    /// surfaced or logged by the client.
    private func map(_ error: Error, accountDeletion: Bool = false) -> AIClientError {
        FirebaseFunctionsErrorMapper.clientError(
            code: (error as NSError).code,
            accountDeletion: accountDeletion
        )
    }
}
#endif

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
