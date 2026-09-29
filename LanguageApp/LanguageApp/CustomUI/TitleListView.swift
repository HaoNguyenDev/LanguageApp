//
//  TitleListView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

protocol TitleItem {
    var title: String { get }
}

struct TitleListView: View {
    @Environment(UserSettings.self) private var userSettings
    private let kDragDismissThreshold: CGFloat = 100
    private let kMaxOffset: CGFloat = 400
    
    @State private var isShow: Bool = false
    @State private var offset: CGFloat = 400
    @State private var opacity: CGFloat = 0

    let title: String
    let items: [TitleItem]
    var onDismiss: VoidResult?
    var onSelectItem: SingleResult<(Int, TitleItem)>?

    var body: some View {
        VStack(spacing: 16) {
            VStack {
                Text("swipe_down_to_exit".localized())
                    .setFont(.regular, size: 14, color: userSettings.theme.textColor)
                VStack(spacing: 16) {
                    Text(title)
                        .setFont(.bold, size: 24, color: userSettings.theme.textOnSubviewColor)

                    VStack(spacing: 16) {
                        ForEach(items.indices, id: \.self) { idx in
                            Text(items[idx].title)
                                .setFont(.regular, size: 16, color: userSettings.theme.textOnSubviewColor)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelectItem?((idx, items[idx]))
                                }
                            if idx < items.count - 1 {
                                Divider()
                                    .background(userSettings.theme.textOnSubviewColor)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .padding(EdgeInsets(top: 40, leading: 32, bottom: 40, trailing: 32))
                .frame(maxWidth: .infinity)
                .background(userSettings.theme.subviewBgColor, in: .rect(cornerRadius: 40))
            }
            .offset(y: offset)
            .opacity(opacity)
            .gesture(createDismissGesture())
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 10)
//        .background(theme.theme.subviewBgColor)
        .animation(.easeOut(duration: 0.2), value: offset)
        .animation(.easeOut(duration: 0.2), value: opacity)
        .onChange(of: isShow) { _, newValue in
            offset = newValue ? 0 : kMaxOffset
            opacity = newValue ? 1 : 0
            if !newValue {
                onDismiss?()
            }
        }
        .onAppear {
            // Add a slight delay to ensure the view is fully rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                isShow = true
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func createDismissGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = max(0, value.translation.height)
                offset = translation
                opacity = 1 - translation / kMaxOffset
            }
            .onEnded { value in
                isShow = value.translation.height < kDragDismissThreshold
                offset = isShow ? 0 : kMaxOffset
                opacity = isShow ? 1 : 0
            }
    }
}

#Preview {
    TitleListView(title: "List View", items: LanguageCode.allCases)
        .environment(UserSettings())
    
}
