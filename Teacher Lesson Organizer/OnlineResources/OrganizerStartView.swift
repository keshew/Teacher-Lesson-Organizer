import Combine
import SwiftUI

struct OrganizerStartView: View {
    @ObservedObject var appDelegate: OrganizerAppDelegate
    @StateObject private var store = OrganizerStore(installsNotificationDelegate: false)
    @StateObject private var startup = OrganizerStartup()
    @State private var showsOrganizer = false
    @State private var selectedGame: ArcadeGame?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if showsOrganizer {
                ContentView(store: store)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Button {
                            showsOrganizer = false
                        } label: {
                            Label("Games", systemImage: "chevron.left")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                        .background(.regularMaterial)
                    }
            } else {
                ArcadeLobby(openOrganizer: openOrganizer, selected: $selectedGame)
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
            selectedGame = nil
            openOrganizer()
            store.reminderRoute = id
            DispatchQueue.main.async {
                if appDelegate.selectedReminder == id { appDelegate.clearSelectedReminder() }
            }
        }
        .onOpenURL { url in
            selectedGame = nil
            openOrganizer()
            store.receiveBackup(url)
        }
        .fullScreenCover(isPresented: Binding(get: { startup.page != nil && selectedGame == nil }, set: { _ in })) {
            ResourcePageView(address: Binding(get: { startup.page }, set: { _ in }))
                .ignoresSafeArea()
                .safeAreaInset(edge: .top, spacing: 0) {
                    Button {
                        startup.openWorkspace()
                        showsOrganizer = false
                    } label: {
                        Label("Games", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                    .background(.regularMaterial)
                }
                .interactiveDismissDisabled()
        }
    }

    private func openOrganizer() {
        startup.openWorkspace()
        showsOrganizer = true
    }
}
