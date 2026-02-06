# Monthly Markdown Header Squasher - Installation Instructions

## Files Included
1. `~/.config/fish/functions/squash_headers.fish` - The main function
2. `~/.local/bin/monthly_squash.fish` - Wrapper script that runs monthly
3. `~/.config/systemd/user/monthly-squash.service` - Systemd service file
4. `~/.config/systemd/user/monthly-squash.timer` - Systemd timer file

## Installation Steps
### 1. Update Systemd Timer (User Level)
```bash
# Reload systemd daemon
systemctl --user daemon-reload

# Enable and start the timer
systemctl --user enable monthly-squash.timer
systemctl --user start monthly-squash.timer
```

### 2. Verify Update
```bash
# Check timer status
systemctl --user status monthly-squash.timer

# List all timers to see when it will run next
systemctl --user list-timers

# Test the service manually
systemctl --user start monthly-squash.service

# Check the logs
journalctl --user -u monthly-squash.service
```

## How It Works

1. On the 1st of each month at 00:05 (5 minutes past midnight), the timer triggers
2. The service runs `monthly_squash.fish`
3. The script determines the previous month (e.g., if it's February, it gets "jan")
4. It looks for `jan.md` in your specified directory
5. It runs `squash_headers jan.md` which creates `output_jan.md`
6. The consolidated output is saved as `output_jan.md`

## Manual Usage

You can also run the function manually anytime:
```fish
# In fish shell
squash_headers jan.md  # Creates output_jan.md
squash_headers feb.md  # Creates output_feb.md
```

## Troubleshooting

If the timer doesn't run:
```bash
# Check if the timer is active
systemctl --user is-active monthly-squash.timer

# Check for errors in the logs
journalctl --user -u monthly-squash.service -n 50

# Test the script manually
fish ~/.local/bin/monthly_squash.fish
```

## Notes

- The timer uses `Persistent=true`, so if your computer is off on the 1st, it will run when you next boot
- All logs are stored in the systemd journal
- The timer runs at the user level, so it doesn't require root access
- Make sure fish is installed: `sudo pacman -S fish`
