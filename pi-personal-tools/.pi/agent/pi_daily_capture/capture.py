#!/usr/bin/env python3
"""Create a same-day raw Obsidian capture for internship learning.

This script is intentionally conservative: it filters by Asia/Tokyo day
boundaries, prefers paths/summaries over raw content, and skips obvious secret
or generated locations.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    yaml = None

SECRET_NAME_RE = re.compile(r"(\.env|secret|token|credential|private[_-]?key|id_rsa|id_ed25519|\.pem|\.key)", re.I)
SECRET_VALUE_RE = re.compile(r"(?i)(api[_-]?key|token|secret|password|bearer)\s*[:=]\s*['\"]?[^\s'\"]+")
SIGNAL_RE = re.compile(
    r"\b(idk|not sure|unclear|why|how does|need to understand|look into|read into|question|todo|fixme|note|error|failed|debug|tradeoff|assumption|metric|eval|explained|discussion)\b",
    re.I,
)
TODO_RE = re.compile(r"\b(TODO|FIXME|NOTE|QUESTION)\b[:\s-]*(.*)", re.I)
LINK_RE = re.compile(r"https?://[^\s)\]>\"]+")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
CONCEPT_RE = re.compile(r"\b[A-Z][A-Za-z0-9+_.-]{2,}\b|`([^`]{2,60})`")

DEFAULT_CONFIG = {
    "timezone": "Asia/Tokyo",
    "internship_root": "/home/ubuntu/obsidian/internship",
    "week_1_monday": "2026-06-01",
    "repos": ["~/Projects", "~/work", "~/shisa"],
    "note_roots": ["/home/ubuntu/obsidian/internship"],
    "exclude_paths": [".git", "node_modules", ".venv", "__pycache__"],
    "max_excerpt_chars": 500,
    "max_diff_lines": 80,
    "max_repos_discovered": 200,
    "max_files_per_repo": 80,
    "max_notes": 120,
    "skip_in_devcontainer": True,
}


def load_config(path: Path) -> dict[str, Any]:
    if not path.exists():
        return dict(DEFAULT_CONFIG)
    text = path.read_text()
    if yaml is not None:
        loaded = yaml.safe_load(text) or {}
        return {**DEFAULT_CONFIG, **loaded}
    return {**DEFAULT_CONFIG, **parse_tiny_yaml(text)}


def parse_tiny_yaml(text: str) -> dict[str, Any]:
    """Parse the simple config.yaml shape used by this tool when PyYAML is absent."""
    data: dict[str, Any] = {}
    current_key: str | None = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if not line.startswith(" ") and ":" in line:
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()
            current_key = key
            if value == "":
                data[key] = []
            elif value.lower() in {"true", "false"}:
                data[key] = value.lower() == "true"
            else:
                data[key] = int(value) if value.isdigit() else value
        elif current_key and line.lstrip().startswith("- "):
            data.setdefault(current_key, []).append(line.lstrip()[2:].strip())
    return data


def run(cmd: list[str], cwd: Path | None = None) -> str:
    try:
        return subprocess.run(cmd, cwd=cwd, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout.strip()
    except OSError:
        return ""


def expand_path(value: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def in_devcontainer() -> bool:
    return bool(os.environ.get("REMOTE_CONTAINERS") or os.environ.get("CODESPACES") or os.environ.get("DEVCONTAINER")) or Path("/.dockerenv").exists()


def iso(ts: dt.datetime) -> str:
    return ts.isoformat(timespec="seconds")


def file_mtime(path: Path, tz: ZoneInfo) -> dt.datetime | None:
    try:
        return dt.datetime.fromtimestamp(path.stat().st_mtime, tz)
    except OSError:
        return None


def is_same_day(path: Path, start: dt.datetime, end: dt.datetime, tz: ZoneInfo) -> bool:
    mtime = file_mtime(path, tz)
    return bool(mtime and start <= mtime <= end)


def excluded(path: Path, exclude_names: set[str]) -> bool:
    return any(part in exclude_names for part in path.parts)


def secretish(path: Path) -> bool:
    return bool(SECRET_NAME_RE.search(str(path)))


def safe_excerpt(line: str, max_chars: int) -> str:
    line = SECRET_VALUE_RE.sub(r"\1=<redacted>", line.strip())
    if len(line) > max_chars:
        return line[: max_chars - 1] + "…"
    return line


def discover_repos(entries: list[str], exclude: set[str], limit: int) -> tuple[list[Path], list[str]]:
    repos: list[Path] = []
    skipped: list[str] = []
    seen: set[Path] = set()
    for entry in entries:
        root = expand_path(entry)
        if not root.exists():
            skipped.append(f"repo root missing: {root}")
            continue
        candidates: list[Path] = []
        if (root / ".git").exists():
            candidates = [root]
        else:
            for dirpath, dirnames, _ in os.walk(root):
                p = Path(dirpath)
                dirnames[:] = [d for d in dirnames if d not in exclude]
                if (p / ".git").exists():
                    candidates.append(p)
                    dirnames[:] = []
        for repo in candidates:
            if repo not in seen:
                repos.append(repo)
                seen.add(repo)
                if len(repos) >= limit:
                    skipped.append(f"repo discovery limited to {limit} repos")
                    return repos, skipped
    return repos, skipped


@dataclass
class RepoActivity:
    path: Path
    branch: str = "unknown"
    commits: list[str] = field(default_factory=list)
    files_today: list[str] = field(default_factory=list)
    uncommitted_today: list[str] = field(default_factory=list)
    new_today: list[str] = field(default_factory=list)
    diff_stat: list[str] = field(default_factory=list)
    signals: list[str] = field(default_factory=list)
    uncertain: list[str] = field(default_factory=list)

    @property
    def active(self) -> bool:
        return any([self.commits, self.files_today, self.uncommitted_today, self.new_today, self.signals, self.uncertain])


def collect_repo(repo: Path, start: dt.datetime, end: dt.datetime, tz: ZoneInfo, cfg: dict[str, Any]) -> RepoActivity:
    max_files = int(cfg["max_files_per_repo"])
    max_excerpt = int(cfg["max_excerpt_chars"])
    exclude = set(cfg["exclude_paths"])
    activity = RepoActivity(path=repo)
    activity.branch = run(["git", "branch", "--show-current"], repo) or "detached/unknown"
    since, until = iso(start), iso(end)
    log = run(["git", "log", f"--since={since}", f"--until={until}", "--date=iso-strict", "--pretty=format:%h %ad %s"], repo)
    activity.commits = log.splitlines()[:20] if log else []

    status = run(["git", "status", "--porcelain=v1", "-z"], repo)
    paths: list[tuple[str, str]] = []
    if status:
        parts = status.split("\0")
        i = 0
        while i < len(parts) and parts[i]:
            rec = parts[i]
            code, rel = rec[:2], rec[3:]
            if code.strip().startswith("R") and i + 1 < len(parts):
                i += 1
            paths.append((code, rel))
            i += 1
    for code, rel in paths:
        p = repo / rel
        if excluded(Path(rel), exclude) or secretish(p):
            continue
        if is_same_day(p, start, end, tz):
            activity.uncommitted_today.append(f"{code} {rel}")
            if code == "??":
                activity.new_today.append(rel)

    touched = run(["git", "log", f"--since={since}", f"--until={until}", "--name-only", "--pretty=format:"], repo)
    for rel in sorted({x for x in touched.splitlines() if x.strip()}):
        if len(activity.files_today) >= max_files:
            activity.uncertain.append(f"file list truncated at {max_files} entries")
            break
        if excluded(Path(rel), exclude) or secretish(repo / rel):
            continue
        activity.files_today.append(rel)

    for _, rel in paths:
        if rel and rel not in activity.files_today and len(activity.files_today) < max_files:
            p = repo / rel
            if not excluded(Path(rel), exclude) and not secretish(p) and is_same_day(p, start, end, tz):
                activity.files_today.append(rel)

    stat = run(["git", "diff", "--stat"], repo)
    if stat:
        activity.diff_stat = stat.splitlines()[: int(cfg["max_diff_lines"])]

    for rel in activity.files_today[:max_files]:
        p = repo / rel
        if p.exists() and p.is_file() and not secretish(p) and p.stat().st_size < 300_000:
            activity.signals.extend(extract_signals(p, max_excerpt, prefix=rel, max_lines=6))
    activity.signals = dedupe(activity.signals)[:20]
    return activity


def extract_signals(path: Path, max_excerpt: int, prefix: str | None = None, max_lines: int = 12) -> list[str]:
    if secretish(path):
        return []
    try:
        text = path.read_text(errors="ignore")
    except OSError:
        return []
    signals: list[str] = []
    for line in text.splitlines():
        if SIGNAL_RE.search(line) or TODO_RE.search(line) or LINK_RE.search(line):
            label = f"{prefix}: " if prefix else ""
            signals.append(label + safe_excerpt(line, max_excerpt))
            if len(signals) >= max_lines:
                break
    return signals


def collect_notes(note_roots: list[str], start: dt.datetime, end: dt.datetime, tz: ZoneInfo, cfg: dict[str, Any]) -> tuple[list[dict[str, Any]], list[str]]:
    notes: list[dict[str, Any]] = []
    skipped: list[str] = []
    exclude = set(cfg["exclude_paths"])
    for entry in note_roots:
        root = expand_path(entry)
        if not root.exists():
            skipped.append(f"note root missing: {root}")
            continue
        for p in root.rglob("*.md"):
            if len(notes) >= int(cfg["max_notes"]):
                skipped.append(f"note list truncated at {cfg['max_notes']} notes")
                return notes, skipped
            if excluded(p.relative_to(root), exclude) or secretish(p):
                continue
            # Explicitly avoid editing or special-casing official logs; read-only if modified today.
            if is_same_day(p, start, end, tz):
                notes.append(parse_note(p, int(cfg["max_excerpt_chars"])))
    return notes, skipped


def parse_note(path: Path, max_excerpt: int) -> dict[str, Any]:
    text = path.read_text(errors="ignore")
    headings = [m.group(2).strip() for m in map(HEADING_RE.match, text.splitlines()) if m][:12]
    title = headings[0] if headings else path.stem
    todos = []
    links = []
    signals = []
    for line in text.splitlines():
        if TODO_RE.search(line) or "?" in line:
            todos.append(safe_excerpt(line, max_excerpt))
        links.extend(LINK_RE.findall(line))
        if SIGNAL_RE.search(line):
            signals.append(safe_excerpt(line, max_excerpt))
        if len(todos) >= 10 and len(signals) >= 10:
            break
    return {"path": path, "title": title, "headings": headings, "todos": dedupe(todos)[:10], "links": dedupe(links)[:10], "signals": dedupe(signals)[:10]}


def dedupe(items: list[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for item in items:
        if item and item not in seen:
            out.append(item)
            seen.add(item)
    return out


def categorize(repos: list[RepoActivity], notes: list[dict[str, Any]]) -> dict[str, list[str]]:
    cats = {
        "concepts_tools_encountered": [],
        "uncertain_areas": [],
        "debugging_or_friction": [],
        "design_or_implementation_assumptions": [],
        "evaluation_or_metric_questions": [],
        "communication_or_collaboration_signals": [],
        "possible_generalizable_lessons": [],
        "resources_added": [],
    }
    evidence = []
    for repo in repos:
        evidence.extend(repo.commits)
        evidence.extend(repo.signals)
        evidence.extend(repo.files_today)
    for note in notes:
        evidence.extend(note["headings"] + note["todos"] + note["signals"] + note["links"])
    for item in evidence:
        low = item.lower()
        if LINK_RE.search(item):
            cats["resources_added"].append(item)
        if any(x in low for x in ["idk", "not sure", "unclear", "why", "how does", "question", "look into", "read into", "need to understand"]):
            cats["uncertain_areas"].append(item)
        if any(x in low for x in ["error", "failed", "fail", "debug", "fixme", "friction", "bug"]):
            cats["debugging_or_friction"].append(item)
        if any(x in low for x in ["assumption", "tradeoff", "design", "fallback", "refactor", "architecture"]):
            cats["design_or_implementation_assumptions"].append(item)
        if any(x in low for x in ["eval", "metric", "benchmark", "score", "accuracy", "latency"]):
            cats["evaluation_or_metric_questions"].append(item)
        if any(x in low for x in ["iyke", "teammate", "discuss", "explained", "review", "meeting", "collab"]):
            cats["communication_or_collaboration_signals"].append(item)
        if any(x in low for x in ["todo", "note", "docs", "chore", "cleanup"]):
            cats["possible_generalizable_lessons"].append(item)
        for match in CONCEPT_RE.findall(item):
            concept = match if isinstance(match, str) else match[0]
            if concept and not concept.isdigit():
                cats["concepts_tools_encountered"].append(concept)
    return {k: dedupe(v)[:15] for k, v in cats.items()}


def week_name(date: dt.date, week_1_monday: str) -> str:
    base = dt.date.fromisoformat(week_1_monday)
    days = (date - base).days
    n = days // 7 + 1
    return f"week_{max(n, 1)}"


def bullet(items: list[str], empty: str = "None found.", indent: str = "- ") -> str:
    if not items:
        return f"{indent}{empty}"
    return "\n".join(f"{indent}{x}" for x in items)


def generate_questions(repos: list[RepoActivity], notes: list[dict[str, Any]], cats: dict[str, list[str]]) -> list[str]:
    qs: list[str] = []
    for repo in repos[:4]:
        if repo.active:
            name = repo.path.name
            if repo.commits:
                qs.append(f"In {name}, which commit from today represents the clearest learning moment, and why?")
            if repo.diff_stat:
                qs.append(f"You changed files in {name} today. What assumption or workflow did those changes test?")
            if repo.signals:
                qs.append(f"A signal in {name} mentions `{repo.signals[0][:80]}`. What knowledge gap should Hermes help unpack?")
    for note in notes[:3]:
        qs.append(f"You modified `{note['path']}`. Which heading or question in that note should become the durable lesson?")
    if cats["evaluation_or_metric_questions"]:
        qs.append("Today had evaluation/metric signals. What decision should those measurements unlock?")
    if cats["debugging_or_friction"]:
        qs.append("Which debugging/friction point from today is reusable as a checklist or mental model?")
    if cats["communication_or_collaboration_signals"]:
        qs.append("What did a teammate or discussion clarify today, and what remained unclear afterward?")
    qs.append("Was today mostly chore work, or did it reveal a generalizable principle worth writing down?")
    return dedupe(qs)[:10]


def render(cfg: dict[str, Any], date: dt.date, week: str, tz: ZoneInfo, start: dt.datetime, end: dt.datetime, repos_checked: list[Path], note_roots: list[str], skipped: list[str], repo_acts: list[RepoActivity], notes: list[dict[str, Any]]) -> str:
    now = dt.datetime.now(tz)
    cats = categorize(repo_acts, notes)
    questions = generate_questions(repo_acts, notes, cats)
    active_repos = [r for r in repo_acts if r.active]
    lines = [
        "---",
        "type: internship-pi-capture",
        f"date: {date.isoformat()}",
        f"week: {week}",
        f"timezone: {cfg['timezone']}",
        f"generated_at: {iso(now)}",
        "source_agent: pi-coding-agent",
        "status: raw-capture",
        "---",
        "",
        f"# pi-coding-agent Capture — {date.isoformat()}",
        "",
        "## Scope",
        "",
        f"- Date boundary: {date.isoformat()} Asia/Tokyo only ({iso(start)} to {iso(end)})",
        "- Repos checked:",
        *(f"  - {p}" for p in repos_checked),
        "- Note folders checked:",
        *(f"  - {expand_path(n)}" for n in note_roots),
        "- Sources skipped / unavailable:",
        *(f"  - {s}" for s in (skipped or ["None."])),
        "",
        "## Today’s repo activity",
        "",
    ]
    if not active_repos:
        lines += ["No same-day repo activity found.", ""]
    for repo in active_repos:
        lines += [
            f"### Repo: {repo.path}",
            "",
            f"- Branch: {repo.branch}",
            "- Commits today:",
            bullet(repo.commits, indent="  - "),
            "- Files changed today:",
            bullet(repo.files_today, indent="  - "),
            "- Uncommitted same-day changes:",
            bullet(repo.uncommitted_today, indent="  - "),
            "- New files created today:",
            bullet(repo.new_today, indent="  - "),
            "- Diff summary:",
            bullet(repo.diff_stat, indent="  - "),
            "- Possible learning signals:",
            bullet(repo.signals, indent="  - "),
        ]
        if repo.uncertain:
            lines += ["- uncertain_same_day:", bullet(repo.uncertain, indent="  - ")]
        lines.append("")

    lines += ["## Today’s note activity", "", "- Notes created/modified today:"]
    if notes:
        lines += [f"  - {n['path']} — {n['title']}" for n in notes]
    else:
        lines.append("  - None found.")
    lines += ["- Headings or sections touched:"]
    note_headings = [f"{n['path']}: {', '.join(n['headings'][:8])}" for n in notes if n["headings"]]
    lines.append(bullet(note_headings, indent="  - "))
    lines += ["- TODOs/questions/links added:"]
    note_items: list[str] = []
    for n in notes:
        note_items.extend([f"{n['path']}: {x}" for x in (n["todos"] + n["links"])])
    lines += [bullet(note_items[:30], indent="  - "), "", "## Learning-relevant signals", ""]

    headings = [
        ("Concepts/tools encountered", "concepts_tools_encountered"),
        ("Uncertain areas / trailing questions", "uncertain_areas"),
        ("Debugging or friction points", "debugging_or_friction"),
        ("Design / implementation assumptions", "design_or_implementation_assumptions"),
        ("Evaluation / metric questions", "evaluation_or_metric_questions"),
        ("Communication / collaboration signals", "communication_or_collaboration_signals"),
        ("Possible generalizable lessons", "possible_generalizable_lessons"),
        ("Resources added", "resources_added"),
    ]
    for title, key in headings:
        lines += [f"### {title}", "", bullet(cats[key]), ""]

    general_tags = ["internship", "raw-capture", "pi-coding-agent"] + [sanitize_tag(x) for x in cats["concepts_tools_encountered"][:7]]
    lines += [
        "## Candidate tags",
        "",
        "company_specific_tags:",
        "- internship",
        "",
        "general_tags:",
        *(f"- {t}" for t in dedupe([t for t in general_tags if t])),
        "",
        "## Questions Hermes should ask me",
        "",
    ]
    lines += [f"{i}. {q}" for i, q in enumerate(questions, 1)]
    raw: list[str] = []
    for r in active_repos:
        raw.append(f"repo {r.path} branch={r.branch}")
        raw.extend([f"commit {r.path}: {c}" for c in r.commits[:5]])
    raw.extend([f"note {n['path']}" for n in notes[:20]])
    lines += ["", "## Raw evidence index", "", bullet(raw[:60]), ""]
    return "\n".join(lines)


def sanitize_tag(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_-]+", "-", value.strip()).strip("-").lower()
    return value[:40]


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        Path(tmp_path).replace(path)
    except Exception:
        Path(tmp_path).unlink(missing_ok=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path(__file__).with_name("config.yaml"))
    parser.add_argument("--date", help="Asia/Tokyo date to capture, YYYY-MM-DD (default: today)")
    parser.add_argument("--force-container", action="store_true", help="run even when a devcontainer/container is detected")
    args = parser.parse_args()

    cfg = load_config(args.config)
    if cfg.get("skip_in_devcontainer", True) and in_devcontainer() and not args.force_container and not os.environ.get("PI_DAILY_CAPTURE_ALLOW_CONTAINER"):
        print("[skip] devcontainer/container detected; rerun with --force-container only on a personal machine", file=sys.stderr)
        return 2

    tz = ZoneInfo(str(cfg["timezone"]))
    today = dt.date.fromisoformat(args.date) if args.date else dt.datetime.now(tz).date()
    start = dt.datetime.combine(today, dt.time(0, 0, 0), tzinfo=tz)
    end = dt.datetime.combine(today, dt.time(23, 59, 59), tzinfo=tz)
    week = week_name(today, str(cfg["week_1_monday"]))

    exclude = set(cfg["exclude_paths"])
    repos, skipped = discover_repos(list(cfg["repos"]), exclude, int(cfg["max_repos_discovered"]))
    repo_acts = [collect_repo(r, start, end, tz, cfg) for r in repos]
    notes, note_skipped = collect_notes(list(cfg["note_roots"]), start, end, tz, cfg)
    skipped.extend(note_skipped)

    out = expand_path(str(cfg["internship_root"])) / "braindump" / week / today.isoformat() / "pi-capture.md"
    content = render(cfg, today, week, tz, start, end, repos, list(cfg["note_roots"]), skipped, repo_acts, notes)
    atomic_write(out, content)
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
