//
//  ScreenCoordinator.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import SwiftUI

protocol ScreenCoordinator {
    associatedtype ScreenRouter
    associatedtype Screen: View

    var navRouter: NavRouterProtocol { get set }
    @ViewBuilder
    func viewForRouter(router: ScreenRouter) -> Screen
}
