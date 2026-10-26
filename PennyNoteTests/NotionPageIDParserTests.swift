import Testing
@testable import PennyNote

struct NotionPageIDParserTests {
    private let expectedID = "0123abcd-4567-89ef-0123-456789abcdef"

    @Test func parsesBareID() {
        #expect(NotionPageIDParser.parse("0123abcd456789ef0123456789abcdef") == expectedID)
    }

    @Test func parsesDashedID() {
        #expect(NotionPageIDParser.parse(expectedID) == expectedID)
    }

    @Test func parsesFullURLTakingLast32HexCharacters() {
        let url = "https://www.notion.so/workspace/Mis-gastos-0123abcd456789ef0123456789abcdef"
        #expect(NotionPageIDParser.parse(url) == expectedID)
    }

    @Test(arguments: ["?pvs=4", "?v=fedcba9876543210fedcba9876543210&pvs=4", "#abc123"])
    func ignoresQueryAndFragment(_ suffix: String) {
        let url = "https://www.notion.so/Mis-gastos-0123abcd456789ef0123456789abcdef" + suffix
        #expect(NotionPageIDParser.parse(url) == expectedID)
    }

    @Test func trimsWhitespace() {
        #expect(NotionPageIDParser.parse("  0123abcd456789ef0123456789abcdef\n") == expectedID)
    }

    @Test(arguments: ["", "   ", "abc", "0123abcd456789ef0123456789abcde"])
    func rejectsInputWithoutEnoughHexCharacters(_ input: String) {
        #expect(NotionPageIDParser.parse(input) == nil)
    }
}
