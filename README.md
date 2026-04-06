# 🤖 DockBuddies

Cute pixel-art agents that sit on your macOS dock, showing live status of your [GitHub Copilot CLI](https://githubnext.com/projects/copilot-cli) sessions.

Each buddy represents an active Copilot agent — bouncing, blinking, and displaying what it's doing in real time (EDITING, SEARCHING, THINKING, etc.). Double-click any buddy to instantly jump to the terminal tab running that session.

![DockBuddies Demo](https://github.com/mikedelgaudio/DockBuddies/blob/main/Resources/demo.png?raw=true)

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

## 🚀 Getting Started

### Requirements

- macOS 14.0+
- Swift 5.9+
- [GitHub Copilot CLI](https://githubnext.com/projects/copilot-cli) installed and running

### Build & Run

```bash
git clone https://github.com/mikedelgaudio/DockBuddies.git
cd DockBuddies
swift build
swift run
```

The buddies will appear floating above your dock. Look for the 💬 icon in your menu bar.

### Accessibility Permission (for tab switching)

On first launch, macOS will prompt you to grant Accessibility permission. This is needed to switch terminal tabs when you double-click a buddy.

1. **System Settings → Privacy & Security → Accessibility**
2. Click **"+"** at the bottom
3. Press **Cmd+Shift+G** and paste the binary path:
   ```
   /path/to/DockBuddies/.build/arm64-apple-macosx/debug/DockBuddies
   ```
4. Toggle it **on**

> **Note:** If you're running via `swift run`, you may need to re-add the binary after rebuilding.

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
