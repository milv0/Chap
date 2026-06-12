import Testing

@testable import QuickAccess

@Suite("Domain Validation")
struct DomainValidationTests {
    @Test(arguments: [
        ("google.com", true),
        ("sub.domain.co.uk", true),
        ("valid-host_name.123", true),
        ("a", true),
        ("evil<script>", false),
        ("has space", false),
        ("", false),
        ("with/slash", false),
        ("quote\"mark", false),
    ])
    func domainValidation(domain: String, shouldPass: Bool) {
        #expect(isValidDomain(domain) == shouldPass)
    }
}

@Suite("Chrome Bounds")
struct ChromeBoundsTests {
    @Test func calculatesCorrectBoundsString() {
        let bounds = chromeBoundsString(x: 100, y: 200, width: 800, height: 600)
        #expect(bounds == "100, 200, 900, 800")
    }

    @Test func handlesZeroOrigin() {
        let bounds = chromeBoundsString(x: 0, y: 0, width: 1920, height: 1080)
        #expect(bounds == "0, 0, 1920, 1080")
    }

    @Test func handlesSmallWindow() {
        let bounds = chromeBoundsString(x: 50, y: 50, width: 100, height: 100)
        #expect(bounds == "50, 50, 150, 150")
    }
}
