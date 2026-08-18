import Foundation
import Testing

@testable import Chap

@Suite("ConfigFormatReference")
struct ConfigFormatReferenceTests {

    @Test("exampleJSON is valid JSON that decodes to Config")
    func exampleJSONDecodesToConfig() throws {
        let data = try #require(ConfigFormatReference.exampleJSON.data(using: .utf8))
        let config = try JSONDecoder().decode(Config.self, from: data)
        #expect(config.sites.count == 4)
    }

    @Test("exampleJSON contains all four launch types")
    func exampleJSONCoversAllLaunchTypes() throws {
        let data = try #require(ConfigFormatReference.exampleJSON.data(using: .utf8))
        let config = try JSONDecoder().decode(Config.self, from: data)
        let types = Set(config.sites.map(\.launchType))
        #expect(types.contains(.url))
        #expect(types.contains(.app))
        #expect(types.contains(.finder))
        #expect(types.contains(.shell))
    }

    @Test("exampleJSON passes import normalization without blocking issues")
    func exampleJSONPassesImportValidation() throws {
        let data = try #require(ConfigFormatReference.exampleJSON.data(using: .utf8))
        let config = try JSONDecoder().decode(Config.self, from: data)
        let result = normalizeForImport(sites: config.sites, connectedDisplays: [])
        #expect(result.blockingIssues.isEmpty)
    }

    @Test("fieldRequirements is not empty")
    func fieldRequirementsNotEmpty() {
        #expect(!ConfigFormatReference.fieldRequirements.isEmpty)
    }
}
