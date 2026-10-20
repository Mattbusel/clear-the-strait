import AppIntents
import SwiftUI
import UserNotifications

@main
struct ClearTheStraitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        TipSetup.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Only here so a tapped daily reminder opens on today's strait.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let raw = response.notification.request.content.userInfo["route"] as? String, let r = Route(rawValue: raw) {
            Route.set(r)
            await MainActor.run {
                NotificationCenter.default.post(name: .routeWaiting, object: nil)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

extension Notification.Name {
    static let routeWaiting = Notification.Name("routeWaiting")
}

/// Siri, Spotlight and the Shortcuts app.
struct StraitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PlayDailyStraitIntent(),
                    phrases: ["Play the Daily Strait in \(.applicationName)",
                              "Start today's strait in \(.applicationName)",
                              "Open the Daily Strait in \(.applicationName)"],
                    shortTitle: "Daily Strait",
                    systemImageName: "calendar")
        AppShortcut(intent: OpenSeasonIntent(),
                    phrases: ["Open the season in \(.applicationName)",
                              "Show my season goals in \(.applicationName)"],
                    shortTitle: "Club Season",
                    systemImageName: "star.circle.fill")
    }
}
