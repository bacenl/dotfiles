# References
[Single Drive](https://www.youtube.com/watch?v=kE0foLfYkfk)
[Two Drive](https://www.youtube.com/watch?v=vsxAbDcTPRU)

## What You Need
- Windows 11 already installed on your single drive
- Two USB drives: one for the Omarchy ISO, one to keep handy (optional backup)
- Secure Boot disabled in BIOS
- A wired or 2.4GHz dongle keyboard (Bluetooth won't work at the LUKS prompt)

---

## Phase 1: Shrink Windows to Make Free Space

**Step 1 — Create a restore point in Windows**
Search for "restore point" in the Start menu and create one. Safety net in case anything goes wrong.

**Step 2 — Disable BitLocker (if on Windows 11 Pro)**
BitLocker can interfere with Linux. Windows 11 Home users can skip this.

**Step 3 — Shrink your Windows partition**
Right-click the desktop > Open Terminal, type:
```
diskmgmt.msc
```
Right-click your C: drive > **Shrink Volume**. Decide how to split your remaining space across three uses:
- Omarchy (recommend at least 60–100GB)
- Windows keeping enough to breathe (at least 60GB free)
- Shared NTFS partition (whatever you want left over)

For example on a 1TB drive with Windows using ~200GB, you might shrink by 600GB, leaving 400GB for Omarchy and 200GB for shared. Just shrink the total combined amount for now — you'll carve it up precisely later. Click **Shrink**.

You now have unallocated free space on your drive.

---

## Phase 2: Create Partitions from the Arch Linux Live USB

**Step 4 — Flash the Omarchy/Arch Linux ISO**
Download the Arch Linux ISO from archlinux.org. Flash it to a USB with Balena Etcher or Rufus.

**Step 5 — Boot into Arch Linux**
Enter BIOS (F2/Del/F7), disable Secure Boot, set USB as first boot device. Boot into Arch. You'll land at:
```
root@archiso ~#
```
Connect to Wi-Fi if needed:
```
iwctl
station wlan0 scan
station wlan0 connect <your-network>
```

**Step 6 — Partition the free space with cfdisk**
```
lsblk
```
Identify your drive (likely `nvme0n1`). Then:
```
cfdisk /dev/nvme0n1
```
You'll see your existing Windows partitions (EFI, Windows, Recovery) and the unallocated free space at the bottom. In the free space, create three new partitions:

- **Partition A — Omarchy root:** Your chosen size (e.g. 400GB), type: `Linux filesystem`
- **Partition B — Windows Reserved:** 128MB, type: `Microsoft reserved` (some guides use 128M with type `0C01` via gdisk — cfdisk may not have this exact type, which is fine to skip)
- **Partition C — Shared NTFS:** Remaining space, type: `Microsoft basic data`

Select **Write**, type `yes`, then **Quit**.

**Step 7 — Format the partitions**
Format the Omarchy root partition as btrfs:
```
mkfs.btrfs -f /dev/nvme0n1pX   # replace X with your Omarchy partition number
```
Format the shared partition as NTFS:
```
mkfs.ntfs /dev/nvme0n1pY    # replace Y with your shared partition number
```
Leave the Windows reserved partition alone.

**Step 8 — Mount the partitions**
```
mount /dev/nvme0n1pX /mnt
mkdir /mnt/boot
mount /dev/nvme0n1pY /mnt/boot   # pY is usually the existing Windows EFI partition
```
Verify with `lsblk` that everything looks right.

---

## Phase 3: Install Arch + Omarchy

**Step 9 — Run archinstall**
```
archinstall
```
Configure all settings per the [Omarchy manual install docs](https://learn.omacom.io/2/the-omarchy-manual/96/manual-installation). The critical choices:

- **Disk configuration:** Choose **Pre-mounted configuration**, set mount path to `/mnt`
- **Bootloader:** Select **Limine** — make sure "Install to removable location" is **disabled**
- **Hostname, user, password, timezone, locale:** Set as desired
- **Audio:** Pipewire
- **Network:** First option
- **Do not select a profile**

Hit **Install** and wait.

**Step 11 — Reboot**
Remove the USB. Your system should boot into Arch CLI. Log in with your username and password, then install Omarchy:
```
curl -fsSL https://omarchy.org | bash
```
Reboot when done.

---

## Phase 4: Add Windows to the Boot Menu

**Step 12 — Add Windows to Limine**
Boot into Omarchy, open a terminal (Super + Enter):
```
sudo limine-scan
```
Find the Windows Boot Manager entry and select it to add it to Limine. Verify with:
```
cat /boot/limine.conf
```
You should see a Windows entry. If the auto-detect doesn't work, add it manually:
```
sudo nano /boot/limine.conf
```
Add:
```
/Windows
  comment: Microsoft Windows 11
  comment: order-priority=20
  protocol: efi_chainload
  image_path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
```

---

## Phase 5: Set Up the Shared NTFS Partition

**Step 13 — Format shared partition in Windows**
Reboot into Windows. Open Disk Management (`diskmgmt.msc`). Find the unformatted partition you created for sharing. Right-click > **New Simple Volume**, format as NTFS, assign a drive letter (e.g. `D:`), label it `Shared`.

**Step 14 — Disable Fast Startup in Windows**
Control Panel > Power Options > Choose what the power buttons do > uncheck **Turn on fast startup**. Without this, Linux will mount the NTFS partition as read-only.

**Step 15 — Mount the shared partition in Omarchy**
Reboot into Omarchy. Find the UUID of your shared partition:
```
sudo blkid /dev/nvme0n1pY
```
Create a mount point and add it to fstab:
```
sudo mkdir /mnt/shared
sudo nano /etc/fstab
```
Add this line:
```
UUID=<your-uuid>  /mnt/shared  ntfs-3g  defaults,uid=1000,gid=1000,nofail  0  0
```
Test it:
```
sudo mount -a
```
No errors means you're good. Optionally create a symlink for easy access from your home folder:
```
ln -s /mnt/shared ~/shared
```

---

## Final Partition Layout

| Partition | Type | Purpose |
|---|---|---|
| p1 (existing) | FAT32 EFI | Shared bootloader (Windows + Limine) |
| p2 (existing) | NTFS | Windows 11 |
| p3 (existing) | NTFS | Windows Recovery |
| p4 (new) | btrfs | Omarchy Linux |
| p5 (new) | Microsoft reserved | Windows reserved (128MB) |
| p6 (new) | NTFS | Shared between both OS |

Your partition numbers will vary — always double-check with `lsblk` before formatting anything.

---
## Other things to set up
### Basic
Set up browser and git to get the set-up repo

### Languages
```bash
fcitx5-config-qt
```
Add these to `~/.config/environment.d/fcitx5.conf` (create it if it doesn't exist):

```ini
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
```
Add this line to `~/.config/hypr/hyprland.conf` (or a custom conf file Omarchy includes):
```
exec-once = fcitx5 --replace -d
```
Run the config tool:

```bash
fcitx5-config-qt
```

In the configuration tool, add your desired input methods — **Mozc** for Japanese, and **Pinyin** (for Simplified Chinese) or **Cangjie/Bopomofo** (for Traditional). Click Apply after adding them.

Switching between inputs is typically **Ctrl+Space** by default.

---

Electron apps need an extra flag to use Fcitx5. Create a flags file for each app, e.g. for VS Code:

```bash
# ~/.config/code-flags.conf
--enable-wayland-ime
```
