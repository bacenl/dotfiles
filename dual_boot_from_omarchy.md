# Add Windows 11 to an Existing Unencrypted Omarchy Install

This guide adds Windows 11 beside the Omarchy installation already on this
machine. It deliberately does **not** create a shared data partition.

It applies only to the current layout, verified on this machine:

```text
/dev/nvme0n1      953.9 GiB  GPT disk
├─/dev/nvme0n1p1    1 GiB    FAT32 EFI System Partition, mounted at /boot
└─/dev/nvme0n1p2  952.9 GiB  unencrypted Btrfs, mounted as /
```

`/dev/nvme0n1p2` is a plain Btrfs filesystem, not LUKS-encrypted. There is no
`crypto_LUKS` device or `/dev/mapper` root mapping. **Do not use any LUKS or
cryptsetup resizing instructions.**

This is a destructive-adjacent operation: a backup and careful partition
identification are mandatory. Stop if any screen differs materially from this
guide.

## 1. Prepare recovery media and backups

1. Back up all files from Omarchy to a separate physical disk or cloud service.
   Verify that the backup can be read.
2. Create an Omarchy or Arch Linux live USB. It is the recovery environment if
   Btrfs or Limine fails to boot.
3. Create a Windows 11 installation USB using Microsoft's Media Creation Tool.
   It needs a blank USB drive of at least 8 GB.
4. Create or retain Windows recovery media. If the machine already has a
   Windows license in firmware, Windows Setup usually detects it automatically;
   otherwise have the product key available.
5. Photograph or save the current firmware boot entries:

   ```bash
   sudo efibootmgr -v
   ```

6. Confirm the layout one last time. The output must show `vfat` on `p1` and
   `btrfs` directly on `p2`:

   ```bash
   lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS
   findmnt /
   findmnt /boot
   ```

Do not proceed if `p2` is not the Btrfs root partition, if another disk is
present and its identity is unclear, or if the backup is incomplete.

## 2. Create unallocated space with an Arch live USB

Do this from the Arch live USB, not while Omarchy is running. Btrfs can shrink
while mounted, but changing the partition boundary of the running root disk is
unnecessarily risky.

The commands below release **250 GiB** from Btrfs, producing 250 GiB of
unallocated space for Windows. They are valid only because `p2` is the final
partition on this disk and currently ends at the end of the disk. Do not adapt
them to a different layout without recalculating the partition endpoint.

1. Boot the Arch USB in **UEFI** mode and connect to the network if needed.
2. Confirm the disk layout again. The output must show only the existing EFI
   partition followed by the Btrfs root partition:

   ```bash
   lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS
   sudo parted /dev/nvme0n1 unit GiB print free
   ```

   Stop unless `p1` is the 1 GiB FAT32 EFI partition and `p2` is the final,
   approximately 952.9 GiB Btrfs partition.
3. Mount the Btrfs top-level subvolume and confirm it is the expected
   filesystem:

   ```bash
   sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt
   sudo btrfs filesystem usage /mnt
   ```

   Ensure the estimated free space plus the unused device space is sufficient
   to reduce the filesystem by 250 GiB. If it is not, stop and free data from
   Omarchy before trying again.
4. Shrink Btrfs by exactly 250 GiB. This may take a long time while Btrfs moves
   extents; do not interrupt it:

   ```bash
   sudo btrfs filesystem resize -250G /mnt
   sudo btrfs filesystem show /mnt
   ```

   The `G` suffix means GiB. If the resize fails, do not change the partition;
   unmount and reboot to Omarchy, free more space, and retry from this section.
5. Unmount Btrfs:

   ```bash
   sudo umount /mnt
   ```

6. Reduce only the **end** of partition 2 by the same 250 GiB. This command
   preserves partition 2's starting offset and changes no other partition:

   ```bash
   sudo parted --script /dev/nvme0n1 unit GiB resizepart 2 -250GiB
   sudo partprobe /dev/nvme0n1
   sudo parted /dev/nvme0n1 unit GiB print free
   ```

   Confirm that `p1` is unchanged, `p2` is about 250 GiB smaller than before,
   and there is about 250 GiB of **unallocated** space after `p2`.
7. Check the now-unmounted Btrfs filesystem read-only:

   ```bash
   sudo btrfs check --readonly /dev/nvme0n1p2
   ```

   Do not run `btrfs check --repair`.
8. Reboot into Omarchy before installing Windows. Confirm that it starts and
   that the root filesystem is still `/dev/nvme0n1p2` Btrfs:

   ```bash
   findmnt /
   lsblk -f
   ```

   If Omarchy does not boot, stop and boot the Arch USB again; do not start the
   Windows installer until Omarchy is working.

## 3. Set firmware options

