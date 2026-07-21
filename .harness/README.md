# .harness - AI Assistant Harness

This directory is the project home for assistant-specific configuration used by
Claude Code, Kiro, and Codex.

## Structure

```text
.harness/
├── shared/                    # Shared rules and hooks
│   ├── rules/
│   │   ├── architecture-docs.md
│   │   ├── commit-convention.md
│   │   ├── swift-conventions.md
│   │   └── swift-testing.md
│   └── hooks/
│       └── swift-format.sh    # Format/lint edited Swift files
├── claude/
│   ├── CLAUDE.md              # Claude Code project instructions
│   ├── settings.json          # Permissions and PostToolUse hook
│   ├── commands/commit.md     # /commit command
│   └── rules -> ../shared/rules
├── kiro/
│   ├── steering/project.md    # Kiro project steering
│   ├── hooks/
│   │   └── swift-format-on-edit.kiro.hook
│   └── rules -> ../shared/rules
└── codex/
    └── AGENTS.md              # Codex project instructions
```

## Root Links

Each tool discovers its entry point from the repository root:

```text
.claude -> .harness/claude
.kiro   -> .harness/kiro
AGENTS.md -> .harness/codex/AGENTS.md
```

## Shared Rules

Update common rules in `.harness/shared/rules/`. Claude and Kiro expose those
rules through `rules` symlinks. Codex references the same files from `AGENTS.md`.

## Tool-Specific Assets

- Claude-specific commands, settings, and future skills belong in `.harness/claude/`.
- Kiro hooks, specs, and steering files belong in `.harness/kiro/`.
- Codex project instructions, project agents, or project config belong in `.harness/codex/`.
