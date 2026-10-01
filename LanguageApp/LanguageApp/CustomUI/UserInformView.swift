//
//  UserInformView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI
import UIKit

struct InformAction {
    let title: String
    let callback: VoidResult?
}

struct UserInformView: View {
    @Environment(UserSettings.self) private var userSettings
    let message: UserMessageItem
    
    @State private var isShow: Bool = false
    private var primaryAction: InformAction?
    private var secondaryAction: InformAction?
    
    init(message: UserMessageItem, primaryAction: InformAction? = nil, secondaryAction: InformAction? = nil) {
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        
    }
    
    var body: some View {
        VStack {
            VStack {
                if let icon = message.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .frame(width: 120, height: 120)
                } else if message.animation != nil {
                    LoadingView(hideText: true, loadingOnSubview: true)
                        .frame(width: 100, height: 100)
//                    LottieHelperView(fileName: animation.name, playLoopMode: animation.loop)
//                        .frame(width: 120, height: 120)
                }
                
                VStack(spacing: 16) {
                    if let title = message.title {
                        Text(title)
                            .setFont(.bold, size: 24.0, color: userSettings.theme.textOnSubviewColor)
                            .foregroundStyle(message.type.color)
                    }
                    if let message = message.message {
                        Text(message)
                            .setFont(.regular, size: 14.0, color: userSettings.theme.textOnSubviewColor)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let attributeMessage = message.attributeMessage {
                        Text(attributeMessage)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(spacing: 16) {
                        // Primary action
                        if let primaryAction {
                            Button(action: {
                                primaryAction.callback?()
                            },
                                   label: {
                                Text(primaryAction.title)
                                    .setFont(.regular, size: 14, color: userSettings.theme.textOnSubviewColor)
                                    .frame(height: 48)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(lineWidth: 1)
                                            .foregroundStyle(userSettings.theme.textOnSubviewColor)
                                    )
                            })
                        }
                        
                        // Secondary action
                        if let secondaryAction {
                            Button(action: {
                                secondaryAction.callback?()
                            },
                                   label: {
                                Text(secondaryAction.title)
                                    .setFont(.regular, size: 14, color: userSettings.theme.textOnSubviewColor)
                                    .frame(height: 48)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(lineWidth: 1)
                                            .foregroundStyle(userSettings.theme.textOnSubviewColor)
                                    )
                            })
                        }
                    }
                }
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(
                userSettings.theme.subviewBgColor
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .opacity(isShow ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .setDefaultBackground()
        .animation(.linear(duration: 0.3), value: isShow)
        .onAppear {
            isShow = true
        }
    }
}

#Preview {
//    UserInformView(message: UserMessageItem(message: "onboarding_welcome_title".localized()),
//                   primaryAction: InformAction(title: "test", callback: {}))
//    .environmentObject(ThemeManager())
    
    UserInformView(message: UserMessageItem(message: "onboarding_welcome_title".localized()),
                   primaryAction: InformAction(title: "test", callback: {}))
    .environment(UserSettings())
}
