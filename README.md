# 🤖 DockBuddies

Cute pixel-art agents that sit on your macOS dock, showing live status of your [GitHub Copilot CLI](https://githubnext.com/projects/copilot-cli) sessions.

Each buddy represents an active Copilot agent — bouncing, blinking, and displaying what it's doing in real time (EDITING, SEARCHING, THINKING, etc.). Double-click any buddy to instantly jump to the terminal tab running that session.

![DockBuddies Demo](https://github.com/mikedelgaudio/DockBuddies/blob/main/Resources/demo.gif?raw=true)

## ✨ Features

- **Live Copilot status** — Polls `~/.copilot/` for active sessions via lock files, SQLite, and event streams
- **Pixel-art agents** — 16×16 blob robots in 4 colors (orange, green, red, teal), drawn entirely in code
- **Idle animations** — Gentle bounce, random blinking, antenna glow with staggered timing per agent
- **Hover feedback** — Pointer cursor + scale/glow effect on hover
- **Click for details** — Popover showing repo, branch, working directory, turn count, and PID
- **Double-click to focus terminal** — Instantly switches to the terminal tab running that Copilot session
- **Terminal support** — Ghostty (with tab switching), Terminal.app, iTerm2, Warp, kitty, Alacritty, WezTerm, Hyper
- **Dynamic count** — Shows N buddies for N active sessions (no fixed limit)
- **Menu-bar only** — No dock icon; lives in your menu bar with a toggle shortcut
- **Accessible** — Full VoiceOver support with labels, hints, and button traits

## 🚀 Install

### Requirements

- macOS 14.0 (Sonoma) or later — works on both Apple Silicon and Intel
- [GitHub Copilot CLI](https://githubnext.com/projects/copilot-cli) installed and running (optional, but you won't see any buddies without active sessions)

### From the latest release (recommended)

1. Go to [**Releases**](https://github.com/mikedelgaudio/DockBuddies/releases/latest) and download `DockBuddies-X.Y.Z.dmg`.
2. Open the `.dmg`. A window appears with **DockBuddies.app** and an **Applications** shortcut.
3. **Drag `DockBuddies.app` onto `Applications`.**
4. Eject the disk image, then launch DockBuddies from Launchpad / Spotlight / `/Applications`.

> **First launch — Gatekeeper warning.** The release `.app` is ad-hoc signed, not notarized
> by Apple. The first time you open it, macOS will say *"DockBuddies cannot be opened because
> the developer cannot be verified."* Right-click (or Control-click) the app in Finder and
> choose **Open** — accept the prompt once and the warning won't appear again.

### Accessibility permission (for tab switching)

Double-clicking a buddy to focus its terminal tab requires the Accessibility permission.

1. Double-click any buddy. macOS will prompt you to grant Accessibility.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Toggle **DockBuddies** on.

The permission is tracked by bundle ID, so it persists across version upgrades — you only
grant it once.

## 🧹 Uninstall

DockBuddies stores nothing on your system other than the app bundle and an Accessibility
entry. To remove it completely:

1. Quit DockBuddies (menu bar → **Quit**).
2. Drag `/Applications/DockBuddies.app` to the Trash.
3. Open **System Settings → Privacy & Security → Accessibility**, select **DockBuddies**, and click the **−** button to revoke the permission.

That's it — there are no caches, preferences, or launch agents to clean up.

## 🛠️ Build from source

### Requirements

- macOS 14.0+
- Swift 5.9+ (Xcode 15 or Command Line Tools — full Xcode is required for **universal** builds)

### Quick development loop

```bash
git clone https://github.com/mikedelgaudio/DockBuddies.git
cd DockBuddies

# Run directly (debug, fastest iteration)
make run

# Or build a debug .app at .build/DockBuddies.app
make app
open .build/DockBuddies.app
```

The Accessibility permission for `make app` is tracked by bundle ID at the
`.build/` path, so it survives rebuilds during development.

### Build a release .app and .dmg

```bash
make dmg
```

This runs the two scripts under `scripts/`:

| Script | Output |
|--------|--------|
| `scripts/build-app.sh` | `dist/DockBuddies.app` (release, ad-hoc signed; universal when full Xcode is installed, otherwise host-arch) |
| `scripts/build-dmg.sh` | `dist/DockBuddies.dmg` (drag-to-install layout) |

The `dist/` directory is git-ignored — release artifacts are **never** committed; they are only
published as GitHub Release assets by the workflow described below.

### Cutting a release

Releases are produced by [`.github/workflows/release.yml`](.github/workflows/release.yml) on
the `macos-14` runner (which has full Xcode, so the `.dmg` it ships is a true arm64 + x86_64
universal binary).

```bash
# 1. Tag the commit you want to release.
git tag v1.2.3
git push origin v1.2.3

# 2. The Release workflow will:
#    - build dist/DockBuddies-1.2.3.dmg with the version stamped into Info.plist
#    - publish a GitHub Release with auto-generated notes and the .dmg attached
```

You can also trigger the workflow manually from the **Actions** tab (`workflow_dispatch`)
to test the build without cutting a public release — the `.dmg` is uploaded as a workflow
artifact instead.

## 🎮 Usage

| Action | What happens |
|--------|-------------|
| **Hover** | Pointer cursor + scale up with colored glow |
| **Single click** | Opens detail popover (repo, branch, PID, etc.) |
| **Double-click** | Instantly focuses the terminal tab running that session |
| **Menu bar → Show/Hide** | Toggle buddy visibility (Cmd+B) |
| **Menu bar → Quit** | Exit DockBuddies |

## 🏗️ Architecture

```
Sources/DockBuddies/
├── App/                    # App entry + menu bar setup
├── Window/                 # Transparent overlay panel + dock detection
├── Models/                 # AgentInfo, AgentColor (4 palettes)
├── PixelArt/               # 16×16 sprite grid, Canvas renderer, animations
├── Services/               # Copilot poller, SQLite reader, event parser, terminal focuser
└── Views/                  # Overlay, character, status bubble, detail popover
```

### How status detection works

1. **Lock files** — Scans `~/.copilot/session-state/*/inuse.*.lock` for active PIDs
2. **SQLite** — Queries `~/.copilot/session-store.db` for session metadata (repo, branch, summary)
3. **Event stream** — Reads the tail of `events.jsonl` for real-time tool activity

### How terminal focus works

1. Walks up the process tree from the Copilot PID via `sysctl` to find the parent terminal
2. Activates the terminal app via `NSRunningApplication`
3. For **Ghostty**: matches the process TTY against Ghostty's child processes to find the tab index, then sends `Cmd+N` via `CGEvent`
4. For **Terminal.app / iTerm2**: uses AppleScript to find and select the correct tab/window

## 📝 License

MIT
