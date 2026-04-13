import AppKit
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
        let totalCount = appState.sessions.count
        button.title = "🤖 \(activeCount)/\(totalCount)"
        rebuildMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

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
        // Menu is static (Settings + Quit), no rebuild needed
    }

    @objc private func openSettings() {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

}
