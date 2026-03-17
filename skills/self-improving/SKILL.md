---
name: self-improving
description: Self-reflection + Self-criticism + Self-learning + Self-organizing memory. Agent evaluates its own work, catches mistakes, and improves permanently. Use before starting work and after responding to the user.
metadata:
  version: 2.0.0
  displayName: Self-Improving Agent (With Self-Reflection)
  homepage: https://clawic.com/skills/self-improving
  changelog: "Refactored to coding-agent-only runtime and standardized steering integration."
  memoryRoot: "~/self-improving/"
  supportsCodingAgentsOnly: true
  platforms:
    - claude-code
    - codex
    - gemini
    - opencode
---

## When to Use

User corrects you or points out mistakes. You complete significant work and want to evaluate the outcome. You notice something in your own output that could be better. Knowledge should compound over time without manual maintenance.

## Architecture

Memory lives in `~/self-improving/` with tiered structure. If `~/self-improving/` does not exist, run `setup.md`.

```
~/self-improving/
├── memory.md          # HOT: ≤100 lines, always loaded
├── index.md           # Topic index with line counts
├── projects/          # Per-project learnings
├── domains/           # Domain-specific (code, writing, comms)
├── archive/           # COLD: decayed patterns
└── corrections.md     # Last 50 corrections log
```

## Quick Reference

| Topic                | File                                |
| -------------------- | ----------------------------------- |
| Setup guide          | `setup.md`                          |
| Platform integration | `setup.md` (Cross-platform section) |
| Memory template      | `memory-template.md`                |
| Learning mechanics   | `learning.md`                       |
| Security boundaries  | `boundaries.md`                     |
| Scaling rules        | `scaling.md`                        |
| Memory operations    | `operations.md`                     |
| Self-reflection log  | `reflections.md`                    |

## Cross-Platform Activation Contract

To support Claude Code, Codex, Gemini, and OpenCode consistently, enforce this runtime contract:

Mandatory setup requirement: the host platform's steering file must be mapped and updated with this contract before this skill is considered installed or active. Loading memory files alone is not a valid substitute for steering integration.

1. **Session/task start**

- Use `~/self-improving/` as the fixed memory root
- Load `memory.md` first (HOT), then `index.md`, then matched namespace files

2. **After meaningful output**

- Run self-reflection: outcome vs intent, lesson, candidate pattern
- Write reflection/correction updates before ending the turn

3. **On explicit user correction**

- Append correction event to `corrections.md` with timestamp and context
- Update counters and promotion state

4. **On memory command**

- Support natural commands from this skill (`memory stats`, `show patterns`, `forget X`, `export memory`)
- Return source-aware answers (file + context when available)

5. **On context pressure**

- Degrade safely: load HOT only, disclose skipped WARM/COLD loads

This contract is platform-agnostic; only the host-specific steering file differs. If the steering file mapping is missing, treat setup as incomplete and complete `setup.md` before using the skill.

## Detection Triggers

Log automatically when you notice these patterns:

**Corrections** → add to `corrections.md`, evaluate for `memory.md`:

- "No, that's not right..."
- "Actually, it should be..."
- "You're wrong about..."
- "I prefer X, not Y"
- "Remember that I always..."
- "I told you before..."
- "Stop doing X"
- "Why do you keep..."

**Preference signals** → add to `memory.md` if explicit:

- "I like when you..."
- "Always do X for me"
- "Never do Y"
- "My style is..."
- "For [project], use..."

**Pattern candidates** → track, promote after 3x:

- Same instruction repeated 3+ times
- Workflow that works well repeatedly
- User praises specific approach