1. Enter firmware setup.
2. Keep boot mode set to **UEFI**. Disable Legacy/CSM boot if it is enabled.
3. Do not change the storage-controller mode (AHCI, RAID, RST, or VMD).
4. Leave Secure Boot in the state that currently lets Omarchy boot. For a stock
   Omarchy/Limine install this will commonly be disabled. Windows 11 requires
   Secure-Boot capability, not necessarily that Secure Boot be enabled during
   this installation.
5. Use the one-time boot menu to boot the Windows USB entry labelled
   **UEFI: ...**. Do not select a Legacy/BIOS USB entry.

## 4. Install Windows into only the unallocated space

1. Start Windows Setup and choose **Install now**.
2. Select **Custom: Install Windows only (advanced)**.
3. At **Where do you want to install Windows?**, identify the 953.9 GiB target
   disk by its total size.
4. Select only the row named `Disk <number> Unallocated Space`. Its size must
   match the space created in section 2.
5. Click **Next**.

Windows Setup creates its own Microsoft Reserved, NTFS, and recovery partitions
inside that selected free area. It may add its boot files to the existing 1 GiB
EFI System Partition; this is expected. The EFI partition is large enough for
Windows' documented minimum.

### Absolute prohibitions at the disk-selection screen

- Do **not** click **Delete**, **Format**, **New**, **Extend**, or **Load
driver** on an existing partition.
- Do **not** select `/dev/nvme0n1p1` (the existing FAT32 EFI partition).
- Do **not** select the existing Btrfs partition, which Windows may show as an
  unknown or primary partition.
- Do **not** open a command prompt or run `diskpart`, especially `clean` or
  `convert`. Microsoft's whole-disk installation procedure is not applicable
  to this dual-boot disk.

If the only selectable target is not precisely the expected unallocated space,
cancel Setup and return to section 2.

## 5. Finish Windows setup without changing Linux

1. Complete Windows Setup and allow it to reboot normally.
2. Install Windows updates and confirm Windows boots twice.
3. Disable Fast Startup in Windows before ever mounting its NTFS system volume
   from Linux.
4. Do not enable BitLocker or device encryption until both operating systems
   boot successfully and the BitLocker recovery key is safely stored.

Windows will normally make Windows Boot Manager first in UEFI boot order. This
is expected; Microsoft's BCDBoot documentation describes this default behavior.

## 6. Boot Omarchy and add the Windows entry to Limine

1. Reboot and open the firmware one-time boot menu.
2. Select the existing Omarchy/Limine entry. Do not select Windows Boot
   Manager.
3. After Omarchy starts, confirm the root filesystem is unchanged:

   ```bash
   findmnt /
   lsblk -f
   ```

4. Ask Limine to discover Windows:

   ```bash
   sudo limine-scan
   ```

   Approve the Windows Boot Manager entry. If `limine-scan` is unavailable,
   use:

   ```bash
   sudo limine-entry-tool --scan
   ```

5. Verify that Limine has a Windows entry:

   ```bash
   sudo grep -n -A8 -B2 -i windows /boot/limine.conf
   ```

6. Reboot and test all three routes:
   - Limine -> Omarchy
   - Limine -> Windows Boot Manager
   - firmware boot picker -> Windows Boot Manager

Keep the direct firmware Windows Boot Manager entry as a permanent recovery
path.

## 7. Restore the preferred boot order

Use the firmware setup UI to place the existing Omarchy/Limine boot entry above
Windows Boot Manager. This is safer than copying generic `efibootmgr -o`
commands, because UEFI boot numbers differ per machine.

Reboot twice. Limine should appear by default, and both OS entries should work.

## 8. After installation

- Keep Fast Startup disabled.
- Enable BitLocker only after storing its recovery key. Firmware, Secure Boot,
  or bootloader changes can trigger a recovery-key prompt.
- Do not enable Secure Boot later unless Omarchy's Limine setup has been
  explicitly configured and tested for Secure Boot. A stock unsigned setup may
  no longer boot if it is enabled.
- There is intentionally no shared NTFS partition in this layout.

## Verified references

- Microsoft, [Create installation media for Windows](https://support.microsoft.com/en-us/windows/create-installation-media-for-windows-99a58364-8c02-206f-aa6f-40c3b507420d)
- Microsoft, [Windows Setup: UEFI and GPT partition style](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-installing-using-the-mbr-or-gpt-partition-style?view=windows-11)
- Microsoft, [UEFI/GPT partition requirements](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions?view=windows-11)
- Microsoft, [BCDBoot and UEFI boot-order behavior](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/bcdboot-command-line-options-techref-di?view=windows-11)
- ArchWiki, [Btrfs](https://wiki.archlinux.org/title/Btrfs)
- Omarchy community guidance, [Limine Windows discovery](https://github.com/basecamp/omarchy/discussions/5306)
