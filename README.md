# Updates

An Omarchy bar plugin that checks **Arch**, **Omarchy** and **AUR** updates in
one go, from a single flyout.

## Install

```bash
omarchy plugin add https://github.com/DeV-433/Updates
```

When asked, choose to enable it and pick where it goes on the bar (it defaults
to `right`).

## Usage

1. Click the box icon on the bar to open the flyout.
2. Press **Check**. Arch, Omarchy and AUR are checked together.
3. Pending updates are listed by package name, repo and `old → new` version,
   with the changed part of the new version highlighted. A colored bar shows
   the split between repos, and the chips above the list filter it by repo.
4. Click **Install N updates** to launch the Omarchy update in a floating
   terminal.

Notes:

- Nothing is checked in the background; it only runs when you press **Check**.
- If Arch or AUR can't be checked, the flyout says so instead of showing "up to date".
- When a kernel, systemd, glibc, CPU microcode or NVIDIA driver update is
  pending, the flyout says to reboot afterwards and marks those packages.

## Requirements

`checkupdates` (from `pacman-contrib`) and `yay`, both present on a standard
Omarchy install.

## License

MIT
