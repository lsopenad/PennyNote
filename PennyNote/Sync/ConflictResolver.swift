import Foundation

enum ConflictResolver {
    // Last-write-wins puro por timestamp: gana quien haya editado más tarde.
    static func remoteWins(localLastModified: Date, remoteLastEditedTime: Date) -> Bool {
        remoteLastEditedTime > localLastModified
    }
}
