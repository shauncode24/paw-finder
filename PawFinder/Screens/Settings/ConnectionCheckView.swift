import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import SwiftUI

/// Settings › Check connection. Tests, one step at a time, whether this phone
/// can reach Firebase, and says what to fix. It exists because "you're offline"
/// has several different causes that look the same on screen.
struct ConnectionCheckView: View {
    struct Step: Identifiable {
        let id = UUID()
        let ok: Bool
        let title: String
        let detail: String
    }

    @Environment(NetworkMonitor.self) private var network
    @Environment(\.dismiss) private var dismiss

    @State private var steps: [Step] = []
    @State private var isRunning = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: Spacing.md) {
                            Image(systemName: step.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(step.ok ? Color.pfSuccess : Color.pfError)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(.pfHeadline)
                                Text(step.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.pfTextSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                    }
                    if isRunning {
                        HStack(spacing: Spacing.md) {
                            ProgressView()
                            Text("Testing…").foregroundStyle(Color.pfTextSecondary)
                        }
                    }
                } footer: {
                    Text("Listings, chats, applications, the map and swipe all come from Firestore. If the last step fails, none of them can show anything.")
                }

                Section {
                    Button("Run the check again") { Task { await run() } }
                        .disabled(isRunning)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pfBackground)
            .navigationTitle("Check connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await run() }
        }
    }

    // MARK: - The checks

    private func run() async {
        isRunning = true
        steps = []
        defer { isRunning = false }

        let configured: Bool = FirebaseApp.app() != nil
        steps.append(Step(
            ok: configured, title: "Firebase is set up in the app",
            detail: configured
                ? "GoogleService-Info.plist was found."
                : "GoogleService-Info.plist is missing from the Xcode target. Add it (docs/SETUP.md, step 2)."))
        guard configured else { return }

        steps.append(Step(
            ok: network.isOnline, title: "The phone reports a connection",
            detail: network.isOnline
                ? "iOS says it is online."
                : "iOS says there is no network. In the Simulator, check the Mac's Wi-Fi/VPN and restart the Simulator."))

        steps.append(await internetStep())
        steps.append(accountStep())
        steps.append(await firestoreStep())
    }

    private func internetStep() async -> Step {
        var request = URLRequest(url: URL(string: "https://firestore.googleapis.com/")!)
        request.timeoutInterval = 8
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code: Int = (response as? HTTPURLResponse)?.statusCode ?? 0
            return Step(ok: true, title: "Google's servers are reachable",
                        detail: "firestore.googleapis.com answered (HTTP \(code)).")
        } catch {
            return Step(ok: false, title: "Google's servers are NOT reachable",
                        detail: "\(error.localizedDescription) This Mac/network is blocking Google (VPN, campus Wi-Fi, firewall, or no internet). Try a phone hotspot.")
        }
    }

    private func accountStep() -> Step {
        if let user = Auth.auth().currentUser {
            return Step(ok: true, title: "You are signed in", detail: user.email ?? user.uid)
        }
        return Step(ok: true, title: "You are not signed in",
                    detail: "Fine for browsing. Sign in to message, apply or list pets.")
    }

    /// A real read from the server (never the phone's saved copy), with a 12 second limit.
    private func firestoreStep() async -> Step {
        let outcome: String? = await withTaskGroup(of: String?.self) { group in
            group.addTask {
                do {
                    let snapshot = try await Firestore.firestore().collection("listings")
                        .limit(to: 1).getDocuments(source: .server)
                    return "ok:\(snapshot.documents.count)"
                } catch {
                    let ns = error as NSError
                    return "error:\(ns.code):\(error.localizedDescription)"
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(12))
                return nil
            }
            let first: String?? = await group.next()
            group.cancelAll()
            return first ?? nil
        }

        guard let outcome else {
            return Step(ok: false, title: "Firestore did not answer in 12 seconds",
                        detail: "The most common cause is that the Firestore database was never created: Firebase console › Build › Firestore Database › Create database (docs/SETUP.md, step 3). If it exists, the network is blocking it.")
        }
        if outcome.hasPrefix("ok:") {
            let count: String = String(outcome.dropFirst(3))
            return Step(ok: true, title: "Firestore answered",
                        detail: count == "0"
                            ? "Connected, but there are no listings yet. Post one from Profile › List a pet."
                            : "Connected and listings are readable.")
        }
        let parts: [Substring] = outcome.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        let code: String = parts.count > 1 ? String(parts[1]) : ""
        let message: String = parts.count > 2 ? String(parts[2]) : outcome
        switch code {
        case "7":
            return Step(ok: false, title: "Firestore refused the read (permission denied)",
                        detail: "Publish the latest firestore.rules in the Firebase console › Firestore › Rules (docs/SETUP.md, step 3).")
        case "5":
            return Step(ok: false, title: "Firestore database not found",
                        detail: "Create the database: Firebase console › Build › Firestore Database › Create database.")
        case "14", "4":
            return Step(ok: false, title: "Firestore is unreachable",
                        detail: "Create the database if you have not (Firebase console › Firestore Database), otherwise this network is blocking it. \(message)")
        default:
            return Step(ok: false, title: "Firestore error \(code)", detail: message)
        }
    }
}
