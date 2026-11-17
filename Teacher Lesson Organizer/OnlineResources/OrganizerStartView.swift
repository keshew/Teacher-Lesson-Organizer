import Combine
import SwiftUI

struct OrganizerStartView: View {
    @ObservedObject var appDelegate: OrganizerAppDelegate
    @StateObject private var store = OrganizerStore(installsNotificationDelegate: false)
    @StateObject private var startup = OrganizerStartup()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if startup.hasOpenedWorkspace {
                ContentView(store: store)
            } else {
                LaunchScreen()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                startup.enterForeground()
            } else if phase == .background {
                startup.enterBackground()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ResourceCache.registrationChanged)) { _ in
            startup.registrationChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: ResourceCache.noticeSelected)) { _ in
            startup.openResourceNotification()
        }
        .onReceive(appDelegate.$selectedReminder.compactMap { $0 }) { id in
            startup.openWorkspace()
            store.reminderRoute = id
            DispatchQueue.main.async {
                if appDelegate.selectedReminder == id { appDelegate.clearSelectedReminder() }
            }
        }
        .onOpenURL { url in
            startup.openWorkspace()
            store.receiveBackup(url)
        }
        .fullScreenCover(isPresented: Binding(get: { startup.page != nil }, set: { _ in })) {
            ResourcePageView(address: Binding(get: { startup.page }, set: { _ in }))
                .ignoresSafeArea()
                .interactiveDismissDisabled()
        }
    }
}
