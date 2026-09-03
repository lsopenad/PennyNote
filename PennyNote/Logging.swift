import os

// Loggers compartidos para no repetir el subsystem en cada fichero que necesita registrar un error.
enum Log {
    static let data = Logger(subsystem: "com.pennynote.app", category: "data")
    static let sync = Logger(subsystem: "com.pennynote.app", category: "sync")
}
