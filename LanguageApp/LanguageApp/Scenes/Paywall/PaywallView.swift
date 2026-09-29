//
//  PaywallView.swift
//  LanguageApp
//
//  "LinguaPath Plus" subscription screen (StoreKit 2).
//

import SwiftUI
import StoreKit

struct PaywallCoordinator: View {
    var navRouter: any NavRouterProtocol

    var body: some View {
        PaywallView(onClose: { navRouter.dismiss() })
    }
}

struct PaywallView: View {
    @Environment(UserSettings.self) private var userSettings
    @Environment(PremiumManager.self) private var premium
    @Environment(GamificationManager.self) private var gamification
    var onClose: VoidResult?

    @State private var selectedProductId: String?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private let benefits: [(icon: String, key: String)] = [
        ("heart.fill", "plus_benefit_hearts"),
        ("rectangle.stack.fill", "plus_benefit_reviews"),
        ("sparkles", "plus_benefit_early_access")
    ]

    var body: some View {
        let theme = userSettings.theme
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { onClose?() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(LinearGradient(colors: [theme.xpColor, theme.streakColor],
                                                        startPoint: .top, endPoint: .bottom))
                    Text("plus_title".localized())
                        .setFont(.bold, size: 30, color: theme.textColor, alignment: .center)
                    Text("plus_subtitle".localized())
                        .setFont(.regular, size: 16, color: theme.secondaryTextColor, alignment: .center)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.key) { benefit in
                            HStack(spacing: 14) {
                                Image(systemName: benefit.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(theme.primaryColor)
                                    .frame(width: 28)
                                Text(benefit.key.localized())
                                    .setFont(.semibold, size: 16, color: theme.textColor)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.cardBgColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    products
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            VStack(spacing: 10) {
                if let errorMessage {
                    Text(errorMessage)
                        .setFont(.regular, size: 13, color: theme.wrongColor, alignment: .center)
                }
                Button {
                    purchase()
                } label: {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("subscribe".localized())
                    }
                }
                .filled(theme.primaryColor)
                .disabled(selectedProduct == nil || isPurchasing || premium.isPremium)

                Button("restore_purchases".localized()) {
                    Task { await premium.restorePurchases() }
                }
                .buttonStyle(TextButtonStyle(color: theme.secondaryTextColor))

                Text("subscription_terms".localized())
                    .setFont(.regular, size: 11, color: theme.secondaryTextColor, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .setDefaultBackground()
        .task {
            if premium.products.isEmpty { await premium.loadProducts() }
            if selectedProductId == nil { selectedProductId = premium.products.last?.id }
        }
        .onChange(of: premium.isPremium) { _, isPremium in
            if isPremium {
                gamification.refillAll()
                onClose?()
            }
        }
    }

    private var selectedProduct: Product? {
        premium.products.first { $0.id == selectedProductId }
    }

    @ViewBuilder
    private var products: some View {
        let theme = userSettings.theme
        if premium.isLoadingProducts {
            ProgressView()
        } else if premium.products.isEmpty {
            Text("products_unavailable".localized())
                .setFont(.regular, size: 14, color: theme.secondaryTextColor, alignment: .center)
        } else {
            VStack(spacing: 12) {
                ForEach(premium.products, id: \.id) { product in
                    Button {
                        selectedProductId = product.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.displayName).font(mainFont.bold(17))
                                Text(product.description).font(mainFont.regular(13)).opacity(0.8)
                            }
                            Spacer()
                            Text(product.displayPrice).font(mainFont.bold(17))
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(OptionButtonStyle(state: product.id == selectedProductId ? .selected : .normal))
                }
            }
        }
    }

    private func purchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        errorMessage = nil
        Task {
            defer { isPurchasing = false }
            do {
                _ = try await premium.purchase(product)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(UserSettings())
        .environment(PremiumManager())
        .environment(GamificationManager())
}
