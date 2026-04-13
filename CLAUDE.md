# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CodeIsland is a macOS app that displays real-time AI coding agent status in the Dynamic Island (notch). It connects to 9 AI coding tools via Unix socket IPC, showing session status, tool calls, permission requests, and more.

## Build Commands

```bash
# Debug build (quick iteration)
swift build && ./.build/debug/CodeIsland

# Release build (universal binary: Apple Silicon + Intel)
./build.sh
open .build/release/CodeIsland.app

# Run tests
swift test

# Run specific test file
swift test --filter ConfigInstallerTests
```

## Architecture

### Target Structure

The project uses Swift Package Manager with three targets:

- **CodeIslandCore** (`Sources/CodeIslandCore/`) — Shared models and utilities used by both the app and bridge
- **CodeIsland** (`Sources/CodeIsland/`) — Main macOS app (SwiftUI, menu bar, notch panel)
- **codeisland-bridge** (`Sources/CodeIslandBridge/`) — Lightweight CLI binary (~86KB) that hooks forward events to

### IPC Flow

```
AI Tool (Claude/Codex/Gemini/Cursor/Copilot/...)
  → Hook event triggered
    → codeisland-bridge (native Swift binary)
      → Unix socket → /tmp/codeisland-<uid>.sock
        → CodeIsland app receives event
          → Updates UI in real time
```

The bridge (`main.swift`) collects terminal environment info (tmux, iTerm, Kitty, etc.), enriches the JSON payload, and forwards it via POSIX socket.

### Key Components

| File | Purpose |
|------|---------|
| `HookServer.swift` | NWListener on Unix socket, processes incoming events, handles permission/question requests |
| `AppState.swift` | Central @Observable state manager — sessions, permissions, questions, UI surface state |
| `ConfigInstaller.swift` | Installs/uninstalls hooks in CLI tool configs (Claude, Codex, Gemini, etc.) |
| `SessionSnapshot.swift` | Session state model (Core) — status, tool history, subagents, terminal info |
| `EventNormalizer.swift` | Normalizes event names from different CLIs to internal PascalCase |
| `Models.swift` (Core) | HookEvent parsing, AgentStatus enum, tool description extraction |
| `IslandSurface.swift` | UI state enum: collapsed, expanded, approvalCard, questionCard, completionCard |
| `NotchPanelView.swift` | Main SwiftUI view for the notch panel |
| `Settings.swift` | UserDefaults-backed settings with keys and defaults |
| `L10n.swift` | Localization (English, Chinese, Turkish) |

### Supported AI Tools

Claude Code, Codex, Gemini CLI, Cursor, GitHub Copilot CLI, Qoder, Factory (Droid), CodeBuddy, OpenCode.

Each tool has different hook formats defined in `ConfigInstaller.swift`:
- `claude` — Claude Code style with matcher
- `nested` — Codex/Gemini style (hooks array only)
- `flat` — Cursor style (simple command)
- `copilot` — GitHub Copilot CLI style (type/bash/timeoutSec)

### UI Architecture

- SwiftUI with `@Observable` macro for state management
- Panel window controlled by `PanelWindowController.swift`
- Settings in separate window via `SettingsWindowController.swift`
- Mascot animations via `PixelCharacterView.swift` and `MascotView.swift`

## Development Notes

### macOS Requirements

- macOS 14.0+ (Sonoma)
- Swift 5.9+
- Works on MacBooks with notch, also supports external displays

### Hook Event Types

Key events handled (see `EventNormalizer.swift` for full mapping):
- `SessionStart`, `SessionEnd` — Session lifecycle
- `PreToolUse`, `PostToolUse` — Tool execution
- `PermissionRequest` — Permission approval flow (blocking)
- `Notification` — Status updates, questions
- `SubagentStart`, `SubagentStop` — Subagent lifecycle

### Permission Handling

`HookServer.swift` auto-approves safe internal tools (TaskCreate, TaskUpdate, EnterPlanMode, etc.) without UI. Other permissions show approval card in notch.

### Terminal Detection

The bridge detects terminal environment via environment variables:
- `TERM_PROGRAM`, `__CFBundleIdentifier` — Terminal app
- `ITERM_SESSION_ID` — iTerm2 session
- `KITTY_WINDOW_ID` — Kitty window
- `TMUX`, `TMUX_PANE` — tmux pane and client TTY
- `CMUX_SURFACE_ID`, `CMUX_WORKSPACE_ID` — cmux surface

### Localization

Language stored in `SettingsKey.appLanguage`. Supported: "system", "en", "zh", "tr". Access via `L10n.shared["key"]`.