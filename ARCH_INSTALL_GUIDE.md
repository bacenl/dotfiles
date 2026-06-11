# Arch Installation for Omarchy

This guide installs vanilla Arch Linux as the base for Omarchy. For a machine
that already contains Windows, follow [dual_boot.md](dual_boot.md) for disk
preparation and use this guide for the common installation steps.

The authoritative upstream references are:

- [Omarchy manual installation](https://learn.omacom.io/2/the-omarchy-manual/96/manual-installation)
- [Arch installation guide](https://wiki.archlinux.org/title/Installation_guide)

## Before starting

- Back up all important data.
- Download the current Arch ISO from <https://archlinux.org/download/>.
- Write it to a USB drive and disable Secure Boot before booting it.
- Use a wired or 2.4 GHz keyboard if enabling LUKS; Bluetooth is unavailable at
  the pre-boot password prompt.

Disk operations are destructive. Replace every example device name with values
confirmed by `lsblk -f`.

## 1. Boot and connect

Verify UEFI mode and network connectivity:

```bash
ls /sys/firmware/efi/efivars
ping -c 3 archlinux.org
```

For Wi-Fi:

```text
iwctl
station wlan0 scan
station wlan0 connect <network>
exit
```

The wireless interface may not be named `wlan0`; check `device list` inside
`iwctl`.

## 2. Run archinstall

```bash
archinstall
```

For a machine dedicated to Arch, use the current official Omarchy choices:

| Section | Choice |
|---|---|
| Mirrors | Your region |
| Disk layout | Default layout on the intended disk |
| File system | Btrfs, default subvolumes, compression enabled |
| Disk encryption | LUKS applied to the Linux partition |
| Bootloader | Limine |
| User | Create a superuser account |
| Audio | PipeWire |
| Network | Copy ISO network configuration |
| Profile | Do not select a desktop profile |
| Timezone | Your timezone |

For dual boot, do not choose an option that wipes the whole disk. Use the
partitioning instructions in [dual_boot.md](dual_boot.md), preserve the Windows
partitions, and mount the existing EFI System Partition without formatting it.

Review the generated configuration carefully before selecting Install. Confirm
that only the intended Linux partitions are marked for formatting.

## 3. Install Omarchy

After Arch finishes, reboot, remove the USB drive, and log in as the created
user. Then run the current official installer:

```bash
curl -fsSL https://omarchy.org/install | bash
```

Omarchy asks for sudo access and Git identity information, completes its setup,
and offers to reboot.

## 4. Install personal setup

After the Omarchy reboot, follow [INSTALL.md](INSTALL.md). The public curl
bootstrap installs the browser, GitHub CLI, Syncthing, and dotfiles without
requiring browser or GitHub setup first.
