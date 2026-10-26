import os

// Loggers compartidos para no repetir el subsystem en cada fichero que necesita registrar un error.
enum Log {
    static let data = Logger(subsystem: "com.pennynote.app", category: "data")
    static let sync = Logger(subsystem: "com.pennynote.app", category: "sync")
    static let security = Logger(subsystem: "com.pennynote.app", category: "security")
    static let widget = Logger(subsystem: "com.pennynote.app", category: "widget")
}
