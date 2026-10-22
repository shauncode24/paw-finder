import SwiftUI

/// Account › Change password. Needs the current password (a Firebase security rule).
struct ChangePasswordSheet: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var done = false

    private var canSave: Bool {
        !current.isEmpty && new.count >= 6 && new == confirm && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                if done {
                    Section {
                        Label("Your password was changed.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.pfSuccess)
                    }
                } else {
                    Section {
                        SecureField("Current password", text: $current)
                            .textContentType(.password)
                    }
                    Section {
                        SecureField("New password (6+ characters)", text: $new)
                            .textContentType(.newPassword)
                        SecureField("Repeat the new password", text: $confirm)
                            .textContentType(.newPassword)
                    } footer: {
                        if !confirm.isEmpty, new != confirm {
                            Text("The two new passwords don't match.").foregroundStyle(Color.pfError)
                        }
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(Color.pfError) }
                    }
                    Section {
                        PFButton(title: "Change password", isLoading: isSaving) { Task { await save() } }
                            .disabled(!canSave)
                            .opacity(canSave || isSaving ? 1 : 0.5)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pfBackground)
            .navigationTitle("Change password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(done ? "Done" : "Cancel") { dismiss() } }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await auth.changePassword(current: current, new: new)
            done = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
