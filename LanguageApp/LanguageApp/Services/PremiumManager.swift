//
//  PremiumManager.swift
//  LanguageApp
//
//  StoreKit 2 subscriptions ("LinguaPath Plus").
//  Create matching auto-renewable subscriptions in App Store Connect
//  (or a local .storekit configuration file for testing).
//

import Foundation
import Observation
import StoreKit

@Observable final class PremiumManager {
    static let productIds: [String] = [
        "com.haonguyen.app.LanguageApp.plus.monthly",
        "com.haonguyen.app.LanguageApp.plus.yearly"
    ]

    private(set) var products: [Product] = []
    private(set) var isPremium = false
    private(set) var isLoadingProducts = false
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    func start() async {
        listenForTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: Self.productIds).sorted { $0.price < $1.price }
        } catch {
            Logger.shared.error("Load products failed: \(error)")
        }
    }

    /// - Returns: true if the purchase completed.
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            Logger.shared.error("Restore failed: \(error)")
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIds.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPremium = active
    }

    private func listenForTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
