---
description: .claude/rules/commit-convention.md 규약에 맞춘 Conventional Commit 을 생성한다. 변경이 여러 의미 단위면 쪼개서 커밋한다. AI/에이전트 attribution 금지, Co-authored-by 금지, 영문 ≤72자.
allowed-tools: Bash, Read
---

# Conventional Commit

본 커맨드의 메시지 규약은 다음 SSOT 가 정의한다:

@../rules/commit-convention.md

위 import 가 인입되지 않으면 즉시 `Read('.claude/rules/commit-convention.md')` 로 직접 로드한 뒤 진행한다.

## 절차

1. **변경 파일 안전 검토** — SSOT §1 의 sensitive 파일 목록을 적용. `git status` / `git diff --stat HEAD` 로 확인.
   - 시크릿 파일 감지 시 즉시 중단, 사용자에게 보고.
   - `.DS_Store`, `*.log`, `*.zip` 는 staging 에서 제외.

2. **커밋 단위 분석** — 변경 파일 목록과 diff 를 분석해 의미적으로 구분되는 단위를 식별한다.

   분리 기준:
   - **type 이 다르면** 반드시 분리 (feat + fix → 2 커밋)
   - **scope 이 다르면** 분리 권장 (app + docs → 2 커밋)
   - **같은 type/scope 이라도** 독립적 변경이면 분리 (버그 A 수정 + 버그 B 수정 → 2 커밋)

   분리하지 않는 경우:
   - 하나의 기능을 구성하는 여러 파일 변경 (모델 + 뷰 + 테스트 = 1 커밋)
   - 리팩토링의 일부로 여러 파일에 걸친 rename

   분석 결과를 사용자에게 보고:
   ```
   변경 분석:
   1. feat(app): ... — AppDelegate.swift, Models.swift
   2. docs(docs): ... — README.md
   3. chore(repo): ... — .gitignore
   ```
   사용자 확인 후 순서대로 커밋 진행. 단일 커밋이 적절하면 바로 진행.

3. **빌드 검증** — Swift 소스 변경이 포함된 경우에만:
   ```bash
   xcodebuild -project QuickAccess.xcodeproj -scheme QuickAccess -configuration Debug -destination "platform=macOS" build 2>&1 | tail -3
   ```
   - 실패하면 커밋 진행하지 않고 에러 보고 후 종료.
   - Swift 소스 변경이 없으면 (문서, 설정만 변경) 생략.

4. **type / scope 결정** — SSOT §2.1, §2.2 의 매핑 표를 따른다.

5. **메시지 작성** — SSOT §2.3 (subject) + §2.4 (body) + §2.5 (footer) + §3 (금지 표현) + §4 (언어 검증).
   - subject ≤ 72 chars 확인.
   - body 영문 + bullets 3~5.
   - footer 는 BREAKING CHANGE 가 있을 때만.

6. **커밋 실행** — 각 단위별로 해당 파일만 staging 후 커밋:
   ```bash
   git add <해당 단위의 파일들>
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <subject>

   - <bullet 1>
   - <bullet 2>
   - <bullet 3>
   EOF
   )"
   ```
   여러 단위면 위 과정을 반복.

7. **결과 보고** — 각 커밋에 대해 해시, subject, 변경 파일 수를 한국어로 보고.
   ```
   커밋 1: abc1234 feat(app): add multi-monitor support — 3개 파일
   커밋 2: def5678 docs(docs): update README — 1개 파일
   ```

8. **push 하지 않는다** — SSOT §7. 사용자가 명시적으로 요청한 경우에만 push.

## 변경이 없는 경우

`git status` 가 깨끗하면 "변경사항 없음으로 커밋 skip" 한 줄만 보고하고 종료.

## 사후 검증

모든 커밋 완료 후 마지막 커밋에 대해 attribution 패턴 누출 검사:

```bash
git log -1 --format=%B | grep -iE "co-authored-by:|generated with|built with|authored by|powered by" && \
  echo "[WARN] attribution 패턴 감지 — 메시지 재작성 필요" >&2 || \
  echo "[OK] 메시지 규약 준수"
```

매치되면 사용자에게 즉시 보고하고 revert + 새 커밋으로 정정 제안.

## 실패 처리

- **빌드 실패**: 에러 메시지 보고 후 종료. 자동 수정 시도 금지.
- **pre-commit hook 실패**: hook 출력 보고. `--no-verify` 금지. 원인 수정 후 새 커밋 (`--amend` 금지).
