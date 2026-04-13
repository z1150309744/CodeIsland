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
            guard let session = appState.sessions[id] else { continue }
            let emoji = statusEmoji(for: session.status)
            let label = session.sourceLabel.padding(toLength: 12, withPad: " ", startingAt: 0)
            let item = NSMenuItem(title: "\(label)\(emoji)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        if sortedIds.count > 10 {
            let remaining = sortedIds.count - 10
            let moreItem = NSMenuItem(
                title: String(format: L10n.shared["status_more"], remaining),
                action: nil, keyEquivalent: ""
            )
            moreItem.isEnabled = false
            menu.addItem(moreItem)
        }

        menu.addItem(NSMenuItem.separator())

        let activeCount = appState.sessions.values.filter { $0.status == .running || $0.status == .processing }.count
        let totalCount = appState.sessions.count
        let summary = "\(L10n.shared["status_active_count"]) \(activeCount)  \(L10n.shared["status_total_count"]) \(totalCount)"
        let summaryItem = NSMenuItem(title: summary, action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)
    }

    private func statusEmoji(for status: AgentStatus) -> String {
        switch status {
        case .running, .processing: return "🟢"
        case .waitingApproval, .waitingQuestion: return "🟡"
        case .idle: return "⚪"
        }
    }
}
