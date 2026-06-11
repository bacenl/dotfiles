# Windows 11 and Omarchy Dual Boot

This guide assumes Windows 11 is already installed in UEFI mode and Arch Linux
will be installed beside it on the same disk. Read
[ARCH_INSTALL_GUIDE.md](ARCH_INSTALL_GUIDE.md) before starting.

## Requirements

- A verified backup of important files.
- A Windows recovery drive or installer.
- The Windows BitLocker recovery key, even if BitLocker will be suspended.
- An Arch Linux USB drive.
- Secure Boot disabled.
- A wired or 2.4 GHz keyboard for the LUKS prompt.

Partition names in this guide are placeholders. Confirm the disk, partition
type, filesystem, size, and labels with `lsblk -f` before formatting anything.
Never format the Windows EFI, Windows data, or recovery partitions.

## 1. Prepare Windows

1. Install pending Windows updates and create a restore point.
2. Back up the BitLocker recovery key. Suspend or disable BitLocker before
   changing partitions.
3. Disable Fast Startup in Control Panel under Power Options.
4. Open Disk Management with `diskmgmt.msc`.
5. Shrink `C:` to create unallocated space for Linux and, optionally, a shared
   data partition.

Leave the Linux portion unallocated. Windows can create and format an optional
shared NTFS volume now. Do not create another Microsoft Reserved partition;
Windows already created the one it needs.

## 2. Boot the Arch USB

Boot the USB in UEFI mode and connect to the network as described in
[ARCH_INSTALL_GUIDE.md](ARCH_INSTALL_GUIDE.md).

Inspect the disk:

```bash
lsblk -o NAME,SIZE,FSTYPE,FSVER,LABEL,PARTLABEL,MOUNTPOINTS
```

Identify:

- The existing EFI System Partition, normally FAT32 and a few hundred MiB.
- The Windows NTFS partition.
- The Windows recovery partition.
- The unallocated space created in Windows.

## 3. Partition for Arch

Start `cfdisk` against the whole target disk, for example:

```bash
cfdisk /dev/nvme0n1
```

Create one Linux filesystem partition in the unallocated space. Optionally
create a Microsoft basic data partition for shared NTFS storage if Windows did
not create it.

Do not delete, resize, or format any existing Windows partition. Write the new
partition table only after checking every entry.

## 4. Install Arch

Run:

```bash
archinstall
```

Use manual partitioning so the existing Windows partitions are preserved:

- Select the new Linux partition for the Btrfs root filesystem.
- Enable LUKS encryption on the Linux partition.
- Reuse the existing EFI System Partition as `/boot`.
- Do not enable formatting for the EFI System Partition.
- Select Limine as the bootloader.
- Use PipeWire, copy the ISO network configuration, and do not select a desktop
  profile.

The archinstall interface changes over time. Before installation, inspect its
summary and verify that formatting is enabled only for the new Linux partition.
If the summary proposes formatting the EFI or any Windows partition, cancel and
correct the configuration.

Complete the remaining choices using
[ARCH_INSTALL_GUIDE.md](ARCH_INSTALL_GUIDE.md), then install and reboot.

## 5. Install Omarchy

Log in to the new Arch system and run:

```bash
curl -fsSL https://omarchy.org/install | bash
```

Allow Omarchy to finish and reboot.

## 6. Add Windows to Limine

From Omarchy:

```bash
sudo limine-scan
```

Review the resulting boot entries:

```bash
sudo grep -n -A8 -B2 -i windows /boot/limine.conf
```

Reboot and test both Omarchy and Windows. Keep the firmware's Windows Boot
Manager entry available as a fallback until both paths have been tested.

## 7. Mount an optional shared NTFS volume

Boot Windows first, assign the shared volume a drive letter, format it as NTFS
if necessary, and confirm Fast Startup remains disabled.

Back in Omarchy, find its UUID:

```bash
lsblk -f
```

Create a mount point:

```bash
sudo mkdir -p /mnt/shared
```

Add an `/etc/fstab` entry using the actual UUID:

```fstab
UUID=<shared-ntfs-uuid> /mnt/shared ntfs3 uid=1000,gid=1000,umask=022,nofail,x-systemd.automount 0 0
```

Confirm the user's numeric IDs with `id -u` and `id -g`; replace `1000` if
needed. Validate before rebooting:

```bash
sudo mount -a
findmnt /mnt/shared
```

## 8. Run personal setup

Follow [INSTALL.md](INSTALL.md) to install Vivaldi, GitHub CLI, Syncthing,
dotfiles, language support, and NetworkManager. GitHub authentication,
Syncthing pairing, and input-method selection are the final interactive steps
after automation completes.
