---
description: .claude/rules/commit-convention.md 규약에 맞춘 Conventional Commit 을 생성한다. AI/에이전트 attribution 금지, Co-authored-by 금지, 영문 ≤72자.
allowed-tools: Bash, Read
---

# Conventional Commit

본 커맨드의 메시지 규약은 다음 SSOT 가 정의한다:

@../rules/commit-convention.md

위 import 가 인입되지 않으면 즉시 `Read('.claude/rules/commit-convention.md')` 로 직접 로드한 뒤 진행한다.

## 절차

1. **변경 파일 안전 검토** — SSOT §1 의 sensitive 파일 목록을 적용. `git status` / `git diff --stat HEAD` 로 확인.
   - 시크릿 파일 감지 시 즉시 중단, 사용자에게 보고.
   - `.DS_Store`, `*.log`, `*.zip` (docs/ 제외) 는 staging 에서 제외.

2. **빌드 검증** — 커밋 전 컴파일 확인:
   ```bash
   swiftc QuickAccess.swift -o /dev/null -target arm64-apple-macosx14.0 -framework Cocoa -framework SwiftUI 2>&1
   ```
   - 실패하면 커밋 진행하지 않고 에러 보고 후 종료.
   - 통과하면 다음 단계.

3. **type / scope 결정** — SSOT §2.1, §2.2 의 매핑 표를 따른다.

4. **메시지 작성** — SSOT §2.3 (subject) + §2.4 (body) + §2.5 (footer) + §3 (금지 표현) + §4 (언어 검증).
   - subject ≤ 72 chars 확인.
   - body 영문 + bullets 3~5.
   - footer 는 BREAKING CHANGE 가 있을 때만.

5. **커밋 실행** — SSOT §5 의 heredoc 형식:
   ```bash
   git add <relevant files>
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <subject>

   - <bullet 1>
   - <bullet 2>
   - <bullet 3>
   EOF
   )"
   ```
   - `git add -A` 대신 관련 파일만 명시적으로 staging.

6. **결과 보고** — `git log -1 --stat` 출력에서 커밋 해시, subject, 변경 파일 수만 한국어로 한 줄.

7. **push 하지 않는다** — SSOT §7. 사용자가 명시적으로 요청한 경우에만 push.

## 변경이 없는 경우

`git status` 가 깨끗하면 "변경사항 없음으로 커밋 skip" 한 줄만 보고하고 종료.

## 사후 검증

커밋 직후 attribution 패턴 누출 검사:

```bash
git log -1 --format=%B | grep -iE "co-authored-by:|generated with|built with|authored by|powered by" && \
  echo "[WARN] attribution 패턴 감지 — 메시지 재작성 필요" >&2 || \
  echo "[OK] 메시지 규약 준수"
```

매치되면 사용자에게 즉시 보고하고 revert + 새 커밋으로 정정 제안.

## 실패 처리

- **빌드 실패**: 에러 메시지 보고 후 종료. 자동 수정 시도 금지.
- **pre-commit hook 실패**: hook 출력 보고. `--no-verify` 금지. 원인 수정 후 새 커밋 (`--amend` 금지).
