import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore

/// The signed-in user, as the app sees it.
struct AppUser: Equatable {
    let id: String
    let email: String?
    let displayName: String?
    let signInMethod: SignInMethod

    enum SignInMethod: Equatable {
        case email
        case username(String)
        case apple
    }

    /// What to show under the name on the profile screen.
    var accountLabel: String {
        switch signInMethod {
        case .email: email ?? ""
        case .username(let name): "@\(name)"
        case .apple: email.map { "Signed in with Apple · \($0)" } ?? "Signed in with Apple"
        }
    }
}

/// Accounts through Firebase Authentication.
///
/// Supports email + password, **username** + password, and Sign in with Apple.
/// Firebase only knows emails, so a username like "shaun_k" is stored as the
/// hidden email "shaun_k@users.pawfinder.app". Firebase keeps the session in
/// the Keychain and refreshes tokens by itself.
@MainActor
@Observable
final class AuthManager {
    private(set) var user: AppUser?
    /// False when GoogleService-Info.plist is missing; the app then runs guest-only.
    let isConfigured: Bool

    @ObservationIgnored private var listener: AuthStateDidChangeListenerHandle?

    static let usernameDomain = "users.pawfinder.app"

    init() {
        isConfigured = FirebaseApp.app() != nil
        guard isConfigured else { return }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in self?.user = firebaseUser.map(Self.appUser) }
        }
    }

    /// Call once at launch, before creating an AuthManager.
    static func configureFirebase() {
        guard FirebaseApp.app() == nil else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            Log.app.notice("GoogleService-Info.plist not found: accounts are turned off (guest mode only).")
            return
        }
        FirebaseApp.configure()
    }

    // MARK: - Email / username + password

    /// - Parameter identifier: An email address or a username.
    func signIn(identifier: String, password: String) async throws {
        let email = try Self.email(for: identifier)
        try await run { _ = try await Auth.auth().signIn(withEmail: email, password: password) }
    }

    func signUp(identifier: String, password: String, displayName: String) async throws {
        let email = try Self.email(for: identifier)
        try await run {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let name = displayName.trimmingCharacters(in: .whitespaces)
            let change = result.user.createProfileChangeRequest()
            change.displayName = name.isEmpty ? Self.username(from: email) ?? "" : name
            try await change.commitChanges()
            try await result.user.reload()
        }
        refreshUser()
    }

    func sendPasswordReset(identifier: String) async throws {
        let email = try Self.email(for: identifier)
        guard Self.username(from: email) == nil else { throw AuthError.usernameCantReset }
        try await run { try await Auth.auth().sendPasswordReset(withEmail: email) }
    }

    func updateDisplayName(_ name: String) async {
        guard let currentUser = firebaseUser else { return }
        let change = currentUser.createProfileChangeRequest()
        change.displayName = name
        try? await change.commitChanges()
        refreshUser()
    }

    func signOut() throws {
        guard isConfigured else { return }
        try Auth.auth().signOut()
    }

    // MARK: - Sign in with Apple

    /// Make a nonce before showing the Apple button; pass its hash to the request.
    static func makeNonce() -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<32).map { _ in characters.randomElement() ?? "a" })
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Finishes Sign in with Apple once the system sheet returns.
    func signInWithApple(_ result: Result<ASAuthorization, Error>, nonce: String) async throws {
        let credential = try Self.appleCredential(from: result)
        guard let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.appleFailed
        }
        let firebaseCredential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce,
                                                               fullName: credential.fullName)
        try await run { _ = try await Auth.auth().signIn(with: firebaseCredential) }
    }

    // MARK: - Delete account

    /// Deletes the account. Firebase wants a fresh sign-in first, so password
    /// accounts pass their password here.
    func deleteAccount(password: String) async throws {
        guard let currentUser = firebaseUser,
              let email = currentUser.email else { throw AuthError.notConfigured }
        try await run {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await currentUser.reauthenticate(with: credential)
            try await currentUser.delete()
        }
    }

    /// Apple accounts confirm with Apple again; we also revoke the Apple
    /// token, which App Store rules require when deleting an Apple account.
    func deleteAppleAccount(_ result: Result<ASAuthorization, Error>, nonce: String) async throws {
        guard let currentUser = firebaseUser else { throw AuthError.notConfigured }
        let credential = try Self.appleCredential(from: result)
        guard let tokenData = credential.identityToken, let token = String(data: tokenData, encoding: .utf8),
              let codeData = credential.authorizationCode, let code = String(data: codeData, encoding: .utf8) else {
            throw AuthError.appleFailed
        }
        try await run {
            let firebaseCredential = OAuthProvider.appleCredential(withIDToken: token, rawNonce: nonce,
                                                                   fullName: nil)
            try await currentUser.reauthenticate(with: firebaseCredential)
            try await Auth.auth().revokeToken(withAuthorizationCode: code)
            try await currentUser.delete()
        }
    }

    // MARK: - Helpers

    /// `Auth.auth()` crashes if Firebase isn't configured, so check first.
    private var firebaseUser: User? {
        isConfigured ? Auth.auth().currentUser : nil
    }

    /// Runs a Firebase call and turns its errors into friendly ones.
    private func run(_ work: () async throws -> Void) async throws {
        guard isConfigured else { throw AuthError.notConfigured }
        do {
            try await work()
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError(firebaseError: error)
        }
    }

    private func refreshUser() {
        user = firebaseUser.map(Self.appUser)
    }

    private static func appUser(_ user: User) -> AppUser {
        let isApple = user.providerData.contains { $0.providerID == "apple.com" }
        let username = user.email.flatMap(Self.username(from:))
        let method: AppUser.SignInMethod = isApple ? .apple : username.map { .username($0) } ?? .email
        return AppUser(id: user.uid, email: username == nil ? user.email : nil,
                       displayName: user.displayName, signInMethod: method)
    }

    /// "shaun@mail.com" stays as is; "shaun_k" becomes "shaun_k@users.pawfinder.app".
    static func email(for identifier: String) throws -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmed.contains("@") { return trimmed }
        guard trimmed.range(of: #"^[a-z0-9_.]{3,20}$"#, options: .regularExpression) != nil else {
            throw AuthError.invalidUsername
        }
        return "\(trimmed)@\(usernameDomain)"
    }

    static func username(from email: String) -> String? {
        let suffix = "@\(usernameDomain)"
        return email.hasSuffix(suffix) ? String(email.dropLast(suffix.count)) : nil
    }

    private static func appleCredential(from result: Result<ASAuthorization, Error>) throws
        -> ASAuthorizationAppleIDCredential {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthError.appleFailed
            }
            return credential
        case .failure(let error):
            let code = (error as? ASAuthorizationError)?.code
            if code == .canceled { throw CancellationError() }
            // 1000 (.unknown) is what you get without the Sign in with Apple capability.
            if code == .unknown { throw AuthError.appleNeedsPaidAccount }
            throw AuthError.appleFailed
        }
    }
}

