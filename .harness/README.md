# .harness — AI 어시스턴트 Harness

이 디렉토리는 Claude Code와 Kiro가 사용하는 모든 AI 어시스턴트 자산의 단일 출처(SSOT)다.

## 구조

```
.harness/
├── shared/rules/              ← 공유 규칙 (SSOT, 원본)
│   ├── commit-convention.md
│   ├── swift-conventions.md
│   └── swift-testing.md
├── claude/                    ← Claude Code 전용
│   ├── CLAUDE.md              ← 프로젝트 지침 (매 세션 자동 로드)
│   ├── commands/commit.md     ← /commit 슬래시 커맨드
│   └── rules/                 → symlink: ../shared/rules
└── kiro/                      ← Kiro 전용
    └── rules/                 → symlink: ../shared/rules
```

## 루트 심볼릭 링크

각 도구는 저장소 루트에서 자기 설정 디렉토리를 찾는다. 아래 심볼릭 링크로 연결:

```
.claude → .harness/claude
.kiro   → .harness/kiro
```

## 규칙 수정 방법

`.harness/shared/rules/` 의 파일만 수정하면 된다. 양쪽 도구가 심볼릭 링크를 통해 같은 파일을 읽으므로 두 곳을 따로 업데이트할 필요 없음.

## 도구별 전용 자산 추가

- Claude 전용 (commands, skills, settings): `.harness/claude/` 에 배치
- Kiro 전용 (hooks, specs, steering): `.harness/kiro/` 에 배치
