import BackgroundTasks

/// Asks iOS to wake the app now and then (roughly every few hours, iOS decides)
/// to check favorites for adoptions. The work itself is in PawFinderApp's
/// `.backgroundTask(.appRefresh(...))`.
enum BackgroundRefresh {
    /// Must match BGTaskSchedulerPermittedIdentifiers in Info.plist.
    static let identifier = "pawfinder.refreshFavorites"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Expected on the Simulator, which doesn't run background refresh.
            Log.app.notice("Couldn't schedule background refresh: \(error.localizedDescription)")
        }
    }
}
