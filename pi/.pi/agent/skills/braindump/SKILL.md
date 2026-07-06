# Braindump Skill

Use this skill when the user wants to log something they learned, capture a note, braindump, or journal about their internship. Triggers: "I learned", "braindump", "note to self", "TIL", "log this", "write this down", "capture this", or any request to save learnings/notes to their Obsidian vault.

## Behavior

Write notes to the user's Obsidian internship braindump folder using this path structure:

```
~/Documents/obsidian/internship/braindump/<week_folder>/<today_folder>/
```

### Path Convention

- **Week folder**: `week-<N>` where N is the internship week number
- **Internship start date**: **2026-06-01** (Monday) — this is week 1
- **Calculation**: `week = floor((today - 2026-06-01) / 7) + 1`
- **Today folder**: `<YYYY-MM-DD>` (e.g., `2026-06-25`)
- **Full example**: `~/Documents/obsidian/internship/braindump/week-4/2026-06-25/`

Use the current date at the time of writing. Calculate the internship week number by counting days since June 1, 2026.

### File Naming

- Use a short, descriptive kebab-case filename based on the topic: `<topic>.md`
- Examples: `rust-lifetimes.md`, `docker-networking.md`, `git-rebase-workflow.md`
- If the user doesn't specify a topic name, infer one from the content

### Note Format

Write notes as clean Obsidian-compatible Markdown:

```markdown
# <Title>

<Content — what was learned, key takeaways, examples, gotchas>
```

Guidelines:
- Keep it concise but complete — capture the insight, not a textbook
- Use code blocks with language tags for any code snippets
- Use bullet points for lists of takeaways
- Add `> [!tip]` or `> [!warning]` callouts for important gotchas
- Link related concepts with `[[wikilinks]]` if the user mentions connections to other notes
- Don't add YAML frontmatter unless the user asks for it

### Multiple Topics

If the user dumps multiple topics at once, create separate files for each distinct topic in the same day folder.

### Appending

If a file for the same topic already exists today, append to it under a `---` separator rather than overwriting.

## Steps

1. Determine today's date
2. Calculate internship week: `floor((today - 2026-06-01) / 7) + 1`
3. Construct the target directory path
4. Create the directory if it doesn't exist (use `mkdir -p` via bash or let `write` handle it)
5. Write the note file(s)
6. Confirm what was written and where
