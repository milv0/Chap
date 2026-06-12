import Foundation
import Testing
@testable import QuickAccess

@Suite("Site Model")
struct SiteModelTests {
    @Test func roundTripsIdentically() throws {
        let original = Site(name: "Test", url: "https://example.com", width: 400, height: 200, x: 50, y: 50)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Site.self, from: data)

        #expect(decoded == original)
    }

    @Test func decodesAllFields() throws {
        let json = #"{"name":"GitHub","url":"https://github.com","width":800,"height":600,"x":100,"y":100}"#
        let site = try JSONDecoder().decode(Site.self, from: Data(json.utf8))

        #expect(site.name == "GitHub")
        #expect(site.url == "https://github.com")
        #expect(site.width == 800)
        #expect(site.height == 600)
        #expect(site.x == 100)
        #expect(site.y == 100)
        #expect(site.displayName == nil)
    }

    @Test func decodesWithDisplayName() throws {
        let json = #"{"name":"Work","url":"https://work.com","width":800,"height":600,"x":0,"y":0,"displayName":"Built-in Retina Display"}"#
        let site = try JSONDecoder().decode(Site.self, from: Data(json.utf8))

        #expect(site.displayName == "Built-in Retina Display")
    }
}

@Suite("Config Model")
struct ConfigModelTests {
    @Test("defaults runInBackground to true when key is missing")
    func defaultsRunInBackground() throws {
        let json = #"{"sites":[]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))

        #expect(config.runInBackground == true)
    }

    @Test func respectsExplicitRunInBackground() throws {
        let json = #"{"runInBackground":false,"sites":[]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))

        #expect(config.runInBackground == false)
    }

    @Test func decodesMultipleSites() throws {
        let json = #"{"sites":[{"name":"A","url":"https://a.com","width":100,"height":100,"x":0,"y":0},{"name":"B","url":"https://b.com","width":200,"height":200,"x":10,"y":10}]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))

        #expect(config.sites.count == 2)
        #expect(config.sites[0].name == "A")
        #expect(config.sites[1].name == "B")
    }

    @Test func roundTripsWithAllFields() throws {
        let original = Config(
            runInBackground: false,
            sites: [Site(name: "X", url: "https://x.com", width: 500, height: 300, x: 20, y: 30)]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)

        #expect(decoded.runInBackground == original.runInBackground)
        #expect(decoded.sites == original.sites)
    }
}

@Suite("LaunchType")
struct LaunchTypeTests {
    @Test func defaultsToURLWhenMissing() throws {
        let json = #"{"name":"Old","url":"https://old.com","width":800,"height":600,"x":0,"y":0}"#
        let site = try JSONDecoder().decode(Site.self, from: Data(json.utf8))

        #expect(site.launchType == .url)
        #expect(site.appPath == nil)
        #expect(site.script == nil)
    }

    @Test func decodesAppType() throws {
        let json = #"{"name":"Slack","url":"","width":800,"height":600,"x":0,"y":0,"launchType":"app","appPath":"/Applications/Slack.app"}"#
        let site = try JSONDecoder().decode(Site.self, from: Data(json.utf8))

        #expect(site.launchType == .app)
        #expect(site.appPath == "/Applications/Slack.app")
    }

    @Test func decodesShellType() throws {
        let json = #"{"name":"Deploy","url":"","width":800,"height":600,"x":0,"y":0,"launchType":"shell","script":"echo hello"}"#
        let site = try JSONDecoder().decode(Site.self, from: Data(json.utf8))

        #expect(site.launchType == .shell)
        #expect(site.script == "echo hello")
    }

    @Test func roundTripsAppType() throws {
        let original = Site(name: "App", url: "", width: 800, height: 600, x: 0, y: 0,
                            launchType: .app, appPath: "/Applications/Safari.app")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Site.self, from: data)

        #expect(decoded == original)
    }

    @Test func roundTripsShellType() throws {
        let original = Site(name: "Script", url: "", width: 800, height: 600, x: 0, y: 0,
                            launchType: .shell, script: "ls -la\necho done")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Site.self, from: data)

        #expect(decoded == original)
    }
}
