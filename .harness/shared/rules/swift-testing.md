# Chap Testing Convention

Swift Testing 프레임워크(`import Testing`) 기반. XCTest 가 아닌 `@Test`/`@Suite` 사용.

## 1. Test Structure

- 테스트 파일은 `Tests/` 디렉토리에 배치. 소스 구조를 미러링:
  ```
  Tests/
    ModelTests.swift
    SettingsViewModelTests.swift
    ValidationTests.swift
  ```
- `@Suite` 로 관련 테스트 그룹화. Suite 이름은 테스트 대상 타입 또는 행위:
  ```swift
  @Suite("Config Codable")
  struct ConfigCodableTests { ... }
  ```
- Tag 로 카테고리 분류 (선택적 실행용):
  ```swift
  extension Tag {
      @Tag static var model: Self
      @Tag static var viewModel: Self
      @Tag static var validation: Self
  }
  ```

## 2. Naming

- `@Test` 함수명은 **행위를 설명하는 문장** (camelCase, 동사 또는 조건으로 시작):
  ```swift
  @Test func decodesConfigWithMissingRunInBackground()
  @Test func hasChangesReturnsTrueAfterModifyingSites()
  @Test func rejectsDomainWithSpecialCharacters()
  ```
- `test` 접두사 금지 — `@Test` attribute 가 이미 표시함
- "and" 가 필요하면 테스트를 분리

## 3. Swift Testing Idioms

- `#expect(_:)` — 실패해도 나머지 검증 계속:
  ```swift
  #expect(site.name == "GitHub")
  #expect(site.width == 800)
  ```
- `#require(_:)` — 전제조건. 실패 시 테스트 즉시 중단:
  ```swift
  let site = try #require(JSONDecoder().decode(Site.self, from: data))
  ```
- `@Test("display name")` — 함수명만으로 부족할 때 설명 문자열 추가
- `@Test(arguments:)` — 동일 로직을 여러 입력으로 테스트:
  ```swift
  @Test(arguments: [
      ("google.com", true),
      ("evil<script>", false),
      ("", false),
  ])
  func domainValidation(domain: String, shouldPass: Bool) { ... }
  ```

## 4. What to Test

테스트 대상 (UI 불필요한 순수 로직):
- **Codable 모델** — encode/decode, 누락 키 기본값, round-trip
- **ViewModel 상태** — `hasChanges`, `markSaved()`, 상태 전이
- **Validation 로직** — 도메인 정규식, URL 검증
- **순수 계산** — bounds 문자열 생성, layout preset 좌표 계산

## 5. What NOT to Test

- SwiftUI `body` computed property, View 레이아웃, 색상/폰트
- `NSWindow` 생성/크기/순서
- `NSStatusItem`, 메뉴 구성
- `NSAlert` 표시
- `Process` 실행 (mock interface 사용)
- Apple 프레임워크 자체 동작 (JSONDecoder 가 동작하는지 등)

## 6. Test Pattern

Arrange-Act-Assert (AAA) 구조. 구간 분리는 빈 줄:

```swift
@Test func boundsStringCalculatesCorrectly() {
    let x = 100, y = 200, width = 800, height = 600

    let bounds = chromeBoundsString(x: x, y: y, width: width, height: height)

    #expect(bounds == "100, 200, 900, 800")
}
```

## 7. Dependency Injection

- 외부 의존성(파일시스템, UserDefaults, Process)은 protocol 로 추상화:
  ```swift
  protocol ConfigPersistence {
      func load(from path: String) throws -> Data
      func save(_ data: Data, to path: String) throws
  }
  ```
- 테스트에서는 mock/stub 구현 주입
- ViewModel 테스트는 `onSave`/`onReload` 콜백으로 side effect 검증

## 8. Test Execution

XcodeGen/Xcode 프로젝트 기준으로 실행:

```bash
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
```

현재 저장소에는 `Package.swift`가 없다. `swift test`를 사용하지 말고
`Chap.xcodeproj`의 `Chap` scheme을 테스트한다.

## 9. Testability를 위한 코드 분리

테스트 가능하게 하려면 앱 타겟 의존성이 적은 로직을 `Sources/ChapCore/`로 둔다:
- `Sources/ChapCore/Models.swift` — `Site`, `Config`, `LaunchType`, `Defaults`
- `Sources/ChapCore/SettingsViewModel.swift` — `SettingsViewModel`
- `Sources/ChapCore/Validation.swift` — `isValidDomain(_:)`, `targetScreen(for:)`, `centeredBounds(for:on:)`
- `Sources/Chap/` — AppDelegate, launchers, SwiftUI views (직접 테스트 대상 아님)

순수 로직을 free function 또는 static method 로 추출하면 의존성 없이 테스트 가능:
```swift
func isValidDomain(_ domain: String) -> Bool { ... }
func centeredBounds(for site: Site, on screen: NSScreen) -> (left: Int, top: Int, right: Int, bottom: Int) { ... }
```
