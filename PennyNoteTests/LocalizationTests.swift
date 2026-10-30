import Foundation
import Testing
@testable import PennyNote

// Los tests se ejecutan dentro de la app, así que Bundle.main es PennyNote.app.
struct LocalizationTests {
    // El español es el idioma de las claves, pero no el de respaldo (el inglés). Si el catálogo no
    // tiene los textos en español escritos, no se genera es.lproj/Localizable.strings y con el
    // iPhone en español la app sale en inglés (le pasó a la 1.3.0).
    @Test(arguments: ["es", "en", "zh-Hans"])
    func everyLanguageHasItsStringsTable(language: String) throws {
        let path = try #require(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: language))
        let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String])

        #expect(table["Ajustes"] != nil)
    }

    @Test func spanishTextIsTheKeyItself() throws {
        let path = try #require(Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "es"))
        let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String])

        #expect(table["Ajustes"] == "Ajustes")
        #expect(table.count > 150)
    }

    // El aviso de permiso de Face ID sale del Info.plist, que se traduce en InfoPlist.xcstrings.
    @Test(arguments: ["es", "en", "zh-Hans"])
    func faceIDUsageDescriptionIsTranslated(language: String) throws {
        let path = try #require(Bundle.main.path(forResource: "InfoPlist", ofType: "strings", inDirectory: nil, forLocalization: language))
        let table = try #require(NSDictionary(contentsOfFile: path) as? [String: String])

        #expect(table["NSFaceIDUsageDescription"]?.isEmpty == false)
    }
}
