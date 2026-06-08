# QuickAccess — Claude Code 작업 지침

이 파일은 Claude Code 가 매 세션 자동 로드하는 프로젝트 지침이다.

## Rules 참조

상세 규약은 `.claude/rules/` 하위 파일을 SSOT 로 따른다:

| 파일 | 내용 |
|------|------|
| `commit-convention.md` | 커밋 메시지 규약 (Conventional Commit, 금지 표현, push 정책) |
| `swift-conventions.md` | Swift 코딩 컨벤션 (naming, 구조, idioms, 아키텍처, 포맷팅) |
| `swift-testing.md` | 테스팅 규약 (Swift Testing, 테스트 대상/비대상, SPM 구조) |

## 핵심 요약

### Commit
- `<type>(<scope>): <summary>` 형식 (영문, 72자 이내)
- scope 필수: `app`, `ui`, `model`, `build`, `docs`, `claude`, `repo`
- 이모지 금지, 한글 금지, AI attribution 금지
- `Co-Authored-By` 자동 footer 무효
- push 는 사용자 명시적 요청 시에만

### Swift
- 4 spaces 들여쓰기, 100자 줄 제한, K&R 중괄호
- `guard` early exit, `private` 기본, `self.` 최소화
- 데이터 모델은 struct, lifecycle 있는 것만 class (`final` 기본)
- SwiftUI `body` 20줄 넘으면 서브뷰 추출, `@State`는 항상 `private`
- AppDelegate 는 lifecycle/menu/window 만, 비즈니스 로직은 분리

### Testing
- Swift Testing (`@Test`/`@Suite`) 사용, `swift test` 로 실행
- 테스트 대상: Codable 모델, ViewModel 상태, validation, 순수 계산
- 테스트 안 함: SwiftUI body, NSWindow, NSAlert, Process 실행
- AAA 패턴 (Arrange-Act-Assert), 하나의 테스트 = 하나의 행위
