import Foundation
import Testing
@testable import PennyNote

struct AppGroupConstantsTests {
    // Instalada desde Xcode: el grupo con el que se compila, en la app y en el widget.
    @Test(arguments: ["com.pennynote.app", "com.pennynote.app.widget"])
    func usesTheBuiltGroupWhenTheBundleIsNotResigned(bundleIdentifier: String) {
        #expect(AppGroupConstants.resolveIdentifier(infoDictionary: [:], bundleIdentifier: bundleIdentifier) == "group.com.pennynote.app")
    }

    // Instalada con AltStore sin ALTAppGroups: el grupo lleva el mismo sufijo que el identificador.
    @Test(arguments: ["com.pennynote.app.3875E33454", "com.pennynote.app.3875E33454.widget"])
    func addsTheAltStoreSuffixOfTheBundleIdentifier(bundleIdentifier: String) {
        #expect(AppGroupConstants.resolveIdentifier(infoDictionary: [:], bundleIdentifier: bundleIdentifier) == "group.com.pennynote.app.3875E33454")
    }

    @Test func prefersTheGroupThatAltStoreWritesInTheInfoPlist() {
        let infoDictionary: [String: Any] = ["ALTAppGroups": ["group.com.other", "group.com.pennynote.app.ABCDE12345"]]

        #expect(AppGroupConstants.resolveIdentifier(infoDictionary: infoDictionary, bundleIdentifier: "com.pennynote.app.3875E33454") == "group.com.pennynote.app.ABCDE12345")
    }

    @Test func takesTheOnlyAltStoreGroupEvenWithAnotherName() {
        let infoDictionary: [String: Any] = ["ALTAppGroups": ["group.renamed"]]

        #expect(AppGroupConstants.resolveIdentifier(infoDictionary: infoDictionary, bundleIdentifier: "com.pennynote.app") == "group.renamed")
    }

    @Test(arguments: [nil, "com.other.app", "com.pennynote.application"] as [String?])
    func usesTheBuiltGroupForUnknownBundleIdentifiers(bundleIdentifier: String?) {
        #expect(AppGroupConstants.resolveIdentifier(infoDictionary: ["ALTAppGroups": [String]()], bundleIdentifier: bundleIdentifier) == "group.com.pennynote.app")
    }
}