**Ignore** (don't log):

- One-time instructions ("do X now")
- Context-specific ("in this file...")
- Hypotheticals ("what if...")

## Self-Reflection

After completing significant work, pause and evaluate:

1. **Did it meet expectations?** — Compare outcome vs intent
2. **What could be better?** — Identify improvements for next time
3. **Is this a pattern?** — If yes, log to `corrections.md`

**When to self-reflect:**

- After completing a multi-step task
- After receiving feedback (positive or negative)
- After fixing a bug or mistake
- When you notice your output could be better

**Log format:**

```
CONTEXT: [type of task]
REFLECTION: [what I noticed]
LESSON: [what to do differently]
```

**Example:**

```
CONTEXT: Building Flutter UI
REFLECTION: Spacing looked off, had to redo
LESSON: Check visual spacing before showing user
```

Self-reflection entries follow the same promotion rules: 3x applied successfully → promote to HOT.

## Quick Queries

| User says                   | Action                                 |
| --------------------------- | -------------------------------------- |
| "What do you know about X?" | Search all tiers for X                 |
| "What have you learned?"    | Show last 10 from `corrections.md`     |
| "Show my patterns"          | List `memory.md` (HOT)                 |
| "Show [project] patterns"   | Load `projects/{name}.md`              |
| "What's in warm storage?"   | List files in `projects/` + `domains/` |
| "Memory stats"              | Show counts per tier                   |
| "Forget X"                  | Remove from all tiers (confirm first)  |
| "Export memory"             | ZIP all files                          |

## Memory Stats

On "memory stats" request, report:

```
📊 Self-Improving Memory

HOT (always loaded):
  memory.md: X entries

WARM (load on demand):
  projects/: X files
  domains/: X files

COLD (archived):
  archive/: X files

Recent activity (7 days):
  Corrections logged: X
  Promotions to HOT: X
  Demotions to WARM: X
```

## Core Rules

### 1. Learn from Corrections and Self-Reflection

- Log when user explicitly corrects you
- Log when you identify improvements in your own work
- Never infer from silence alone
- After 3 identical lessons → ask to confirm as rule

### 2. Tiered Storage

| Tier | Location            | Size Limit      | Behavior               |
| ---- | ------------------- | --------------- | ---------------------- |
| HOT  | memory.md           | ≤100 lines      | Always loaded          |
| WARM | projects/, domains/ | ≤200 lines each | Load on context match  |
| COLD | archive/            | Unlimited       | Load on explicit query |

### 3. Automatic Promotion/Demotion

- Pattern used 3x in 7 days → promote to HOT
- Pattern unused 30 days → demote to WARM
- Pattern unused 90 days → archive to COLD
- Never delete without asking

### 4. Namespace Isolation

- Project patterns stay in `projects/{name}.md`
- Global preferences in HOT tier (memory.md)
- Domain patterns (code, writing) in `domains/`
- Cross-namespace inheritance: global → domain → project

### 5. Conflict Resolution

When patterns contradict:

1. Most specific wins (project > domain > global)
2. Most recent wins (same level)
3. If ambiguous → ask user

### 6. Compaction

When file exceeds limit:

1. Merge similar corrections into single rule
2. Archive unused patterns
3. Summarize verbose entries
4. Never lose confirmed preferences

### 7. Transparency

- Every action from memory → cite source: "Using X (from projects/foo.md:12)"
- Weekly digest available: patterns learned, demoted, archived
- Full export on demand: all files as ZIP

### 8. Security Boundaries

See `boundaries.md` — never store credentials, health data, third-party info.

### 9. Graceful Degradation

If context limit hit:

1. Load only memory.md (HOT)
2. Load relevant namespace on demand
3. Never fail silently — tell user what's not loaded

## Scope

This skill ONLY:

- Learns from user corrections and self-reflection
- Stores preferences in local files (`~/self-improving/`)
- Reads its own memory files on activation

This skill NEVER:

- Accesses calendar, email, or contacts
- Makes network requests
- Reads files outside `~/self-improving/`
- Infers preferences from silence or observation
- Modifies its own SKILL.md

## Related Skills

For coding-agent runtimes (Claude Code, Codex, Gemini, OpenCode), keep this skill folder in the runtime skill path and wire the activation contract in the steering file.

- `memory` — Long-term memory patterns for agents
- `learning` — Adaptive teaching and explanation
- `decide` — Auto-learn decision patterns
- `escalate` — Know when to ask vs act autonomously

## Feedback

- Track behavior changes via your repo history and memory stats outputs.
