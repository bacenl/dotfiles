---
name: lecture-notes-to-anki
description: Use when generating interview flashcards from technical lecture notes or knowledge vault files and importing them directly into Anki via AnkiConnect, targeting software engineering or game programming interviews at top tech and game companies.
---

# Lecture Notes to Anki

## Overview

Generate interview-ready Anki flashcards from technical content and push them directly into Anki via AnkiConnect — no file export, no manual import step. Questions are weighted by interview likelihood at target companies (Mihoyo, Tencent, NetEase, Shopee, Grab, Garena, FAANG, etc.).

**Requirements:** Anki Desktop with AnkiConnect add-on (code `2055492159`). Anki binary: `/usr/bin/anki`.

---

## Step 0 — Fetch Existing Cards (Deduplication)

**Before generating any new questions**, fetch existing card fronts from the deck so you don't write semantically duplicate questions.

```python
import json, urllib.request

def anki(action, **params):
    payload = json.dumps({"action": action, "version": 6, "params": params}).encode()
    req = urllib.request.Request('http://127.0.0.1:8765', payload, {'Content-Type': 'application/json'})
    resp = json.load(urllib.request.urlopen(req))
    if resp.get('error'): raise Exception(resp['error'])
    return resp['result']

# Fetch all existing fronts from the deck (optionally filtered by tag)
note_ids = anki('findNotes', query='deck:"SWE Interview Practice"')
existing_fronts = []
if note_ids:
    notes_info = anki('notesInfo', notes=note_ids)
    existing_fronts = [n['fields']['Front']['value'] for n in notes_info]

print(f"Deck has {len(existing_fronts)} existing cards.")
```

Use `existing_fronts` as context when writing new questions:
- **Exact duplicates** — AnkiConnect catches these automatically at push time (returns `null` for the note ID).
- **Semantic duplicates** — You (Claude) must avoid them during generation. If an existing front asks essentially the same thing with different wording, skip it.

If the deck is empty or the topic is new, proceed normally.

---

## Step 1 — Identify What to Quiz

For each topic, ask: *would an interviewer at a top tech or game company ask this?*

