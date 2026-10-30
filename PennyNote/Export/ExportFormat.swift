import Foundation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case excel
    case csv

    var id: String { rawValue }

    // Nombres de formato: no se traducen.
    var title: String {
        switch self {
        case .excel: "Excel"
        case .csv: "CSV"
        }
    }

    var fileExtension: String {
        switch self {
        case .excel: "xlsx"
        case .csv: "csv"
        }
    }

    var contentType: UTType {
        switch self {
        case .excel: UTType("org.openxmlformats.spreadsheetml.sheet") ?? .spreadsheet
        case .csv: .commaSeparatedText
        }
    }
}
