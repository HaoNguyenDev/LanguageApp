//
//  NotificationPermissionAlert.swift
//  LanguageApp
//
//  When notifications are turned off for the app, iOS never shows its permission dialog again:
//  the learner has to allow them in Settings. This alert explains it and opens the right page.
//  The banner is shown in Settings while a reminder option is on but notifications are off.
//

import SwiftUI

struct NotificationPermissionAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert("notification_off_title".localized(), isPresented: $isPresented) {
            Button("open_settings".localized()) {
                if let url = NotificationManager.settingsURL { openURL(url) }
            }
            Button("not_now".localized(), role: .cancel) {}
        } message: {
            Text("notification_off_message".localized())
        }
    }
}

extension View {
    /// Alert with an "Open Settings" button for when notifications are turned off.
    func notificationPermissionAlert(isPresented: Binding<Bool>) -> some View {
        modifier(NotificationPermissionAlert(isPresented: isPresented))
    }
}

/// Warning row: reminders are on in the app but notifications are off in iOS Settings.
struct NotificationPermissionBanner: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(\.openURL) private var openURL

    var body: some View {
        let theme = userSettings.theme
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(theme.wrongColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text("notification_off_banner".localized())
                    .setFont(.semibold, size: 14, color: theme.textColor)
                    .fixedSize(horizontal: false, vertical: true)
                Button("open_settings".localized()) {
                    if let url = NotificationManager.settingsURL { openURL(url) }
                }
                .font(mainFont.bold(14))
                .foregroundStyle(theme.primaryColor)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(theme.wrongBgColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}
