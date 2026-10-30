import Foundation
import Testing
@testable import PennyNote

@MainActor
struct AppLockTests {
    private let defaults: UserDefaults
    private let authenticator = FakeAuthenticator()
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "AppLockTests.\(UUID())"))
    }

    private func makeLock() -> AppLock {
        AppLock(defaults: defaults, authenticator: authenticator)
    }

    // Activado y desbloqueado, como queda tras encenderlo en Ajustes.
    private func makeEnabledLock(timeout: AppLockTimeout = .oneMinute) async -> AppLock {
        let lock = makeLock()
        await lock.setEnabled(true)
        lock.timeout = timeout
        authenticator.requests = 0
        return lock
    }

    @Test func isOffByDefault() {
        let lock = makeLock()

        #expect(!lock.isEnabled)
        #expect(!lock.isLocked)
        #expect(!lock.isShielded)
        #expect(lock.timeout == .oneMinute)
    }

    @Test func enablingNeedsToAuthenticate() async {
        authenticator.result = .failure
        let lock = makeLock()

        await lock.setEnabled(true)

        #expect(!lock.isEnabled)
        #expect(authenticator.requests == 1)
    }

    @Test func enabledLockLocksTheNextLaunch() async {
        _ = await makeEnabledLock(timeout: .fiveMinutes)

        let relaunched = makeLock()

        #expect(relaunched.isEnabled)
        #expect(relaunched.isLocked)
        #expect(relaunched.isShielded)
        #expect(relaunched.timeout == .fiveMinutes)
    }

    @Test func backgroundShieldsButReturningInTimeDoesNotAskAgain() async {
        let lock = await makeEnabledLock()

        lock.sceneDidEnterBackground(now: start)
        #expect(lock.isShielded)
        lock.sceneDidBecomeActive(now: start.addingTimeInterval(59))

        #expect(!lock.isLocked)
        #expect(!lock.isShielded)
        #expect(authenticator.requests == 0)
    }

    @Test(arguments: [(AppLockTimeout.oneMinute, 60.0), (.immediately, 0), (.fifteenMinutes, 900), (.oneMinute, -3600)])
    func returningAfterTheTimeoutAsksToUnlock(timeout: AppLockTimeout, elapsed: TimeInterval) async {
        let lock = await makeEnabledLock(timeout: timeout)

        lock.sceneDidEnterBackground(now: start)
        lock.sceneDidBecomeActive(now: start.addingTimeInterval(elapsed))
        await lock.automaticUnlock?.value

        #expect(authenticator.requests == 1)
        #expect(!lock.isLocked)
        #expect(!lock.isShielded)
    }

    @Test func cancellingFaceIDKeepsItLockedWithoutAskingAgainOnItsOwn() async {
        let lock = await makeEnabledLock(timeout: .immediately)
        authenticator.result = .failure

        lock.sceneDidEnterBackground(now: start)
        lock.sceneDidBecomeActive(now: start)
        await lock.automaticUnlock?.value
        // El aviso de Face ID desactiva la app y, al cerrarse, vuelve a activarla.
        lock.sceneDidBecomeActive(now: start)
        await lock.automaticUnlock?.value

        #expect(authenticator.requests == 1)
        #expect(lock.isLocked)
        #expect(lock.isShielded)
    }

    @Test func unlockingAfterLeavingAgainIsIgnored() async {
        let lock = await makeEnabledLock(timeout: .immediately)
        lock.sceneDidEnterBackground(now: start)
        lock.sceneDidBecomeActive(now: start)
        authenticator.onAuthenticate = { lock.sceneDidEnterBackground(now: start) }

        await lock.automaticUnlock?.value

        #expect(lock.isLocked)
        #expect(lock.isShielded)
    }

    @Test func withoutPasscodeTheAppOpensAndLocksAgainWhenItComesBack() async {
        let lock = await makeEnabledLock(timeout: .immediately)

        authenticator.method = .none
        lock.sceneDidEnterBackground(now: start)
        lock.sceneDidBecomeActive(now: start)
        #expect(!lock.isLocked)
        #expect(!lock.isShielded)
        #expect(!lock.canAuthenticate)

        authenticator.method = .faceID
        lock.sceneDidEnterBackground(now: start)
        lock.sceneDidBecomeActive(now: start)
        #expect(lock.isLocked)
    }

    @Test func resetTurnsItOffForTheNextAccount() async {
        let lock = await makeEnabledLock(timeout: .immediately)
        lock.sceneDidEnterBackground(now: start)

        lock.reset()

        #expect(!lock.isEnabled)
        #expect(!lock.isShielded)
        #expect(!makeLock().isEnabled)
        #expect(makeLock().timeout == .oneMinute)
    }

    @Test func notifiesTheShieldWhenItChanges() async {
        let lock = await makeEnabledLock()
        var changes = 0
        lock.onShieldChange = { changes += 1 }

        lock.sceneDidEnterBackground(now: start)
        lock.sceneDidEnterBackground(now: start)
        lock.sceneDidBecomeActive(now: start)

        #expect(changes == 2)
    }
}

@MainActor
private final class FakeAuthenticator: DeviceAuthenticator {
    var method = DeviceAuthMethod.faceID
    var result = DeviceAuthResult.success
    var requests = 0
    // Lo que pasa mientras se muestra el aviso de Face ID.
    var onAuthenticate: (() -> Void)?

    func availableMethod() -> DeviceAuthMethod {
        method
    }

    func authenticate(reason: String) async -> DeviceAuthResult {
        requests += 1
        onAuthenticate?()
        return result
    }
}
