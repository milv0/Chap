import Testing

@testable import Chap

@Suite("Menu rebuild gate")
struct MenuRebuildGateTests {
    @Test("rebuilds immediately while the menu is closed")
    func closedRebuildsImmediately() {
        var gate = MenuRebuildGate()
        let shouldBuild = gate.request()
        #expect(shouldBuild)
        #expect(!gate.isTracking)
    }

    @Test("requests while open coalesce into one rebuild after close")
    func openRequestsCoalesce() {
        var gate = MenuRebuildGate()
        gate.didOpen()
        let first = gate.request()
        let second = gate.request()
        let afterClose = gate.didClose()
        let afterSecondClose = gate.didClose()
        #expect(!first)
        #expect(!second)
        #expect(afterClose)
        #expect(!afterSecondClose)
    }

    @Test("closing without a request does not rebuild")
    func closeWithoutRequest() {
        var gate = MenuRebuildGate()
        gate.didOpen()
        let shouldBuild = gate.didClose()
        #expect(!shouldBuild)
    }
}
