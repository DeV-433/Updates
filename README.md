# Updates

An Omarchy bar plugin that checks **Arch**, **Omarchy** and **AUR** updates, plus
updates for your git-installed **shell plugins**, from a single flyout.

## Install

```bash
omarchy plugin add https://github.com/DeV-433/Updates
```

When asked, choose to enable it and pick where it goes on the bar (it defaults
to `right`).

## Usage

1. Click the layers icon on the bar to open the flyout. Its three layers are
   Arch (bottom), Omarchy (middle) and AUR (top). The icon turns solid when
   any system update is pending, and while checking, the layers still being
   checked pulse from the bottom up.
2. Press **Check**. Arch, Omarchy, AUR and your plugins are checked together,
   and each source ticks off as it finishes.
3. Pending updates are listed by package name, repo and `old → new` version,
   with the changed part of the new version highlighted. A colored bar shows
   the split between repos, and the breakdown beside the count filters the
   list by repo.
4. Click **Install N system updates** to launch the Omarchy update in a floating
   terminal.
5. Below that, the **Plugins** section lists every plugin installed with
   `omarchy plugin add` that is behind its upstream, with `old → new` version
   (or commit) and how many commits it is behind (`+N`). Update one with its row
   button, or all of them with **Install N plugin updates**. Plugins are
   fast-forwarded, validated, and rolled back if validation fails, and the
   shell reloads once at the end with a notification summarising the result.

Notes:

- Nothing is checked in the background; it only runs when you press **Check**.
  For plugins this runs `git fetch` in each plugin folder.
- A plugin with local commits or edits can't be fast-forwarded, so it is
  hidden and left for you to update by hand. The eye button beside **PLUGINS**
  shows these plugins.
- Plugin results are cached in `~/.cache/omarchy-updatecheck/plugins.tsv`, so
  they survive the shell reload an update causes.
- If Arch or AUR can't be checked, the flyout says so instead of showing "up to date".
- When a kernel, systemd, glibc, CPU microcode or NVIDIA driver update is
  pending, the flyout says to reboot afterwards and marks those packages.

## Requirements

`checkupdates` (from `pacman-contrib`), `yay`, `git` and `jq`, all present on a standard
Omarchy install.

## License

MIT
