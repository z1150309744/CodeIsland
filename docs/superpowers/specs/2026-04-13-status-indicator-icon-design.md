# Status Indicator Icon Design

**Date:** 2026-04-13
**Author:** Claude + User
**Status:** Draft

## Overview

Add a new status bar icon to display real-time AI coding agent session counts (active/idle), positioned to the left of the existing menu icon. Clicking the icon reveals a popup menu listing all sessions with their status indicators.

## Requirements

| Item | Decision |
|------|----------|
| Function | Display active/idle agent counts |
| Format | SF Symbols icon + numbers (e.g., `🤖 3/1`) |
| Position | New independent icon, left side of menu icon |
| Interaction | Click to popup session detail menu |
| Menu Content | Agent name + status icon only (e.g., `Claude 🟢`) |

## Architecture

```
AppDelegate
    ├── StatusItemController (existing, menu icon)
    └── StatusIndicatorController (new, status icon)
            │
            ├── statusItem: NSStatusItem
            ├── indicatorMenu: NSMenu
            └── Subscribes to AppState.sessions
```

## Files

### New File

**`Sources/CodeIsland/StatusIndicatorController.swift`**

```swift
@MainActor
final class StatusIndicatorController: NSObject {
    static let shared = StatusIndicatorController()

    private var statusItem: NSStatusItem?
    private var appState: AppState?
    private var sessionObservationTask: Task<Void, Never>?

    func startObserving(appState: AppState) {
        self.appState = appState
        createStatusItem()
        startSessionObservation()
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "🤖 0/0"
        }
        item.menu = makeMenu()
        statusItem = item
    }

    private func startSessionObservation() {
        sessionObservationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                withObservationTracking {
                    _ = self?.appState?.sessions
                } onChange: {
                    Task { @MainActor in self?.updateIndicator() }
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func updateIndicator() {
        guard let appState, let button = statusItem?.button else { return }
        let activeCount = appState.sessions.values
            .filter { $0.status == .running || $0.status == .processing }
            .count
        let idleCount = appState.sessions.values
            .filter { $0.status == .idle }
            .count
        button.title = "🤖 \(activeCount)/\(idleCount)"
        rebuildMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        return menu
    }

    private func rebuildMenu() {
        guard let menu = statusItem?.menu, let appState else { return }
        menu.removeAllItems()

        let sortedIds = appState.sessions.keys.sorted()
        let displayIds = sortedIds.prefix(10)

        if displayIds.isEmpty {
            let item = NSMenuItem(title: L10n.shared["status_no_sessions"], action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        for id in displayIds {
            let session = appState.sessions[id]
            let statusEmoji = statusEmojiFor(session?.status ?? .idle)
            let paddedLabel = (session?.sourceLabel ?? "Unknown").padding(toLength: 12, withPad: " ", startingAt: 0)
            let title = "\(paddedLabel)\(statusEmoji)"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        if sortedIds.count > 10 {
            let moreText = String(format: L10n.shared["status_more"], sortedIds.count - 10)
            let moreItem = NSMenuItem(title: moreText, action: nil, keyEquivalent: "")
            moreItem.isEnabled = false
            menu.addItem(moreItem)
        }

        menu.addItem(NSMenuItem.separator())

        let activeCount = appState.sessions.values.filter { $0.status == .running || $0.status == .processing }.count
        let idleCount = appState.sessions.values.filter { $0.status == .idle }.count
        let summary = "\(L10n.shared["status_active_count"]) \(activeCount)  \(L10n.shared["status_idle_count"]) \(idleCount)"
        let summaryItem = NSMenuItem(title: summary, action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)
    }

    private func statusEmojiFor(_ status: AgentStatus) -> String {
        switch status {
        case .running, .processing: return "🟢"
        case .waitingApproval, .waitingQuestion: return "🟡"
        case .idle: return "⚪"
        }
    }
}
```

### Modified File

**`Sources/CodeIsland/AppDelegate.swift`**

Insert initialization **between lines 22 and 27** (after `StatusItemController`, before `hookServer`):

```swift
// Line 22: existing
StatusItemController.shared.startObserving()

// INSERT HERE (new line after 22):
StatusIndicatorController.shared.startObserving(appState: appState)

// Line 27: existing (hookServer)
hookServer = HookServer(appState: appState)
```

**Positioning mechanism:**
- macOS status items created later appear further LEFT in the menu bar
- StatusIndicatorController initialized AFTER StatusItemController → appears on the LEFT side
- Order in menu bar: `[Status Indicator] [Menu Icon] ... other system icons`

## Display Format

**Icon:** SF Symbols emoji representation `🤖` (robot emoji)

**Status item length:** `NSStatusItem.variableLength` (to accommodate dynamic text width)

**Button composition:**
- Use `button.title` with emoji + text
- Format: `🤖 {active}/{idle}`
- Example: `🤖 3/1` means 3 active sessions, 1 idle

