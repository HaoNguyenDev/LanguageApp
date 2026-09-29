//
//  BackgroundAnimation.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//


import SwiftUI

struct BackgroundAnimation: View {
    @State private var startAnimation = false
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.3)
                ]),
                startPoint: startAnimation ? .topLeading : .bottomTrailing,
                endPoint: startAnimation ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                    startAnimation.toggle()
                }
            }
        }
    }
}

#Preview {
    BackgroundAnimation()
}
