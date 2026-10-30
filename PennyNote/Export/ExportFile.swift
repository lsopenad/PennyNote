import CoreTransferable
import Foundation

// Lo que se comparte desde Ajustes → Exportar. El fichero se genera cuando la hoja de compartir lo
// pide, no cada vez que cambia la pantalla.
struct ExportFile: Transferable, Sendable {
    let rows: [ExportRow]
    let format: ExportFormat
    let currency: AppCurrency
    // Sin extensión.
    let fileName: String
    let periodTitle: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: ExportFormat.excel.contentType) { file in
            SentTransferredFile(try file.write())
        }
        .exportingCondition { $0.format == .excel }

        FileRepresentation(exportedContentType: ExportFormat.csv.contentType) { file in
            SentTransferredFile(try file.write())
        }
        .exportingCondition { $0.format == .csv }
    }

    // Cada fichero va en su propia carpeta para conservar el nombre: la hoja de compartir puede
    // pedirlo más de una vez (vista previa y destino).
    func write() throws -> URL {
        let directory = Self.directory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let url = directory.appending(path: "\(fileName).\(format.fileExtension)", directoryHint: .notDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            switch format {
            case .csv:
                try CSVExporter.data(for: rows, currency: currency).write(to: url, options: .atomic)
            case .excel:
                try ExcelExporter.write(rows, to: url, currency: currency, periodTitle: periodTitle)
            }
        } catch {
            Log.data.error("No se pudo generar el fichero de exportación: \(error.localizedDescription)")
            throw error
        }
        return url
    }

    // Borra los ficheros de exportaciones anteriores. Se llama al abrir la pantalla, cuando no hay
    // ninguna hoja de compartir usándolos.
    static func removeTemporaryFiles() {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch CocoaError.fileNoSuchFile {
            // No había nada que borrar.
        } catch {
            Log.data.error("No se pudieron borrar las exportaciones anteriores: \(error.localizedDescription)")
        }
    }

    private static var directory: URL {
        FileManager.default.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)
    }
}
