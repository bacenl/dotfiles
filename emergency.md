# Dual Boot Emergency Mount Troubleshooting
### Windows + Omarchy (Arch Linux) — Shared NTFS Partition

---

## Symptoms
- Boot drops into **emergency mode**
- `mnt-shared.mount` fails at startup
- Errors like: `wrong fs type, bad option, bad superblock on /dev/nvmeXnXpX`

---

## Step 1 — Escape Emergency Mode First

Comment out the shared mount in fstab so the system can boot normally:

```bash
nano /etc/fstab
```

Put a `#` at the start of the `/mnt/shared` line:

```
# UUID=<your-uuid>  /mnt/shared  ntfs-3g  defaults,uid=1000,gid=1000,nofail  0  0
```

Then exit emergency mode:

```bash
exit
```

> ⚠️ Always add `nofail` to your fstab mount options to prevent emergency mode on mount failure in the future.

---

## Step 2 — Diagnose the Failure

Once booted normally, check the mount status:

```bash
systemctl status mnt-shared.mount
```

Then verify the partition exists and has a filesystem:

```bash
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
sudo blkid | grep ntfs
```

**If `FSTYPE` is blank** for your shared partition → it was never formatted. Go to Step 3.

**If `FSTYPE` shows ntfs** → go to Step 4 (Windows dirty state).

---

## Step 3 — Format the Partition (if no filesystem)

The partition exists but was never formatted as NTFS:

```bash
sudo mkfs.ntfs -f /dev/nvme0n1p7   # replace p7 with your partition
```

Get the new UUID:

```bash
sudo blkid /dev/nvme0n1p7
```

Update `/etc/fstab` with the new UUID, uncomment the line, then test:

```bash
sudo mount -a
```

---

## Step 4 — Fix Windows Dirty/Hibernated State

If the partition has NTFS but still won't mount, Windows left it in a hibernated state (Fast Startup).

**In Windows, do a full shutdown:**

Option A — Hold `Shift` then click Shut Down from the Start menu.

Option B — Run in admin Command Prompt:
```
shutdown /s /f /t 0
```

Then boot back into Omarchy and run:

```bash
sudo mount -a
```

---

## Step 5 — Install ntfs-3g (if missing)

If `pacman -S ntfs-3g` fails due to no internet (common in emergency mode), get network up first:

```bash
systemctl start NetworkManager
nmcli device wifi connect "YourWiFiName" password "YourPassword"
```

Then install:

```bash
sudo pacman -S ntfs-3g
sudo mount -a
```

---

## Step 6 — Verify UUID Matches

If the mount still fails after formatting or reinstalling Windows, the UUID may have changed:

```bash
sudo blkid /dev/nvme0n1p7       # get current UUID
cat /etc/fstab | grep shared    # check what fstab has
```

If they differ, update fstab:

```bash
sudo nano /etc/fstab
# Replace old UUID with new one
```

Test without rebooting:

```bash
sudo mount -a
```

---

## Correct fstab Line

```
UUID=<your-uuid>  /mnt/shared  ntfs-3g  defaults,uid=1000,gid=1000,nofail  0  0
```

Make sure the mount point exists:

```bash
sudo mkdir -p /mnt/shared
```

---

## Quick Reference — Common Errors

| Error | Cause | Fix |
|---|---|---|
| `wrong fs type / bad superblock` | Partition not formatted | `mkfs.ntfs -f /dev/nvmeXnXpX` |
| `Could not resolve host` | No internet in emergency mode | Comment out fstab, boot normally first |
| Mount read-only | Windows Fast Startup active | Full shutdown from Windows |
| UUID mismatch | Windows reinstall or repartition | Run `blkid` and update fstab |
| Emergency mode on boot | Missing `nofail` in fstab | Add `nofail` to mount options |
