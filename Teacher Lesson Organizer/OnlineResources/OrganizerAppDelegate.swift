import AdjustSdk
import Combine
import AppTrackingTransparency
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class OrganizerAppDelegate: NSObject, ObservableObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    @Published private(set) var selectedReminder: UUID?

    private let campaignToken = "vbnp2d7xx4hs"
    private let campaignRecorder = OrganizerAttribution()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = ResourceCache.standard.installationIdentifier
        _ = ResourceCache.standard.clientIdentifier

        FirebaseApp.configure()
        if let project = FirebaseApp.app()?.options.googleAppID {
            ResourceCache.standard.useMessagingProject(project)
        }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true

        if let config = ADJConfig(appToken: campaignToken, environment: ADJEnvironmentProduction) {
            config.delegate = campaignRecorder
            config.logLevel = .info
            Adjust.initSdk(config)
        }

        if let payload = options?[.remoteNotification] as? [AnyHashable: Any] {
            ResourceCache.standard.enqueueNotice(identifier: Self.noticeIdentifier(in: payload))
        }
        return true
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
        Self.retainRegistration(token)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Messaging.messaging().apnsToken = token
        Messaging.messaging().token { token, error in
            if error != nil {
                print("Teacher Lesson Organizer: could not refresh messaging registration")
                return
            }
            Self.retainRegistration(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Teacher Lesson Organizer: APNs registration failed")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.trigger is UNPushNotificationTrigger {
            Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.banner, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let notification = response.notification.request
        let payload = notification.content.userInfo
        guard notification.trigger is UNPushNotificationTrigger else {
            if let value = payload["entryID"] as? String, let id = UUID(uuidString: value) {
                DispatchQueue.main.async {
                    self.selectedReminder = id
                }
            }
            completionHandler()
            return
        }
        Messaging.messaging().appDidReceiveMessage(payload)
        let identifier = Self.noticeIdentifier(in: payload)
        DispatchQueue.main.async {
            ResourceCache.standard.enqueueNotice(identifier: identifier)
            NotificationCenter.default.post(name: ResourceCache.noticeSelected, object: nil)
        }
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification payload: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Messaging.messaging().appDidReceiveMessage(payload)
        completionHandler(.newData)
    }

    func clearSelectedReminder() {
        selectedReminder = nil
    }

    private static func retainRegistration(_ raw: String?) {
        guard let token = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }
        ResourceCache.standard.registrationToken = token
    }

    private static func noticeIdentifier(in object: Any) -> String? {
        if let payload = object as? [AnyHashable: Any] {
            for key in ["push_id", "gcm.notification.push_id"] {
                guard let value = payload[key] else { continue }
                let identifier = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
                if !identifier.isEmpty { return identifier }
            }
            for key in ["push_data", "data"] {
                if let value = payload[key], let identifier = noticeIdentifier(in: value) {
                    return identifier
                }
            }
        } else if let text = object as? String,
                  let data = text.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: data) {
            return noticeIdentifier(in: payload)
        }
        return nil
    }
}

private final class OrganizerAttribution: NSObject, AdjustDelegate {
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        guard let attribution, ATTrackingManager.trackingAuthorizationStatus != .notDetermined else { return }

        guard let values = attribution.jsonResponse, JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values) else {
            ResourceCache.standard.campaignSnapshot = nil
            return
        }
        ResourceCache.standard.campaignSnapshot = String(data: data, encoding: .utf8)
    }
}
