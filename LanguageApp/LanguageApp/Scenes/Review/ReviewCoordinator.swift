//
//  ReviewCoordinator.swift
//  LanguageApp
//

import SwiftUI

struct ReviewCoordinator: View {
    var navRouter: any NavRouterProtocol

    var body: some View {
        ReviewView(
            onStartReview: { courseId, practice in
                navRouter.showFullScreenCover(RouterView(routable: Router.Study.review(courseId: courseId, practice: practice)))
            },
            onShowWords: { courseId in
                navRouter.push(Router.MainTab.wordList(courseId: courseId), animate: true)
            }
        )
        .toolbar(.hidden, for: .navigationBar)
    }
}
