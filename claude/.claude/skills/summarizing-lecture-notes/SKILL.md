---
name: summarizing-lecture-notes
description: Use when converting lecture slides, course PDFs, or academic materials into a structured markdown knowledge vault for interview preparation or practical reference in software engineering, full-stack, or game programming roles.
---

# Summarizing Lecture Notes

## Overview

Convert course materials into a concise, interview-focused markdown vault. Each file targets a 3-minute read and refreshes 80% of understanding — not a textbook, a refresh tool.

**Vault root:** `/obsidian/`
**Output target:** `/obsidian/02_programming/` (ask user to confirm placement per file)

## When to Use

- User provides lecture PDFs or slides from a technical course
- Goal is interview prep or on-the-job reference (not comprehensive study)
- Domain is software engineering, full-stack, or game development

**Not for:** first-time learning, academic assignments, or comprehensive documentation.

---

## Core Pattern

### Step 1 — Read and Triage

Use a subagent (or parallel reads) to extract key concepts per lecture. For each file identify:
- Main topic
- Interview-relevant concepts (would an interviewer at a top tech/game company ask about this?)
- Practical examples or code patterns
- Domain relevance (full-stack vs game dev)

**Omit aggressively.** Academic theory with no interview or job relevance → one bullet in the overview at most.

### Step 2 — Propose File Placement

Before writing anything, scan the existing `02_programming/` structure and propose where each output file should live. Present a mapping to the user and confirm before creating any files.

**Existing `02_programming/` structure to be aware of:**
```
01_languages/      bash, c++, cuda, git, go, godot, java, python, rust, ...
02_concepts/       AI, computer_graphics, computer_networks, concurrency,
                   data_structures_and_algorithms, gpu, math, operating_systems
03_practical_software_development/   backend, systems_design
04_game_engines/   godot, unreal_engine
05_interviews/     leetcode
06_config/
07_agentic/
```

**Mapping proposal format — show this to the user before writing:**
```
Proposed file placement:
  Parallel-Computing.md     → 02_concepts/concurrency/
  CUDA.md                   → 01_languages/cuda/
  OpenMP.md                 → 02_concepts/concurrency/
  MPI.md                    → 02_concepts/concurrency/
  Cache-Coherence.md        → 02_concepts/concurrency/
  Performance-Analysis.md   → 02_concepts/concurrency/
  Processes-and-Threads.md  → 02_concepts/operating_systems/

New folders to create: none

Confirm, or tell me where to move any file.
```

**Placement rules:**
- If content fits an existing folder cleanly → place it there directly (no subfolder)
- If it's a new topic cluster with 3+ files → create a new named subfolder
- If unsure → ask, don't guess
- `05_interviews/` is for leetcode/problem-solving; reference notes go in `02_concepts/` or `01_languages/`

### Step 3 — Write Each File

**Style rules:**
- Bullets and tables over prose
- Code snippets only for patterns worth memorizing
- Domain callouts: `> **Game dev:** ...` or `> **Full-stack:** ...`
- `[[wikilinks]]` for cross-references (Obsidian-compatible)
- Each file ends with `## Related` linking to sibling pages

**Length target:** 300–500 words. If you're over 500, split into two files or cut.

**Abstraction rule:** One level of abstraction per file. Don't explain *how* something works if that belongs in a child page — link instead.

---

## What to Include vs Omit

| Include | Omit |
|---|---|
| Interview-common concepts | Proof derivations |
| Practical code patterns | History / academic context |
| Decision rules ("when to use X vs Y") | Niche edge cases |
| Domain-specific callouts | Content with no interview precedent |
| Comparison tables | Verbose explanations |

---

## Common Mistakes

**Skipping the placement confirmation.** Always show the proposed mapping and wait for the user to confirm before writing files.

**Creating new folders for single files.** One file doesn't justify a subfolder — place it directly in the closest existing parent.

**Too much detail in top-level file.** The overview should be readable in 2 minutes and link downward.

**Treating all topics equally.** Some content is interview-critical (cache coherence, Amdahl's Law). Some is academic noise. Weight accordingly.

**Creating files for everything.** Low-relevance topics belong as one bullet in the parent file, not a dedicated page.
