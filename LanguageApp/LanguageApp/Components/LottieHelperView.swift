//
//  LottieHelperView.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//


import SwiftUI
import UIKit
import Lottie

struct LottieHelperView: View {
    let fileName: String
    let contentMode: UIView.ContentMode = .scaleAspectFit
    var playLoopMode: LottieLoopMode = .loop
    var onAnimationFinished: (() -> Void)?

    var body: some View {
        LottieView(animation: .named(fileName))
        .configure({ view in
            view.contentMode = contentMode
        })
        .playbackMode(.playing(.toProgress(1, loopMode: playLoopMode)))
        .animationDidFinish { _ in
            onAnimationFinished?()
        }
    }
}