**High priority (always include):**
- Foundational concepts with common confusion (mutex vs semaphore, process vs thread)
- Gotchas / counterintuitive behavior (false sharing, warp divergence)
- Laws/formulas asked by name (Amdahl's, CAP theorem)
- "When to use X vs Y" decisions
- Failure modes: deadlock, race condition, starvation

**Medium priority (include if relevant):**
- Non-obvious API/syntax (OpenMP pragmas, MPI lifecycle)
- Architecture facts that explain behavior (cache line = 64 bytes, warp = 32 threads)
- Performance debugging patterns

**Skip:** pure derivations, niche academic content, anything an interviewer would look up.

---

## Step 2 — Write Good Questions

"What is X?" is weak. "Why does X matter / what problem does it solve?" is strong.

| Weak | Strong |
|---|---|
| What is a mutex? | What is the difference between a mutex and a semaphore? |
| What is Amdahl's Law? | Explain Amdahl's Law. What does it imply for parallel design? |
| What is warp divergence? | What is warp divergence and why does it hurt performance? |
| What is false sharing? | What is false sharing and how do you fix it? |

Include "give a concrete example" for abstract concepts — forces recall of implementation, not just the label.

**Question types to cover per topic:**

| Type | Example |
|---|---|
| Compare two concepts | "What is the difference between X and Y?" |
| Explain + implication | "Explain X. What does it imply for design?" |
| Failure mode | "What is X and what causes it?" |
| Fix / debug | "What is X and how do you fix/prevent it?" |
| When to use | "When would you use X over Y?" |
| Concrete example | "Give a concrete example of X." |
| Gotcha | "Can parallel code be slower than sequential? When?" |

---

## Step 3 — Format Cards for AnkiConnect

Each card maps to a **Basic** note in Anki (Front + Back fields).

**Front** = the question, plain text.
**Back** = the full answer. Use HTML for structure — AnkiConnect accepts raw HTML in field values.

Write cards as a flat list. Use a clear separator between cards for readability, but the format is flexible since I parse and construct the JSON directly — no tool-specific syntax required.

**Suggested writing format (for review in Obsidian):**

```markdown
## What is the difference between a mutex and a semaphore?

**Mutex**
Binary lock — only one thread can hold it. The same thread that locks must unlock. Used for mutual exclusion.

**Semaphore**
Counter-based — allows up to N threads simultaneously. Can be signaled from a different thread. Used for producer/consumer or resource limiting.

**Key distinction**
A mutex has ownership; a semaphore does not.
```

When pushing to Anki, the `##` line becomes the Front, and the body is converted to HTML for the Back.

**Answer quality rules:**
- Keep Back under ~150 words — Anki is for recall, not reading
- Use bold headers to chunk multi-part answers
- Include a minimal code snippet when syntax is the point
- 20–30 high-quality cards beats 60 mediocre ones

---

## Step 4 — Push to Anki via AnkiConnect

### 1. Confirm with user before doing anything

Deck is always `"SWE Interview Practice"`. Tag is derived from the topic/input (e.g., `parallel-computing`, `operating-systems`, `system-design`). Infer the tag from the source material — confirm it with the user in the prompt.

```
Ready to import to Anki:
  Deck  : "SWE Interview Practice"
  Tag   : <topic-tag>
  Cards : <N> cards
  Model : Basic (Front / Back)

Launch Anki and push? (y/n)
```

### 2. Ensure Anki is running

```bash
# Check if AnkiConnect is already up
curl -s http://127.0.0.1:8765 > /dev/null 2>&1 || {
    echo "Starting Anki..."
    /usr/bin/anki &
    until curl -s http://127.0.0.1:8765 > /dev/null 2>&1; do sleep 1; done
    echo "AnkiConnect ready."
}
```

### 3. Parse and push via Python

Use a Python one-shot script (not raw curl — JSON escaping for many cards is impractical in shell).

```python
import json, re, urllib.request

with open('<path-to-cards.md>', 'r') as f:
    content = f.read()

# Split on ## headings — each becomes one card
cards_raw = re.split(r'^## ', content, flags=re.MULTILINE)
cards_raw = [c.strip() for c in cards_raw if c.strip()]

def md_to_html(text):
    # Code blocks before inline code
    text = re.sub(r'```[\w]*\n(.*?)```',
        lambda m: '<pre><code>' + m.group(1).replace('&','&amp;').replace('<','&lt;').replace('>','&gt;') + '</code></pre>',
        text, flags=re.DOTALL)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    text = re.sub(r'\n\n+', '<br><br>', text)
    text = re.sub(r'\n', '<br>', text)
    return text

notes = []
for card in cards_raw:
    parts = card.split('\n', 1)
    front = parts[0].strip()
    back  = md_to_html(parts[1].strip()) if len(parts) > 1 else ''
    notes.append({
        "deckName": "SWE Interview Practice",
        "modelName": "Basic",
        "fields": {"Front": front, "Back": back},
        "tags": ["<topic-tag>"]  # e.g. parallel-computing, os, system-design
    })

def anki(action, **params):
    payload = json.dumps({"action": action, "version": 6, "params": params}).encode()
    req = urllib.request.Request('http://127.0.0.1:8765', payload, {'Content-Type': 'application/json'})
    resp = json.load(urllib.request.urlopen(req))
    if resp.get('error'):
        raise Exception(resp['error'])
    return resp['result']

anki('createDeck', deck='SWE Interview Practice')
results = anki('addNotes', notes=notes)

added   = sum(1 for r in results if r is not None)
skipped = sum(1 for r in results if r is None)
print(f"Done. {added} cards added, {skipped} duplicates skipped.")
```

`addNotes` returns an array of note IDs — `null` means a duplicate was skipped (AnkiConnect deduplicates by Front field within the same deck).

### 4. Report results

```
Done. 24 cards added to "Parallel Computing". 0 duplicates skipped.
```
