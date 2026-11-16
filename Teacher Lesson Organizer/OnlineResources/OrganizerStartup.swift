import AdjustSdk
import AdSupport
import AppTrackingTransparency
import Combine
import UIKit
import UserNotifications

final class OrganizerStartup: ObservableObject {
    private enum Screen {
        case loading
        case workspace
        case resource(URL)
    }

    @Published private var screen = Screen.loading
    @Published private(set) var hasOpenedWorkspace = false

    private let cache = ResourceCache.standard
    private var started = false
    private var directoryTask: Task<Void, Never>?
    private var workspaceRequested = false

    var page: URL? {
        if case .resource(let address) = screen { return address }
        return nil
    }

    func start() {
        guard !started else { return }
        started = true
        if !workspaceRequested, !cache.hasQueuedNotice, let saved = cache.lastPage {
            screen = .resource(saved)
        }
        updateResources()
    }

    func openWorkspace() {
        workspaceRequested = true
        showWorkspace()
    }

    func openResourceNotification() {
        workspaceRequested = false
        updateResources()
    }

    private func updateResources() {
        guard directoryTask == nil else { return }
        directoryTask = Task {
            repeat {
                await refreshPage()
            } while cache.hasQueuedNotice
            directoryTask = nil
        }
    }

    private func refreshPage() async {
        let request = await ResourceRegistration(cache: cache).prepareRequest()
        do {
            if let destination = try await ResourceDirectoryClient(cache: cache).destination(for: request) {
                cache.lastPage = destination
                if !workspaceRequested { screen = .resource(destination) }
                return
            }
        } catch {
            print("Teacher Lesson Organizer: could not resolve destination")
        }

        guard !workspaceRequested, page == nil else { return }
        if let saved = cache.lastPage {
            screen = .resource(saved)
        } else {
            showWorkspace()
        }
    }

    private func showWorkspace() {
        hasOpenedWorkspace = true
        screen = .workspace
    }
}

private struct ResourceRegistration {
    let cache: ResourceCache

    func prepareRequest() async -> ResourceRequest {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        UIApplication.shared.registerForRemoteNotifications()

        try? await Task.sleep(for: .milliseconds(500))
        await requestTrackingIfActive()
        await waitForRegistration()

        let notice = cache.takeNotice()
        let campaign = cache.campaignParameters
        let registration = cache.registrationToken ?? "null"
        let attribution = await Adjust.adid(withTimeout: 1_000) ?? ""
        let advertising = ATTrackingManager.trackingAuthorizationStatus == .authorized
            ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : ""

        return ResourceRequest(
            campaign: campaign,
            registrationToken: registration,
            attributionID: attribution,
            advertisingID: advertising,
            hardware: UIDevice.current.model,
            notice: notice
        )
    }

    private func requestTrackingIfActive() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        for _ in 0..<10 {
            if UIApplication.shared.applicationState == .active { break }
            try? await Task.sleep(for: .milliseconds(300))
        }
        if UIApplication.shared.applicationState == .active {
            _ = await Adjust.requestAppTrackingAuthorization()
        }
    }

    private func waitForRegistration() async {
        for _ in 0..<15 {
            if cache.campaignSnapshot != nil, cache.registrationToken != nil { return }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
