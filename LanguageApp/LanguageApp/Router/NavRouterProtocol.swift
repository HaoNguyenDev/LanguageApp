//
//  NavRouterProtocol.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//


import Foundation
import SwiftUI

protocol NavRouterProtocol: AnyObject {
    var path: NavigationPath { get set }
    
    func setRoot<T: Hashable>(to view: T)
    func push<T: Hashable>(_ view: T, animate: Bool)
    func pop(animate: Bool)
    func pop(to view: AnyHashable)
    func pop(to view: AnyHashable, animate: Bool)
    func popToRoot()
    func replaceLast<T: Hashable>(with view: T)
    func contains(_ subpath: AnyHashable) -> Bool
    func showSheet(_ view: RouterView)
    func showFullScreenCover(_ view: RouterView)
    func dismiss()
}
