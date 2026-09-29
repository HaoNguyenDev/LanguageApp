//
//  CustomAlertView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//


import SwiftUI

struct CustomAlertView: View {
    let title: String
    let message: String
    let confirmText: String?
    let cancelText: String?
    let onConfirm: VoidResult?
    let onCancel: VoidResult?

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            HStack {
                if let cancelText = cancelText {
                    Button(cancelText) {
                        onCancel?()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)

                }
                if let confirmText = confirmText {
                    Button(confirmText) {
                        onConfirm?()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal, 40)
        .shadow(radius: 10)
    }
}
