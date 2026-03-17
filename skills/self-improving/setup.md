# Setup — Self-Improving Agent

## First-Time Setup

### 1. Create Memory Structure

```bash
mkdir -p ~/self-improving/{projects,domains,archive}
```

### 2. Initialize Core Files

Create `~/self-improving/memory.md` using `memory-template.md`:

```markdown
Copy the structure from `memory-template.md` into `~/self-improving/memory.md`.
```

Memory file baseline:
```markdown
# Memory (HOT Tier)

## Preferences

## Patterns

## Rules
```

Create `~/self-improving/corrections.md`:
```markdown
# Corrections Log

| Date | What I Got Wrong | Correct Answer | Status |
|------|-----------------|----------------|--------|
```

Create `~/self-improving/index.md`:
```markdown
# Memory Index

| File | Lines | Last Updated |
|------|-------|--------------|
| memory.md | 0 | — |
| corrections.md | 0 | — |
```

### 3. Configure Operating Mode (Mandatory)

This step is required. You must add one operating mode block to the active global host steering file before this skill can be considered installed or active.

Write this into the global steering file that the host runtime actually reads (`AGENTS.md` where supported; otherwise the platform-native steering file). Do not treat an unlinked project-local steering file as sufficient:

```markdown
## Self-Improving Mode

Current mode: Active

Available modes (coding-agent):
- Passive:
  - Load HOT memory on task start
  - Record only explicit corrections
  - No proactive promotion prompts
- Active:
  - Passive + detect repeated patterns
  - Ask to promote when same signal appears 3x
  - Run end-of-task self-reflection write-back
- Strict:
  - Active + require confirmation before any non-log write to memory.md/projects/domains
  - Always emit source citation when memory affected output
```

Minimum runtime hooks (all modes, mandatory):
- Task start: load `~/self-improving/memory.md` then `index.md`
- On explicit correction: append to `~/self-improving/corrections.md`
- Before final response: run memory write-back check (`updated` or `no-op`)

Do not skip this section. If no operating mode is written into the global steering file actually used by the host, setup is incomplete.

### 4. Steering File Mapping (All Coding Agents, Mandatory)

This step is required. Until the correct global host steering file is mapped and updated, `self-improving` is not installed and must not be treated as active.

Map exactly one primary steering entry point based on the current platform:
- Claude Code: the global `CLAUDE.md` (or the workspace steering file only if that is the actual host entry point)
- Codex/OpenCode: the global `AGENTS.md` used by the runtime (preferred)
- Gemini: the global `GEMINI.md` (or runtime system instruction file)

Do not stop after creating `~/self-improving/` files. The setup is incomplete unless this global steering mapping is finished. A project-local file that is not loaded by the host does not count.

### 5. Refine Primary Steering Memory Section (Mandatory, Non-Destructive)

This step is required. Update the primary global steering file (`AGENTS.md` where supported; otherwise the platform-native steering file actually loaded by the host) by complementing the existing `## Memory` section. Do not replace the whole section and do not remove existing lines, but do not skip the additions below.

If your `## Memory` block differs from the default template, insert the same additions in equivalent places so existing information is preserved. Missing these additions means setup is still incomplete.

Add this line in the continuity list (next to Daily notes and Long-term):

```markdown
- **Self-improving:** `~/self-improving/` (via `self-improving` skill) — execution-improvement memory (preferences, workflows, style patterns, what improved/worsened outcomes)
```

Right after the sentence "Capture what matters...", add:

```markdown
Use `memory/YYYY-MM-DD.md` and `MEMORY.md` for factual continuity (events, context, decisions).
Use `~/self-improving/` for compounding execution quality across tasks.
For compounding quality, capture clear execution-improvement signals in `~/self-improving/`: preferences, workflow/style choices, what improved or degraded results, and high-signal inferences for next time.
If in doubt, store factual history in `memory/YYYY-MM-DD.md` / `MEMORY.md`, and store reusable performance lessons in `~/self-improving/` (tentative until human validation).
```

Before the "Write It Down" subsection, add:

```markdown
When writing or organizing in `~/self-improving/`, read `self-improving` `SKILL.md` first.
If inferring a new rule, keep it tentative until human validation.
```

Inside the "Write It Down" bullets, refine the behavior (mandatory, non-destructive):
- Keep existing intent, but route execution-improvement content to `~/self-improving/`.
- If the exact bullets exist, replace only these lines; if wording differs, apply equivalent edits without removing unrelated guidance.

Use this target wording:

