//
//  NavRouter.swift
//  LanguageApp
//
//  Created by Hao Nguyen on 12/7/25.
//


import SwiftUI
import Foundation

@Observable final class NavRouter: NavRouterProtocol {
    // Keep deinit nonisolated. With MainActor default isolation the compiler emits an
    // isolated (MainActor) deinit; on an iOS 17 deployment target it goes through the
    // swift_task_deinitOnExecutor back-deploy shim, which crashes on iOS 26 with
    // "malloc: pointer being freed was not allocated" (seen in LessonSessionViewModelTests).
    nonisolated deinit {}

    var path: NavigationPath = NavigationPath() {
        didSet {
            // System back button / swipe-back shrink `path` directly → drop stale children.
            if children.count > path.count {
                children.removeLast(children.count - path.count)
            }
        }
    }
    var sheet: RouterView?
    var fullScreenCover: RouterView?
    private var children: [AnyHashable] = []
}

// MARK: - Methods
extension NavRouter {
    // Values must be appended to `path` with their concrete type. `NavigationPath` keys
    // `navigationDestination(for:)` by the static type of the appended value, so appending an
    // `AnyHashable` finds no destination and SwiftUI shows a blank screen with a yellow warning icon.
    func setRoot<T: Hashable>(to view: T) {
        path = .init()
        children.removeAll()
        path.append(view)
        children.append(view)
    }
    
    func push<T: Hashable>(_ view: T, animate: Bool = true) {
        var transaction = Transaction(animation: .linear)
        transaction.disablesAnimations = !animate
        
        withTransaction(transaction) {
            path.append(view)
        }
        children.append(view)
    }
    
    func pop(animate: Bool = true) {
        guard !children.isEmpty else { return }
        var transaction = Transaction(animation: .linear)
        transaction.disablesAnimations = !animate
        
        withTransaction(transaction) {
            children.removeLast()
            path.removeLast()
        }
    }
    
    func pop(to subpath: AnyHashable) {
        guard !children.isEmpty else { return }
        
        while contains(subpath) {
            children.removeLast()
            path.removeLast()
        }
    }
    
    func pop(to view: AnyHashable, animate: Bool) {
        if animate {
            self.pop(to: view)
        } else {
            var transaction = Transaction(animation: .linear)
            transaction.disablesAnimations = !animate
            
            withTransaction(transaction) {
                self.pop(to: view)
            }
        }
    }
    
    func popToRoot() {
        while path.count > 1 {
            children.removeLast(children.count)
            path.removeLast(path.count)
        }
    }
    
    func replaceLast<T: Hashable>(with view: T) {
        guard !children.isEmpty else {
            path.append(view)
            children.append(view)
            return
        }
        children.removeLast()
        path.removeLast()

        path.append(view)
        children.append(view)
    }
    
    func contains(_ subpath: AnyHashable) -> Bool {
        children.last != subpath && children.contains(subpath)
    }
    
    func showSheet(_ view: RouterView) {
        sheet = view
    }
    
    func showFullScreenCover(_ view: RouterView) {
        fullScreenCover = view
    }
    
    func dismiss() {
        sheet = nil
        fullScreenCover = nil
    }
}
