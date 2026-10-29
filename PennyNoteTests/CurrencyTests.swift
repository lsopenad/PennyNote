import Foundation
import Testing
@testable import PennyNote

@MainActor
struct CurrencyTests {
    @Test(arguments: [
        ("12", AppCurrency.jpy, true),
        ("12.5", AppCurrency.jpy, false),
        ("12.50", AppCurrency.eur, true),
        ("12.505", AppCurrency.eur, false),
        ("1200", AppCurrency.cop, true),
    ])
    func fractionDigitsFollowTheCurrency(amount: String, currency: AppCurrency, isValid: Bool) throws {
        let value = try #require(Decimal(string: amount))
        #expect(ExpenseLimits.hasValidFractionDigits(value, for: currency) == isValid)
    }

    @Test func regionDefaultUsesTheRegionCurrencyOnlyIfListed() {
        #expect(AppCurrency.regionDefault(locale: Locale(identifier: "es_MX")) == .mxn)
        #expect(AppCurrency.regionDefault(locale: Locale(identifier: "en_GB")) == .gbp)
        #expect(AppCurrency.regionDefault(locale: Locale(identifier: "pt_BR")) == .eur)
    }

    @Test func storedCurrencyWinsOverFallback() throws {
        let defaults = try #require(UserDefaults(suiteName: "CurrencyTests.\(UUID())"))
        CurrencySettings(defaults: defaults).choose(.cad)

        #expect(CurrencySettings(defaults: defaults, fallback: .eur).currency == .cad)
    }

    @Test func choiceStaysPendingIfChangedWhileUploading() throws {
        let settings = CurrencySettings(defaults: try #require(UserDefaults(suiteName: "CurrencyTests.\(UUID())")))
        settings.choose(.usd)
        let uploaded = try #require(settings.pendingRow)

        settings.choose(.gbp)
        settings.markSynced(uploaded)

        #expect(settings.pendingRow?.currency == "GBP")
    }
}