/// Sign-in errors with messages that are OK to show.
enum AuthError: LocalizedError {
    case notConfigured
    case invalidUsername
    case usernameCantReset
    case wrongCredentials
    case accountExists
    case weakPassword
    case invalidEmail
    case offline
    case tooManyAttempts
    case needsRecentLogin
    case appleNeedsPaidAccount
    case appleFailed
    case other(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Accounts aren't set up yet. Add GoogleService-Info.plist (see docs/SETUP.md). You can keep using PawFinder as a guest."
        case .invalidUsername: "Usernames are 3–20 characters: letters, numbers, dots, and underscores."
        case .usernameCantReset:
            "Username accounts don't have an email, so we can't send a reset link. Create a new account if you've lost your password."
        case .wrongCredentials: "That email/username and password don't match."
        case .accountExists: "An account with that email or username already exists. Try signing in."
        case .weakPassword: "Choose a password with at least 6 characters."
        case .invalidEmail: "That email address doesn't look right."
        case .offline: "You're offline. Connect to the internet to sign in."
        case .tooManyAttempts: "Too many attempts. Wait a few minutes and try again."
        case .needsRecentLogin: "For your security, please sign in again and then try once more."
        case .appleNeedsPaidAccount:
            "Sign in with Apple needs a paid Apple Developer account on this build. Use email or a username for now."
        case .appleFailed: "Sign in with Apple didn't work. Please try again."
        case .other(let message): message
        }
    }

    /// Firebase error codes (stable numbers across SDK versions).
    init(firebaseError error: Error) {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            self = .other(error.localizedDescription)
            return
        }
        switch nsError.code {
        case 17009, 17004, 17011: self = .wrongCredentials        // wrong password, invalid credential, no user
        case 17007: self = .accountExists
        case 17026: self = .weakPassword
        case 17008: self = .invalidEmail
        case 17020: self = .offline
        case 17010: self = .tooManyAttempts
        case 17014: self = .needsRecentLogin
        default: self = .other(error.localizedDescription)
        }
    }
}
