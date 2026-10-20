import AuthenticationServices
import SwiftUI

/// Sign in / create account, with email or username + password, or Apple.
/// Used in onboarding and as a sheet from the Profile tab.
struct AuthView: View {
    enum Mode: String, CaseIterable {
        case signIn = "Sign in"
        case signUp = "Create account"
    }

    /// Called after a successful sign-in or sign-up.
    var onSuccess: () -> Void = {}

    @Environment(AuthManager.self) private var auth
    @State private var mode: Mode = .signIn
    @State private var identifier = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var appleNonce = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if !auth.isConfigured {
                Label(AuthError.notConfigured.localizedDescription, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.pfTextPrimary)
                    .padding(Spacing.md)
                    .background(Color.pfBrandDeep, in: RoundedRectangle(cornerRadius: Radius.medium))
            }

            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(spacing: Spacing.sm) {
                if mode == .signUp {
                    field("Your name (optional)", text: $name)
                        .textContentType(.name)
                }
                field("Email or username", text: $identifier)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                secureField("Password", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                if mode == .signUp {
                    secureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                    Text("Use an email to be able to reset your password. A username works too, but can't be recovered.")
                        .font(.pfCaption)
                        .foregroundStyle(Color.pfTextSecondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfError)
            }
            if let infoMessage {
                Text(infoMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.pfSuccess)
            }

            PFButton(title: mode.rawValue, isLoading: isWorking) {
                Task { await submit() }
            }
            .disabled(!canSubmit)

            if mode == .signIn {
                Button("Forgot password?") { Task { await resetPassword() } }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Rectangle().fill(Color.pfBorder).frame(height: 1)
                Text("or").font(.pfCaption).foregroundStyle(Color.pfTextSecondary)
                Rectangle().fill(Color.pfBorder).frame(height: 1)
            }

            SignInWithAppleButton(mode == .signUp ? .signUp : .signIn) { request in
                appleNonce = AuthManager.makeNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = AuthManager.sha256(appleNonce)
            } onCompletion: { result in
                Task { await finishApple(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
        }
        .onChange(of: mode) {
            errorMessage = nil
            infoMessage = nil
        }
    }

    private var canSubmit: Bool {
        guard !identifier.isEmpty, password.count >= 6 else { return false }
        return mode == .signIn || password == confirmPassword
    }

    private func submit() async {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            switch mode {
            case .signIn: try await auth.signIn(identifier: identifier, password: password)
            case .signUp: try await auth.signUp(identifier: identifier, password: password, displayName: name)
            }
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetPassword() async {
        errorMessage = nil
        guard !identifier.isEmpty else {
            errorMessage = "Type your email above first."
            return
        }
        do {
            try await auth.sendPasswordReset(identifier: identifier)
            infoMessage = "Check your email for a link to reset your password."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishApple(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        do {
            try await auth.signInWithApple(result, nonce: appleNonce)
            onSuccess()
        } catch is CancellationError {
            // User closed the Apple sheet.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .padding(Spacing.md)
            .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
    }

    private func secureField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .padding(Spacing.md)
            .background(Color.pfSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium).stroke(Color.pfBorder))
    }
}

/// AuthView in a sheet with a title and Cancel (from the Profile tab).
struct AuthSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                AuthView { dismiss() }
                    .padding(Spacing.lg)
            }
            .background(Color.pfBackground)
            .navigationTitle("Your account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
