import AppKit
import SwiftUI
import CodeIslandCore

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
            button.image = drawStatusIcon(color: .gray)
            button.imagePosition = .imageLeft
            button.title = " 0/0"
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
        let totalCount = appState.sessions.count

        let color: NSColor
        if totalCount > 0 && activeCount == totalCount {
            color = .systemRed
        } else if activeCount > 0 {
            color = .systemGreen
        } else {
            color = .gray
        }

        button.image = drawStatusIcon(color: color)
        button.imagePosition = .imageLeft
        button.title = " \(activeCount)/\(totalCount)"
        rebuildMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let sessionListItem = NSMenuItem(
            title: L10n.shared["session_list"],
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        sessionListItem.target = self
        menu.addItem(sessionListItem)

        let clearItem = NSMenuItem(
            title: L10n.shared["clear_all_sessions"],
            action: #selector(clearAllSessions),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: L10n.shared["settings_ellipsis"],
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.shared["quit"],
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func rebuildMenu() {
        // Menu is static, no rebuild needed
    }

    @objc private func togglePanel() {
        guard let appState else { return }
        if appState.surface.isExpanded {
            withAnimation(NotchAnimation.close) { appState.surface = .collapsed }
        } else {
            withAnimation(NotchAnimation.open) {
                appState.surface = .sessionList
                appState.cancelCompletionQueue()
                if appState.activeSessionId == nil {
                    appState.activeSessionId = appState.sessions.keys.sorted().first
                }
            }
        }
    }

    @objc private func clearAllSessions() {
        guard let appState else { return }
        appState.sessions.removeAll()
        withAnimation(NotchAnimation.close) { appState.surface = .collapsed }
        updateIndicator()
    }

    @objc private func openSettings() {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Draw a status ring icon in the given color (18×18 pt).
    private func drawStatusIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: 9, y: 9)

            // Outer ring: diameter 12pt, stroke 1.5pt, round cap
            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: 5.25, startAngle: 0, endAngle: 360)
            ring.lineWidth = 1.5
            ring.lineCapStyle = .round
            color.setStroke()
            ring.stroke()

            // Center dot: diameter 3pt, solid fill
            let dot = NSBezierPath(ovalIn: NSRect(x: 7.5, y: 7.5, width: 3, height: 3))
            color.setFill()
            dot.fill()

            return true
        }
        image.isTemplate = false
        return image
    }

}
