import PhotosUI
import SwiftUI

/// Change your name and profile photo.
struct EditProfileView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        AvatarView(image: profileStore.avatar, size: 96)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(profileStore.avatar == nil ? "Add photo" : "Change photo")
                        }
                        if profileStore.avatar != nil {
                            Button("Remove photo", role: .destructive) { profileStore.setAvatar(nil) }
                                .font(.subheadline)
                        }
                    }
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)

            Section("Name") {
                TextField("Your name", text: $name)
                    .textContentType(.name)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pfBackground)
        .navigationTitle("Edit profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(isSaving)
            }
        }
        .onAppear { name = profileStore.profile.displayName }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    profileStore.setAvatar(data)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        profileStore.update { $0.displayName = trimmed }
        if auth.user != nil { await auth.updateDisplayName(trimmed) }
        dismiss()
    }
}
