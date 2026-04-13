import AppKit

@MainActor
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private lazy var menu: NSMenu = makeMenu()

    func startObserving() {
        showStatusItem()
    }

    private func showStatusItem() {
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = item.button {
                let icon = SettingsWindowController.bundleAppIcon()
                icon.size = NSSize(width: 18, height: 18)
                button.image = icon
                button.imageScaling = .scaleProportionallyDown
            }
            item.menu = menu
            statusItem = item
        }
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

    @objc private func openSettings() {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
