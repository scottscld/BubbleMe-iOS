import SwiftUI

@main
struct BubbleMeApp: App {
    init() {
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
