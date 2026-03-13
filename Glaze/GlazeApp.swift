import SwiftUI

@main
struct GlazeApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: GlazeController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = GlazeController()
    }
}
