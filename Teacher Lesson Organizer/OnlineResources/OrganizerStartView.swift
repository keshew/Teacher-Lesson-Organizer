import Combine
import SwiftUI

struct OrganizerStartView: View {
    @ObservedObject var appDelegate: OrganizerAppDelegate
    @StateObject private var store = OrganizerStore(installsNotificationDelegate: false)
    @StateObject private var startup = OrganizerStartup()
    @State private var showsOrganizer = false
    @State private var selectedGame: ArcadeGame?
    @State private var loadedPage: URL?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let webContentIsReady = isPageVisible
        Group {
            if startup.showsLaunchScreen {
                LaunchScreen()
            } else if showsOrganizer {
                ContentView(store: store)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if store.ready {
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
        .fullScreenCover(isPresented: Binding(get: { startup.page != nil && selectedGame == nil }, set: { _ in }), onDismiss: { loadedPage = nil }) {
            ResourcePageView(address: startup.page, didLoad: { loadedPage = $0 })
                .accessibilityHidden(!webContentIsReady)
                .overlay {
                    if !webContentIsReady {
                        LaunchScreen(title: "Opening page…")
                    }
                }
                .interactiveDismissDisabled()
                .task(id: startup.page) {
                    guard let requested = startup.page, !isPageVisible else { return }
                    do {
                        try await Task.sleep(for: .seconds(25))
                        if startup.page == requested, !isPageVisible {
                            startup.dismissUnavailablePage(requested)
                        }
                    } catch {
                        return
                    }
                }
        }
    }

    private var isPageVisible: Bool {
        guard let requested = startup.page else { return false }
        return loadedPage == requested
    }

    private func openOrganizer() {
        startup.openWorkspace()
        showsOrganizer = true
    }
}
