import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: LauncherPanel!
    var hotKeyManager: HotKeyManager!
    private var viewModel: ProjectsViewModel!
    private var escapeMonitor: Any?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // Create view model
        viewModel = AppDependencies.makeViewModel()
        viewModel.onAppButtonClicked = { [weak self] in
            self?.hidePanel(animated: true)
        }

        // Create SwiftUI content view
        let contentView = ContentView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: contentView)

        // Create and configure panel
        panel = LauncherPanel(contentView: hostingView)

        // Set up notification for when panel loses focus
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )

        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Worky Launcher")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }

        // Register global hotkey (F1)
        hotKeyManager = HotKeyManager { [weak self] in
            Task { @MainActor in
                self?.togglePanel()
            }
        }

        // F1 key is keyCode 122
        let registered = hotKeyManager.register(
            keyCode: 122,
            modifiers: 0  // No modifiers, just F1
        )

        if !registered {
            print("Warning: Could not register global hotkey")
        }

        // Set up escape key monitoring
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event } // 53 is Escape
            self?.hidePanel(animated: true)
            return nil
        }

        print("Launcher ready. Press F1 to activate or click the menu bar icon.")
    }

    @objc private func statusBarButtonClicked() {
        showPanel()
    }

    @objc private func panelDidResignKey() {
        // Hide when clicking outside the panel
        hidePanel(animated: true)
    }

    private func togglePanel() {
        if panel.isVisible {
            hidePanel(animated: true)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        viewModel.refreshActiveWorktreeFromGhostty()
        panel.show()
        // Load data when showing
        viewModel.load()
    }

    private func hidePanel(animated: Bool) {
        panel.hide(animated: animated)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.unregister()
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
