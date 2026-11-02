import Foundation
import Testing
import UIKit
@testable import PennyNote

@MainActor
struct CurrencyTests {
    @Test(arguments: [
        ("12", AppCurrency.jpy, true),
        ("12.5", AppCurrency.jpy, false),
        ("12.50", AppCurrency.eur, true),
        ("12.505", AppCurrency.eur, false),
        ("1200", AppCurrency.cop, true),
        ("1.125", AppCurrency.kwd, true),
        ("1.1255", AppCurrency.kwd, false),
    ])
    func fractionDigitsFollowTheCurrency(amount: String, currency: AppCurrency, isValid: Bool) throws {
        let value = try #require(Decimal(string: amount))
        #expect(ExpenseLimits.hasValidFractionDigits(value, for: currency) == isValid)
    }

    @Test func regionDefaultUsesTheRegionCurrency() {
        #expect(AppCurrency.regionDefault(locale: Locale(identifier: "es_MX")) == .mxn)
        #expect(AppCurrency.regionDefault(locale: Locale(identifier: "en_GB")) == .gbp)
        #expect(AppCurrency.regionDefault(locale: Locale(identifier: "pt_BR")) == .brl)
    }

    @Test func regionDefaultFallsBackToEuroWithoutRegion() {
        #expect(AppCurrency.regionDefault(locale: Locale(identifier: "es")) == .eur)
    }

    // Como un iOS 18 en Bulgaria, que aún da la leva.
    @Test func regionDefaultSkipsReplacedCurrencies() {
        let locale = Locale(identifier: "bg_BG@currency=BGN")
        #expect(locale.currency?.identifier == "BGN")
        #expect(AppCurrency.regionDefault(locale: locale) == .eur)
    }

    @Test func catalogOffersTheCurrenciesInUseOnly() {
        let codes = Set(AppCurrency.all.map(\.rawValue))

        #expect(codes == Set(Locale.commonISOCurrencyCodes).subtracting(AppCurrency.replacedCodes))
        #expect(codes.isSuperset(of: ["EUR", "USD", "BRL", "INR", "KWD", "XCG"]))
        // Peseta y oro: ISO, pero no en uso.
        #expect(!codes.contains("ESP"))
        #expect(!codes.contains("XAU"))
        // Kuna: iOS aún la da por común, pero la sustituyó el euro.
        #expect(!codes.contains("HRK"))
    }

    @Test(arguments: ["ESP", "HRK"])
    func retiredCurrencyIsStillAccepted(code: String) throws {
        let currency = try #require(AppCurrency(rawValue: code))
        #expect(currency.rawValue == code)
    }

    @Test(arguments: ["", "eur", "EURO", "XYZ", "E1R"])
    func unknownCodeIsRejected(code: String) {
        #expect(AppCurrency(rawValue: code) == nil)
    }

    @Test func storedRetiredCurrencyIsRespected() throws {
        let defaults = try #require(UserDefaults(suiteName: "CurrencyTests.\(UUID())"))
        defaults.set("HRK", forKey: AppGroupConstants.Keys.currency)

        #expect(CurrencySettings(defaults: defaults, fallback: .eur).currency.rawValue == "HRK")
    }

    // Detecta erratas en el mapa: un nombre que no existe dejaría el icono vacío en la pantalla de
    // bloqueo si no fuera por el billete de respaldo.
    @Test func symbolNamesExist() {
        let missing = Set(AppCurrency.symbolBaseNames.values).filter { UIImage(systemName: "\($0).circle") == nil }
        #expect(missing.isEmpty)
        #expect(UIImage(systemName: AppCurrency.fallbackSymbolName) != nil)
    }

    @Test func currencyWithoutOwnSignUsesTheBanknote() throws {
        let currency = try #require(AppCurrency(rawValue: "AED"))
        #expect(currency.symbolName == AppCurrency.fallbackSymbolName)
        #expect(AppCurrency.eur.symbolName == "eurosign.circle")
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
