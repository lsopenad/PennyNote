import Foundation

// Acepta tanto la URL completa de la página de Notion pegada por el usuario como el ID pelado.
enum NotionPageIDParser {
    static func parse(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hexChars = trimmed.filter { $0.isHexDigit }
        guard hexChars.count >= 32 else { return nil }
        let last32 = Array(hexChars.suffix(32))

        return [
            String(last32[0..<8]),
            String(last32[8..<12]),
            String(last32[12..<16]),
            String(last32[16..<20]),
            String(last32[20..<32]),
        ].joined(separator: "-")
    }
}
