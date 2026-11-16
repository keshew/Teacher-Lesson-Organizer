import SwiftUI

@main struct MyApp: App {
    @UIApplicationDelegateAdaptor(OrganizerAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            OrganizerStartView(appDelegate: appDelegate)
        }
    }
}
