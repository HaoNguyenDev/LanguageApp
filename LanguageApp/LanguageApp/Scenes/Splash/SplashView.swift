//
//  SplashView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

struct SplashView: View {
    @Environment(UserSettings.self) var userSettings
    @Environment(AppSettings.self) var appSettings
    var onFinished: VoidResult?
    @State private var appear = false

    var body: some View {
        Group {
            if appSettings.isNeedUpdate {
                updateView
            } else {
                contentView
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension SplashView {
    @ViewBuilder
    var contentView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 88))
                .foregroundStyle(userSettings.theme.primaryColor)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(appear ? 1 : 0.6)
            Text("app_name".localized())
                .setFont(.bold, size: 36, color: userSettings.theme.primaryColor)
            Text("app_slogan".localized())
                .setFont(.regular, size: 16, color: userSettings.theme.secondaryTextColor, alignment: .center)
        }
        .opacity(appear ? 1 : 0)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
            try? await Task.sleep(for: .milliseconds(900))
            onFinished?()
        }
    }

    @ViewBuilder
    var updateView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("please_update".localized())
                .setFont(.bold, size: 28, color: userSettings.theme.textColor, alignment: .center)
            Text("update_the_app_now".localized())
                .setFont(.regular, size: 15, color: userSettings.theme.secondaryTextColor, alignment: .center)
            Spacer()
            Button("update".localized()) {
                // TODO: open App Store URL from AppVersion.urlStore
            }
            .filled(userSettings.theme.primaryColor)
            Button("skip".localized()) { onFinished?() }
                .buttonStyle(TextButtonStyle(color: userSettings.theme.secondaryTextColor))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
    }
}

#Preview {
    SplashView()
        .environment(AppSettings())
        .environment(UserSettings())
}
