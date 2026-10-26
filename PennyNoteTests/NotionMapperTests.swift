import Foundation
import Testing
@testable import PennyNote

struct NotionMapperTests {
    // MARK: - Propiedades de página

    @Test func propertiesEncodeAllDomainFields() throws {
        let date = try #require(DateComponents(calendar: .current, year: 2026, month: 3, day: 15, hour: 12).date)
        let properties = NotionMapper.properties(
            amount: Decimal(string: "19.99")!,
            date: date,
            title: "Café",
            paymentMethod: .cash,
            categoryName: "Comida"
        )

        #expect(titleContent(in: properties) == "Café")
        let amount = try #require(nested(properties, NotionPropertyName.amount, "number") as? Double)
        #expect(abs(amount - 19.99) < 0.000_001)
        #expect(nested(properties, NotionPropertyName.date, "date", "start") as? String == "2026-03-15")
        #expect(nested(properties, NotionPropertyName.paymentMethod, "select", "name") as? String == "Efectivo")
        #expect(nested(properties, NotionPropertyName.category, "select", "name") as? String == "Comida")
    }

    @Test func propertiesUseFallbackTitleWhenEmpty() {
        let properties = NotionMapper.properties(amount: 1, date: .now, title: "", paymentMethod: .card, categoryName: nil)
        #expect(titleContent(in: properties) == "Gasto")
    }

    @Test func propertiesOmitCategoryWhenNil() {
        let properties = NotionMapper.properties(amount: 1, date: .now, title: "x", paymentMethod: .card, categoryName: nil)
        #expect(properties[NotionPropertyName.category] == nil)
    }

    // MARK: - Esquema de base de datos

    @Test func databaseSchemaDeclaresEveryProperty() {
        let schema = NotionMapper.databaseSchemaProperties(categoryNames: ["Comida", "Ocio"])
        #expect(Set(schema.keys) == [
            NotionPropertyName.title,
            NotionPropertyName.amount,
            NotionPropertyName.date,
            NotionPropertyName.category,
            NotionPropertyName.paymentMethod,
        ])
        #expect(nested(schema, NotionPropertyName.amount, "number", "format") as? String == "euro")
        #expect(selectOptionNames(schema, NotionPropertyName.category) == ["Comida", "Ocio"])
        #expect(selectOptionNames(schema, NotionPropertyName.paymentMethod) == PaymentMethod.allCases.map(\.rawValue))
    }

    @Test func categorySchemaOnlyDeclaresSelectProperties() {
        let schema = NotionMapper.categorySchemaProperties(categoryNames: ["Hogar"])
        #expect(Set(schema.keys) == [NotionPropertyName.category, NotionPropertyName.paymentMethod])
        #expect(selectOptionNames(schema, NotionPropertyName.category) == ["Hogar"])
        #expect(selectOptionNames(schema, NotionPropertyName.paymentMethod) == PaymentMethod.allCases.map(\.rawValue))
    }

    // MARK: - Parseo de páginas

    @Test func parsesCompletePage() throws {
        let page = try #require(NotionMapper.parsePage(pageJSON()))

        #expect(page.id == "page-1")
        #expect(page.lastEditedTime == NotionMapper.parseISODate("2026-03-15T10:30:00.000Z"))
        #expect(page.archived == false)
        #expect(page.title == "Cena")
        #expect(page.amount == Decimal(string: "19.99"))
        #expect(page.paymentMethod == .transfer)
        #expect(page.categoryName == "Ocio")
        #expect(NotionMapper.isoDateOnly(page.date) == "2026-03-14")
    }

    @Test func parsesArchivedFlag() throws {
        var json = pageJSON()
        json["archived"] = true
        #expect(try #require(NotionMapper.parsePage(json)).archived)
    }

    @Test func roundsAmountToCents() throws {
        let page = try #require(NotionMapper.parsePage(pageJSON(amount: 10.005_000_1)))
        #expect(page.amount == Decimal(string: "10.01"))
    }

    @Test func fallsBackWhenOptionalPropertiesAreMissing() throws {
        var json = pageJSON()
        json["properties"] = [String: Any]()
        let page = try #require(NotionMapper.parsePage(json))

        #expect(page.title == "")
        #expect(page.amount == 0)
        #expect(page.paymentMethod == .card)
        #expect(page.categoryName == nil)
        #expect(abs(page.date.timeIntervalSinceNow) < 60)
    }

    @Test func fallsBackToCardForUnknownPaymentMethod() throws {
        let page = try #require(NotionMapper.parsePage(pageJSON(paymentMethod: "Bizum")))
        #expect(page.paymentMethod == .card)
    }

    @Test(arguments: ["id", "last_edited_time", "properties"])
    func rejectsPageWithoutRequiredField(_ field: String) {
        var json = pageJSON()
        json[field] = nil
        #expect(NotionMapper.parsePage(json) == nil)
    }

    // MARK: - Fechas ISO

    @Test func parsesISODateWithAndWithoutFractionalSeconds() {
        let withFraction = NotionMapper.parseISODate("2026-03-15T10:30:00.000Z")
        let plain = NotionMapper.parseISODate("2026-03-15T10:30:00Z")
        #expect(withFraction != nil)
        #expect(withFraction == plain)
        #expect(NotionMapper.parseISODate("15/03/2026") == nil)
    }

    @Test func formatsISODateTimeInUTC() throws {
        let date = try #require(NotionMapper.parseISODate("2026-03-15T10:30:00Z"))
        #expect(NotionMapper.isoDateTime(date) == "2026-03-15T10:30:00Z")
    }

    // MARK: - Ayudas

    private func pageJSON(amount: Double = 19.99, paymentMethod: String = "Transferencia") -> [String: Any] {
        [
            "id": "page-1",
            "last_edited_time": "2026-03-15T10:30:00.000Z",
            "archived": false,
            "properties": [
                NotionPropertyName.title: ["title": [["plain_text": "Cena"]]],
                NotionPropertyName.amount: ["number": amount],
                NotionPropertyName.date: ["date": ["start": "2026-03-14"]],
                NotionPropertyName.category: ["select": ["id": "opt-1", "name": "Ocio"]],
                NotionPropertyName.paymentMethod: ["select": ["name": paymentMethod]],
            ] as [String: Any],
        ]
    }

    private func nested(_ dictionary: [String: Any], _ keys: String...) -> Any? {
        var current: Any? = dictionary
        for key in keys {
            current = (current as? [String: Any])?[key]
        }
        return current
    }

    private func titleContent(in properties: [String: Any]) -> String? {
        let titleArray = nested(properties, NotionPropertyName.title, "title") as? [[String: Any]]
        return (titleArray?.first?["text"] as? [String: Any])?["content"] as? String
    }

    private func selectOptionNames(_ schema: [String: Any], _ property: String) -> [String]? {
        let options = nested(schema, property, "select", "options") as? [[String: Any]]
        return options?.compactMap { $0["name"] as? String }
    }
}