**Empty state (0 sessions):**
- Always show counts: `🤖 0/0`
- Button remains visible, menu shows "No active sessions"

**Number display:**
- Format: `{active}/{idle}`
- Active = sessions with status `.running` or `.processing`
- Idle = sessions with status `.idle`

**Status calculation (using actual AgentStatus enum):**
```swift
// AgentStatus enum values: idle, processing, running, waitingApproval, waitingQuestion
let activeCount = appState.sessions.values
    .filter { $0.status == .running || $0.status == .processing }
    .count

let idleCount = appState.sessions.values
    .filter { $0.status == .idle }
    .count
```

## Menu Structure

```
┌─────────────────────┐
│ Claude        🟢    │  ← green = running/processing
│ Codex         🟡    │  ← yellow = waitingApproval/waitingQuestion
│ Gemini        ⚪    │  ← gray = idle
│ ─────────────────── │  ← separator (when sessions exist)
│ Active: 3  Idle: 1 │  ← summary row
└─────────────────────┘
```

**Status icon mapping (actual AgentStatus enum values):**

| AgentStatus | Display | Description |
|-------------|---------|-------------|
| `.running` / `.processing` | 🟢 (green circle) | Agent actively working |
| `.waitingApproval` / `.waitingQuestion` | 🟡 (yellow circle) | Agent waiting for user input |
| `.idle` | ⚪ (gray circle) | Agent inactive |

**Menu item implementation:**
- Use emoji circles embedded in `NSMenuItem.title`
- Right-align status emoji at 12-character width: pad with spaces
- Example: `let paddedLabel = name.padding(toLength: 12, withPad: " ", startingAt: 0); title = "\(paddedLabel)🟢"`
- Use `session.sourceLabel` property (already exists in `SessionSnapshot.swift`)

**Session ordering:**
- Sort by session ID (alphabetical order)
- Consistent with existing `appState.sessions.keys.sorted()` pattern

**Localization keys to add in `L10n.swift`:**
Add to each language dictionary (`en`, `zh`, `tr`) in the "Session grouping" section (around lines 238-247):
- `"status_no_sessions"` → "No active sessions" / "无活跃会话" / "Aktif oturum yok"
- `"status_active_count"` → "Active:" / "活跃:" / "Aktif:"
- `"status_idle_count"` → "Idle:" / "空闲:" / "Boş:"
- `"status_more"` → "... and %d more" / "... 还有 %d 个" / "... ve %d daha"

**Empty state:**
- Display localized "No active sessions" when no sessions exist

**Menu items:**
- Non-clickable, pure informational display
- No action buttons (keep minimal)

**Max session count:** Show up to 10 sessions in menu; if more exist, add localized "... and N more" item at bottom

## State Update Mechanism

**Data flow:**

```
AppState.sessions (@Observable)
    │
    └── StatusIndicatorController subscribes
            │
            └── withObservationTracking loop
                    │
                    └── updateIndicator() called on change
                            │
                            ├── Recalculate counts
                            ├── Update button display
                            └── Rebuild menu items
```

**Observation implementation:**

```swift
private var sessionObservationTask: Task<Void, Never>?

private func startSessionObservation() {
    sessionObservationTask = Task { @MainActor [weak self] in
        while !Task.isCancelled {
            withObservationTracking {
                _ = self?.appState?.sessions
            } onChange: {
                Task { @MainActor in self?.updateIndicator() }
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}

// Note: Task automatically cancelled when app terminates;
// NSStatusBar.statusItem is also auto-removed by AppKit.
```

**Menu rebuild:**
- Clear menu and re-add all session items on each update
- Sort sessions by ID (alphabetical): `sessions.keys.sorted()`
- Limit to 10 sessions max; add "... and N more" if overflow
- Add separator and summary row at bottom

## Implementation Checklist

1. Create `StatusIndicatorController.swift` with full implementation
2. Add localization keys to `L10n.swift` in each language dictionary (`en`, `zh`, `tr`) in the "Session grouping" section (around lines 238-247):
   - `"status_no_sessions"` → "No active sessions"
   - `"status_active_count"` → "Active:"
   - `"status_idle_count"` → "Idle:"
   - `"status_more"` → "... and %d more"
3. Add `StatusIndicatorController.shared.startObserving(appState: appState)` call in `AppDelegate` between lines 22 and 27
4. Test status display updates when sessions change
5. Test menu popup shows correct session list
6. Test empty state (no sessions)

## Notes

- Keep controller independent from `StatusItemController`
- Reuse existing `AppState` session data, no new state needed
- Menu items are static display, no click handlers required
- Use `L10n.shared` for localized text: "No active sessions", "Active:", "Idle:"
- Display name: use `session.sourceLabel` (no special handling for remote sessions in this iteration)