```markdown
- When someone says "remember this" → if it's factual context/event, update `memory/YYYY-MM-DD.md`; if it's a correction, preference, workflow/style choice, or performance lesson, log it in `~/self-improving/` via the `self-improving` skill
- When you learn a lesson → store it in `~/self-improving/` by default; update only your global steering/guardrail docs when the rule is truly cross-domain
- When you make a mistake → document it in `~/self-improving/corrections.md` so future behavior improves; escalate to global steering/guardrails only for broad, always-on rules
```

## Coding-Agent Integration (Claude Code / Codex / Gemini / OpenCode, Mandatory)

This entire section is required. Use the same memory files and behavior contract across coding agents. Prefer centralizing the contract in the global steering file (`AGENTS.md` where supported) that the host actually reads; if the platform does not read it, mirror the same contract in its native global steering file. This mapping is mandatory, not optional.

### Claude Code

1. Put this skill under Claude Code's skills directory.
2. Add (or mirror) the contract in the global `CLAUDE.md` actually read by Claude Code. Without this step, the skill is not active in Claude Code:

```markdown
## Self-Improving Runtime Contract
- At start of each task, load `~/self-improving/memory.md` (HOT) first.
- On explicit correction, append to `corrections.md` and update promotion counters.
- After significant work, run self-reflection and log lessons.
- On memory commands, query tiered files and cite sources.
```

### Codex

1. Keep this skill in your workspace skill path (for example `./skills/self-improving`).
2. Write the contract into the global steering file that Codex actually reads (`AGENTS.md` where supported). A project-local `AGENTS.md` only counts if it is the runtime's real steering entry point. Without this step, the skill is not active in Codex:

```markdown
## Self-Improving Runtime Contract
- Start: load `~/self-improving/memory.md`, then `index.md`, then matching namespace files.
- Correction: write event to `~/self-improving/corrections.md` with timestamp + context.
- Reflection: after multi-step tasks, log lesson and promote only after confirmation rules.
- Transparency: cite memory source when behavior is affected.
```

### Gemini

1. Add this skill/workflow reference into the global `GEMINI.md` or the prompt steering file actually used by your Gemini agent.
2. Write the same contract text there. Without this step, the skill is not active in Gemini:

```markdown
## Self-Improving Runtime Contract
- Use `~/self-improving` as fixed memory root.
- Always load HOT memory first.
- Record explicit corrections only; never infer from silence.
- Apply tier precedence: project > domain > global.
- Expose source and support forget/export commands.
```

### OpenCode

1. Add this skill/workflow reference to the global OpenCode agent instruction file actually used by the host.
2. Reuse the same runtime contract there. Without this step, the skill is not active in OpenCode:

```markdown
## Self-Improving Runtime Contract
- Use `~/self-improving` as fixed memory root.
- Load HOT memory before generating responses.
- Log explicit corrections to `corrections.md` with timestamp and context.
- Apply namespace precedence: project > domain > global.
- Cite memory source when it changes behavior.
```

### Compatibility Notes

- Memory format is plain Markdown; no platform-specific parser is required.
- This skill does not require network access.
- If a runtime has no native skill tool, emulate by loading `SKILL.md` at session start and following the same steering contract.

## Verification

Run both checks below to confirm setup.

1. Run `memory stats` to confirm the memory root is available:

```
📊 Self-Improving Memory

🔥 HOT (always loaded):
   memory.md: 0 entries

🌡️ WARM (load on demand):
   projects/: 0 files
   domains/: 0 files

❄️ COLD (archived):
   archive/: 0 files

⚙️ Mode: Passive
```

2. Verify the active global host steering file contains all required `self-improving` integration blocks. Do not validate against a project-local file unless the runtime truly loads that file.

Minimum acceptance criteria:
- The steering file contains a `## Self-Improving Mode` block
- The steering file contains a `## Self-Improving Runtime Contract` block
- The steering file's `## Memory` section includes the `Self-improving: ~/self-improving/` continuity entry
- The steering file's memory guidance routes corrections, preferences, workflow/style choices, and lessons learned into `~/self-improving/`

If any of the items above is missing, treat setup as incomplete even if `memory stats` succeeds.

## Optional: Heartbeat Integration

Add to `HEARTBEAT.md` for automatic maintenance:

```markdown
## Self-Improving Check

- [ ] Review corrections.md for patterns ready to graduate
- [ ] Check memory.md line count (should be ≤100)
- [ ] Archive patterns unused >90 days
```
