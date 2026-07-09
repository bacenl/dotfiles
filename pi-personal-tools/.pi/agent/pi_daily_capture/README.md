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

## Automated schedule (systemd timer)

The personal profile bootstrap installs a systemd user timer that runs the capture daily at **23:00 JST** — 30 minutes before Hermes ingestion at 23:30 JST.

```text
~/.config/systemd/user/pi-daily-capture.timer
~/.config/systemd/user/pi-daily-capture.service
```

### Why 23:00 JST?

Hermes ingests the capture notes at 23:30 JST. The capture runs at 23:00 to ensure the file is written and flushed before Hermes picks it up. This gives a 30-minute buffer for any slow I/O or git operations.

### Checking status

```bash
# See next trigger time and recent runs
systemctl --user status pi-daily-capture.timer

# View the timer's log output
cat ~/.pi/agent/pi_daily_capture/cron.log

# Force an immediate run for testing
systemctl --user start pi-daily-capture.service
```

### Troubleshooting

If the capture isn't running:

1. **Timer not active:** `systemctl --user enable --now pi-daily-capture.timer`
2. **Stow not done:** The timer references `~/.pi/agent/pi_daily_capture/capture.py` which is created by stowing `pi-personal-tools`. Run `./setup.sh --profile personal` if the symlink is missing.
3. **Log errors:** Check `~/.pi/agent/pi_daily_capture/cron.log` for Python tracebacks or missing paths.
4. **Missing paths:** The `config.yaml` repo/note roots that don't exist on your machine are reported as "skipped" — this is normal and expected.

## Configuration

Edit `~/.pi/agent/pi_daily_capture/config.yaml` (tracked in dotfiles) to add machine-specific repo roots or note folders. Missing roots are reported under "Sources skipped / unavailable" so one shared config can work across multiple personal computers.

Sources currently supported:

- Git repos discovered below configured roots or explicit repo paths
- Markdown notes modified today below configured note roots

Same-day filtering uses Asia/Tokyo boundaries for commits and filesystem modified times. If a source cannot be timestamped precisely, the output places it under an `uncertain_same_day` note rather than treating it as definite evidence.

## Privacy and scope

The capture prefers paths, commit hashes, headings, TODOs, links, and compact diff stats. It skips obvious secret filenames and generated/vendor directories and redacts obvious secret-looking values from excerpts.
