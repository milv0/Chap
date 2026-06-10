# QuickAccess Commit Convention

## 1. 변경 파일 안전 검토 (커밋 전 항상)

`git status` / `git diff --stat HEAD` 로 변경 범위를 확인한다. 다음 파일이 staged/unstaged 에 포함되면 **즉시 중단**하고 사용자에게 확인을 요청한다:

- `.env`, `.env.*`
- `credentials*`, `*.pem`, `*.key`, `id_rsa*`
- 시크릿으로 보이는 텍스트 (API 키, 토큰, 패스워드 등)

다음은 커밋에서 자동 제외:

- `.DS_Store`, `*.log`, `*.zip` (docs/ 제외)

## 2. Conventional Commit 메시지 형식

```
<type>(<scope>): <summary>

<body>

<footer>
```

### 2.1 type (필수)

| type | 사용 사례 |
|------|-----------|
| `feat` | 새 기능 구현 |
| `fix` | 기존 동작의 버그 수정 |
| `refactor` | 기능 변경 없는 구조 개선 |
| `test` | 테스트만 추가/수정 |
| `chore` | 빌드 스크립트, 설정, 도구류 |
| `docs` | 문서만 변경 (README, .kiro 등) |
| `ci` | CI/배포 관련 |
| `perf` | 성능 관련 |
| `style` | 포맷팅 등 동작 변경 없는 스타일 |
| `release` | 버전 릴리스 |
| `ui` | UI/UX 변경 (SwiftUI 뷰 수정) |

### 2.2 scope (필수)

변경 파일 경로 비중이 가장 큰 영역 하나만 사용.

| 경로/영역 | scope |
|-----------|-------|
| `QuickAccess.swift` (AppDelegate, 핵심 로직) | `app` |
| `QuickAccess.swift` (SwiftUI 뷰) | `ui` |
| `QuickAccess.swift` (Config/Site 모델) | `model` |
| `build.sh`, `install.sh` | `build` |
| `docs/`, `index.html` | `docs` |
| `.kiro/` | `kiro` |
| `.claude/`, `CLAUDE.md` | `claude` |
| 여러 영역 광범위 | `repo` |

### 2.3 summary 규칙

- **영문**. 한글 포함 시 재작성.
- 최대 72자 (subject 줄 전체 길이).
- 소문자로 시작, 마침표로 끝나지 않음.
- 명령형 동사 (예: `add`, `move`, `fix`, `refactor`, `drop`).

### 2.4 body (선택, 권장)

- **영문**.
- 3~5 bullets. "왜 변경했는가" 중심.

### 2.5 footer (선택)

- BREAKING CHANGE 가 있으면 `BREAKING CHANGE: <설명>` 줄로 표시.

## 3. 절대 금지 표현

커밋 메시지에 다음을 포함하지 않는다:

- `Co-authored-by:` / `Co-Authored-By:` 라인 (대소문자 불문)
- "Generated with ...", "Built with ...", "Authored by ...", "Powered by ..." 같은 도구 attribution 문구
- 모든 이모지 (subject, body, footer 전부)

## 4. 언어 검증 (필수)

최종 메시지에 한글(U+AC00~U+D7A3, U+1100~U+11FF, U+3130~U+318F) 또는 CJK 문자가 포함되면 재작성.

예외: 파일 경로, API 이름, 고유명사는 원문 유지.

## 5. 실행 방식

heredoc 으로 호출:

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

- <bullet 1>
- <bullet 2>

<footer>
EOF
)"
```

## 6. 실패 처리

- **pre-commit hook 실패**: hook 출력을 사용자에게 보고. `--no-verify` 금지. 원인 수정 후 새 커밋 생성 (`--amend` 사용 금지).
- **변경사항 없음**: "변경사항 없음" 보고 후 종료.

## 7. push 정책

- `git push` 는 사용자가 **명시적으로 요청한 경우에만** 실행. 커밋 직후 자동 push 금지.
- `main` 브랜치로 force push 는 사용자 요청 시에도 한 번 더 확인.

## 8. PR 제목

PR 제목도 §2.3 subject 규칙을 따른다:

- 형식: `<type>(<scope>): <summary>`
- 영문 72자 이하, 소문자 시작, 마침표 없음, 명령형 동사
- 여러 type 이 섞인 PR 은 가장 영향력 있는 type 사용: `feat` > `fix` > `perf` > `refactor` > 그 외
