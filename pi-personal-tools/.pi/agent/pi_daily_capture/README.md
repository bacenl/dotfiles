# pi daily internship capture

Local pi-coding-agent workflow for creating a raw same-day Obsidian capture note.

This package is stowed only by `./setup.sh --profile personal`; devcontainer setup does not install it. The script also refuses to run in detected containers unless you pass `--force-container` or set `PI_DAILY_CAPTURE_ALLOW_CONTAINER=1`.

## Output

One file per Asia/Tokyo day:

```text
/home/ubuntu/obsidian/internship/braindump/week_N/YYYY-MM-DD/pi-capture.md
```

`week_1` starts on Monday `2026-06-01`; week numbers increment every Monday.

The script never edits official daily logs under `internship/daily/` or weekly summaries. It only writes `pi-capture.md` in the braindump day folder.

## Run manually

```bash
python ~/.pi/agent/pi_daily_capture/capture.py
```

For a dry historical check of a specific Tokyo date:

```bash
python ~/.pi/agent/pi_daily_capture/capture.py --date 2026-07-09
```

## Configuration

Edit `~/.pi/agent/pi_daily_capture/config.yaml` (tracked in dotfiles) to add machine-specific repo roots or note folders. Missing roots are reported under "Sources skipped / unavailable" so one shared config can work across multiple personal computers.

Sources currently supported:

- Git repos discovered below configured roots or explicit repo paths
- Markdown notes modified today below configured note roots

Same-day filtering uses Asia/Tokyo boundaries for commits and filesystem modified times. If a source cannot be timestamped precisely, the output places it under an `uncertain_same_day` note rather than treating it as definite evidence.

## Privacy and scope

The capture prefers paths, commit hashes, headings, TODOs, links, and compact diff stats. It skips obvious secret filenames and generated/vendor directories and redacts obvious secret-looking values from excerpts.
