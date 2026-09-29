//
//  Route.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//

import Foundation

struct RouterView: Identifiable {
    let id = UUID()
    let routable: any Routable
}

protocol Routable: Identifiable, Hashable {
    var id: String { get }
}

enum Router {}

extension Router {
    static let homeRouter = Router.Splash.home
}
