import Foundation
import Testing

@testable import Chap

@Suite("ConfigImportProcessor")
struct ConfigImportProcessorTests {
    @Test("valid JSON returns normalized config")
    func validJSON() throws {
        let source = Config(
            showGuideWindow: false, launchAtLogin: true, optionShortcutsEnabled: false,
            statusBarIcon: .lightning,
            sites: [
                Site(name: "Example", url: "https://example.com", width: 80, height: 600)
            ])
        let data = try JSONEncoder().encode(source)

        guard
            case .success(let processed) = ConfigImportProcessor.process(
                data: data, connectedDisplays: [])
        else {
            Issue.record("Expected successful import")
            return
        }
        #expect(processed.config.sites[0].width == 100)
        #expect(processed.config.showGuideWindow == false)
        #expect(processed.config.launchAtLogin)
        #expect(!processed.config.optionShortcutsEnabled)
        #expect(processed.config.statusBarIcon == .lightning)
        #expect(!processed.fixes.isEmpty)
    }

    @Test("invalid JSON returns decode failure")
    func invalidJSON() {
        let result = ConfigImportProcessor.process(
            data: Data("{not json".utf8), connectedDisplays: [])
        guard case .decodeFailed(let message) = result else {
            Issue.record("Expected decode failure")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test("blocking validation issues reject the import")
    func blockingIssue() throws {
        let source = Config(sites: [
            Site(name: "", url: "https://example.com", width: 800, height: 600)
        ])
        let result = ConfigImportProcessor.process(
            data: try JSONEncoder().encode(source), connectedDisplays: [])

        guard case .blocked(_, let issues) = result else {
            Issue.record("Expected blocked import")
            return
        }
        #expect(issues.contains { $0.field == .name })
    }
}
