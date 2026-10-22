import AuthenticationServices
import FirebaseFirestore
import SwiftUI

/// Profile › Account: password reset, sign out, export data, delete account.
struct AccountView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ProfileStore.self) private var profileStore
    @Environment(FavoritesStore.self) private var favorites
    @Environment(FollowedSheltersStore.self) private var followed
    @Environment(ListingsService.self) private var listings
    @Environment(RecentlyViewedStore.self) private var recentlyViewed
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var showPasswordPrompt = false
    @State private var showAppleConfirm = false
    @State private var password = ""
    @State private var isDeleting = false

    var body: some View {
        Form {
            if let user = auth.user {
                Section("Signed in") {
                    LabeledContent("Account", value: user.accountLabel)
                    if case .email = user.signInMethod, let email = user.email {
                        Button("Send password reset email") {
                            Task {
                                do {
                                    try await auth.sendPasswordReset(identifier: email)
                                    message = "Check \(email) for a reset link."
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                    Button("Sign out") { signOut() }
                }
            }

            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Export my data", systemImage: "square.and.arrow.up")
                    }
                } else {
                    ProgressView()
                }
            } header: {
                Text("Your data")
            } footer: {
                Text("A JSON file with your profile, favorites, collections, notes, followed listers, and recently viewed pets.")
            }

            Section {
                Button("Delete account", role: .destructive) { confirmDelete = true }
                    .disabled(isDeleting)
            } footer: {
                Text("Deletes your account and your profile on this device. Favorites stay on this phone and can be removed in the Favorites tab.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(Color.pfError)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pfBackground)
        .navigationTitle("Account")
        .task { makeExport() }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { startDelete() }
        } message: {
            Text("This can't be undone.")
        }
        .alert("Confirm your password", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $password)
            Button("Cancel", role: .cancel) { password = "" }
            Button("Delete", role: .destructive) { Task { await deleteWithPassword() } }
        } message: {
            Text("For your security, enter your password to delete your account.")
        }
        .sheet(isPresented: $showAppleConfirm) {
            AppleDeleteConfirmation { result, nonce in
                showAppleConfirm = false
                Task { await deleteWithApple(result, nonce: nonce) }
            }
            .presentationDetents([.height(260)])
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    /// Removes everything this account put online: its listings (with photos) and its public profile.
    /// Chats and applications are kept, so the other person's history isn't broken.
    private func deleteOnlineData(userID: String) async {
        await listings.deleteAllMine()
        try? await Firestore.firestore().collection("fosters").document(userID).delete()
        try? await Firestore.firestore().collection("users").document(userID).delete()
    }

    private func makeExport() {
        exportURL = try? DataExporter.makeFile(user: auth.user, profile: profileStore.profile, favorites: favorites,
                                               followed: followed, recentlyViewed: recentlyViewed)
    }

    private func signOut() {
        do {
            try auth.signOut()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startDelete() {
        errorMessage = nil
        if case .apple = auth.user?.signInMethod {
            showAppleConfirm = true
        } else {
            showPasswordPrompt = true
        }
    }

    private func deleteWithPassword() async {
        guard let userID = auth.user?.id else { return }
        isDeleting = true
        defer { isDeleting = false; password = "" }
        do {
            try await auth.deleteAccount(password: password, beforeDelete: { await deleteOnlineData(userID: userID) })
            profileStore.deleteData(for: userID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteWithApple(_ result: Result<ASAuthorization, Error>, nonce: String) async {
        guard let userID = auth.user?.id else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await auth.deleteAppleAccount(result, nonce: nonce, beforeDelete: { await deleteOnlineData(userID: userID) })
            profileStore.deleteData(for: userID)
            dismiss()
        } catch is CancellationError {
            // Closed the Apple sheet.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Apple accounts confirm deletion by signing in with Apple once more.
private struct AppleDeleteConfirmation: View {
    let onResult: (Result<ASAuthorization, Error>, String) -> Void
    @State private var nonce = ""

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Confirm with Apple")
                .font(.pfTitle)
                .foregroundStyle(Color.pfTextPrimary)
            Text("To delete your account, confirm it's you with Sign in with Apple.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.pfTextSecondary)
            SignInWithAppleButton(.continue) { request in
                nonce = AuthManager.makeNonce()
                request.nonce = AuthManager.sha256(nonce)
            } onCompletion: { result in
                onResult(result, nonce)
            }
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
        }
        .padding(Spacing.xl)
        .background(Color.pfBackground)
    }
}
