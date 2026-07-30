import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import Security
import UIKit

enum FirebaseRuntime {
    static var isConfigured: Bool { FirebaseApp.app() != nil }
    static var appCheckProviderConfigured: Bool {
        FirebaseBuildConfiguration.appCheckProvider != "" &&
            FirebaseBuildConfiguration.appCheckProvider != "disabled"
    }
    static let configurationRequiredMessage = "Firebase configuration is not installed on this device."
}

enum AuthenticationProvider: String, Equatable {
    case apple
    case google
}

enum AuthenticationState: Equatable {
    case unavailable(String)
    case signedOut
    case signingIn(AuthenticationProvider)
    case signedIn(userID: String)
    case failed(String)

    var userID: String? {
        guard case let .signedIn(userID) = self else { return nil }
        return userID
    }
}

enum AppCheckState: Equatable {
    case unavailable(String)
    case checking
    case ready(expirationDate: Date)
    case failed(String)

    var isReady: Bool {
        guard case let .ready(expirationDate) = self else { return false }
        // Refresh shortly before expiry rather than discovering an expired
        // token only after a protected callable has failed.
        return expirationDate > Date().addingTimeInterval(60)
    }
}

enum ProtectedFeatureAvailability: Equatable {
    case available
    case unavailable(String)

    static func aiAccess(authentication: AuthenticationState, appCheck: AppCheckState) -> ProtectedFeatureAvailability {
        guard authentication.userID != nil else {
            return .unavailable("Sign in is required before AI features can be used.")
        }
        guard appCheck.isReady else {
            return .unavailable("App Check must be configured before AI features can be used.")
        }
        return .available
    }
}

/// Firebase Auth state for UI presentation. The app remains explicitly signed
/// out/unavailable until a Firebase configuration file is present.
@MainActor
final class AuthenticationStateStore: ObservableObject {
    @Published private(set) var state: AuthenticationState
    private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        state = .unavailable(FirebaseRuntime.configurationRequiredMessage)
        refresh()
    }

    deinit {
        if let listenerHandle, FirebaseRuntime.isConfigured {
            Auth.auth().removeStateDidChangeListener(listenerHandle)
        }
    }

    func refresh() {
        guard FirebaseRuntime.isConfigured else {
            state = .unavailable(FirebaseRuntime.configurationRequiredMessage)
            return
        }
        if let listenerHandle {
            Auth.auth().removeStateDidChangeListener(listenerHandle)
        }
        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.state = user.map { .signedIn(userID: $0.uid) } ?? .signedOut
            }
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) async {
        guard FirebaseRuntime.isConfigured else {
            state = .unavailable(FirebaseRuntime.configurationRequiredMessage)
            return
        }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            state = .unavailable("Google Sign-In has not been configured for this app.")
            return
        }
        state = .signingIn(.google)
        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            guard let idToken = result.user.idToken?.tokenString else {
                state = .failed("Google Sign-In did not return an identity token.")
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            if error is CancellationError || (error as NSError).code == -5 {
                state = .signedOut
            } else {
                state = .failed("Google Sign-In could not be completed. Please try again.")
            }
        }
    }

    func signInWithApple(
        identityToken: Data,
        rawNonce: String,
        fullName: PersonNameComponents? = nil
    ) async {
        guard FirebaseRuntime.isConfigured else {
            state = .unavailable(FirebaseRuntime.configurationRequiredMessage)
            return
        }
        guard let token = String(data: identityToken, encoding: .utf8), !token.isEmpty else {
            state = .failed("Apple Sign-In did not return an identity token.")
            return
        }
        state = .signingIn(.apple)
        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: token,
                rawNonce: rawNonce,
                fullName: fullName
            )
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            state = .failed("Apple Sign-In could not be completed. Please try again.")
        }
    }

    func signOut() {
        guard FirebaseRuntime.isConfigured else {
            state = .unavailable(FirebaseRuntime.configurationRequiredMessage)
            return
        }
        do {
            try Auth.auth().signOut()
            state = .signedOut
        } catch {
            state = .failed("Sign out could not be completed. Please try again.")
        }
    }

    func handleAppleAuthorizationFailure(_ error: Error) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            state = .signedOut
        } else {
            state = .failed("Apple Sign-In could not be completed. Please try again.")
        }
    }

    func reportAppleTokenFailure() {
        state = .failed("Apple Sign-In did not return an identity token. Please try again.")
    }

    static func makeAppleNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var nonce = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                preconditionFailure("Unable to generate a secure Apple Sign-In nonce.")
            }
            if Int(random) < alphabet.count {
                nonce.append(alphabet[Int(random)])
                remaining -= 1
            }
        }
        return nonce
    }

    static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// App Check is installed by the app delegate before Firebase configuration.
/// The store only reports ready after it has obtained an unexpired token.
@MainActor
final class AppCheckStateStore: ObservableObject {
    @Published private(set) var state: AppCheckState
    private let providerConfigured: Bool

    init(providerConfigured: Bool = FirebaseRuntime.appCheckProviderConfigured) {
        self.providerConfigured = providerConfigured
        if !FirebaseRuntime.isConfigured {
            state = .unavailable(FirebaseRuntime.configurationRequiredMessage)
        } else if !providerConfigured {
            state = .unavailable("App Check has not been configured for this build.")
        } else {
            state = .unavailable("App Check has not been verified yet.")
        }
    }

    func refresh(forceRefresh: Bool = false) async {
        guard FirebaseRuntime.isConfigured else {
            state = .unavailable(FirebaseRuntime.configurationRequiredMessage)
            return
        }
        guard providerConfigured else {
            state = .unavailable("App Check has not been configured for this build.")
            return
        }

        state = .checking
        do {
            let token = try await AppCheck.appCheck().token(forcingRefresh: forceRefresh)
            state = .ready(expirationDate: token.expirationDate)
        } catch {
            // Do not surface provider or network internals in the UI.
            state = .failed("App Check verification failed. Please try again later.")
        }
    }

    func refreshIfNeeded() async {
        let shouldForceRefresh: Bool
        if case let .ready(expirationDate) = state {
            shouldForceRefresh = expirationDate <= Date().addingTimeInterval(60)
        } else {
            shouldForceRefresh = false
        }
        await refresh(forceRefresh: shouldForceRefresh)
    }
}
