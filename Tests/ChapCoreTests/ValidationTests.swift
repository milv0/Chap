import Testing

@testable import Chap

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
