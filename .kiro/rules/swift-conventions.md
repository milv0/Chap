# QuickAccess Swift Conventions

본 프로젝트의 Swift 코딩 규약. Apple Swift API Design Guidelines, Google Swift Style Guide, Kodeco Style Guide 기반.

## 1. Naming

- 타입/프로토콜: `UpperCamelCase`, 그 외 전부: `lowerCamelCase`
- 변수명은 타입이 아닌 역할로 짓는다 (`string` -> `siteURL`)
- Bool 은 `is-`/`has-`/`can-` 어서션 형태 (`isEmpty`, `hasValidURL`, `canResize`)
- Mutating 메서드는 명령형 동사 (`sort()`), nonmutating 은 `-ed`/`-ing` (`sorted()`)
- Factory 메서드는 `make` 접두사 (`makeStatusItem()`)
- 상수 네임스페이스는 caseless enum:
  ```swift
  enum Defaults {
      static let defaultWidth = 800
  }
  ```
- 약어는 위치에 따라 일관 casing (`urlString`, `HTMLParser`, `utf8Data`)
- Delegate 메서드 첫 인자는 unnamed source object

## 2. Code Organization

- `// MARK: -` 로 논리적 섹션 분리. 권장 순서:
  ```
  // MARK: - Constants
  // MARK: - Data Models
  // MARK: - Persistence
  // MARK: - App Delegate
  // MARK: - Site Launching
  // MARK: - Settings ViewModel
  // MARK: - SwiftUI Views
  // MARK: - Entry Point
  ```
- 프로토콜 conformance 는 별도 extension 으로 분리
- 타입 내부 선언 순서: nested types -> static props -> stored props -> computed props -> init -> lifecycle -> public/internal methods -> private methods
- 죽은 코드, super 만 호출하는 메서드, placeholder 주석 제거
- `import Cocoa` 가 있으면 `import Foundation` 중복 금지

## 3. Swift Idioms

- `guard` 로 early exit. happy path 는 들여쓰기 없이 유지
- `private` 기본 사용. `internal` 은 생략 (기본값). `fileprivate` 보다 `private` 선호
- `self.` 는 필수인 경우(escaping closure, initializer disambiguation)에만 사용
- 옵셔널 unwrap 시 같은 이름 shadow (`guard let button = statusItem.button`)
- `let` 기본. `var` 는 mutation 필요할 때만
- 데이터 모델은 struct (값 타입). identity/lifecycle 필요한 것만 class
- trailing closure 는 단일 마지막 클로저에만 사용
- shorthand 타입 문법: `[Element]`, `Int?`, `[String: Any]`
- 단일 표현식 computed property/closure 는 implicit return
- `!` force-unwrap, `try!` 는 provably safe 한 경우만 (주석 필수)
- `for-where` 사용 (`for site in sites where site.isValid`)

## 4. SwiftUI Patterns

- `body` 가 ~20 줄 넘으면 서브뷰 추출 (private computed property 또는 별도 struct)
- `@State` 는 항상 `private` 마크
- 공유 모델은 `@Observable` (macOS 14+) 또는 `ObservableObject`
- 서브뷰에는 필요한 최소 데이터만 전달 (`@Binding` 또는 직접 파라미터)
- 재사용 스타일은 `ViewModifier` 로 추출. 자체 `@State` 필요하면 반드시 ViewModifier 타입
- Container(레이아웃) = View struct, Decoration(스타일링) = modifier

## 5. AppKit + SwiftUI Interop

- SwiftUI 뷰는 `NSHostingController` 로 임베딩
- `NSStatusItem` 은 strong property 로 유지 (해제 방지)
- menu-bar-only 앱: `.accessory` activation policy
- 상태바 아이콘은 template image + `accessibilityDescription` 설정
- AppKit <-> SwiftUI 상태 전달은 Observable 모델 injection

## 6. Error Handling

- 복구/보고 가능하면 `do-catch`
- 실패 무시해도 되면 `try?`
- `try!` 는 프로덕션 코드에서 금지 (bundled resource, compile-time regex 등 증명 가능한 경우만 예외)
- 도메인 에러는 parent type 내 nested enum 으로 정의
- 비동기 성공/실패 전달은 `Result` 타입 사용

## 7. Architecture

- AppDelegate 책임: lifecycle, status item, menu construction, window management 만
- 비즈니스 로직은 dedicated type 으로 분리
- 데이터 흐름: Model -> ViewModel -> View (단방향). 뷰에서 모델 직접 mutation 금지
- `Codable` struct 는 순수 데이터 (side effect 메서드 없음)
- 500 줄 넘으면 extension 으로 논리적 분리
- class 는 `final` 기본. subclassing 의도 시에만 제거

## 8. Formatting

| 항목 | 규칙 |
|------|------|
| 들여쓰기 | 4 spaces |
| 줄 길이 | 100자 hard limit |
| 중괄호 | K&R (같은 줄에 `{`) |
| 세미콜론 | 사용 금지 |
| 여러 줄 배열/딕셔너리 | trailing comma 필수 |
| 조건문 괄호 | 생략 (`if x == 0`) |
| 빈 줄 | 메서드 사이 1줄, MARK 전후 1줄 |
| 주석 | `//` only (doc: `///`) |
| Void 반환 | 함수 선언은 생략, closure 타입은 `-> Void` 명시 |
| read-only computed | `get { }` wrapper 생략 |
| access control | 선두 위치 (`private let x`) |
