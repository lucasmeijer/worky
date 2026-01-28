import Cocoa
import SwiftUI

class LauncherPanel: NSPanel {
    private let panelWidth: CGFloat = 400
    private var contentSizeObserver: NSKeyValueObservation?

    init(contentView: NSView) {
        let panelWidth: CGFloat = 400
        let initialHeight: CGFloat = 600

        // Position on left side of screen
        let screen = NSScreen.main!
        let screenRect = screen.visibleFrame
        let panelRect = NSRect(
            x: screenRect.minX,
            y: (screenRect.height - initialHeight) / 2,
            width: panelWidth,
            height: initialHeight
        )

        super.init(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        self.level = .floating
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false  // We'll handle this manually
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovable = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Make it so it can become key to receive keyboard events
        self.becomesKeyOnlyIfNeeded = false

        // Observe content view size changes
        contentSizeObserver = contentView.observe(\.frame) { [weak self] view, _ in
            Task { @MainActor in
                self?.adjustSizeToFitContent(view: view)
            }
        }
    }

    private func adjustSizeToFitContent(view: NSView) {
        guard let screen = NSScreen.main else { return }

        // Get the intrinsic content size
        let fittingSize = view.fittingSize
        let screenRect = screen.visibleFrame

        // Cap the height to screen height with some padding
        let maxHeight = screenRect.height - 100
        let newHeight = min(fittingSize.height, maxHeight)

        // Only resize if the change is significant
        if abs(newHeight - frame.height) > 10 {
            let newFrame = NSRect(
                x: frame.minX,
                y: screenRect.minY + (screenRect.height - newHeight) / 2,
                width: panelWidth,
                height: newHeight
            )

            setFrame(newFrame, display: true, animate: isVisible)
        }
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    func show() {
        // Adjust size to fit content before showing
        if let contentView = contentView {
            adjustSizeToFitContent(view: contentView)
        }

        // Position on left side of current screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelHeight = frame.height
            let panelRect = NSRect(
                x: screenRect.minX,
                y: (screenRect.height - panelHeight) / 2 + screenRect.minY,
                width: frame.width,
                height: panelHeight
            )
            setFrame(panelRect, display: false)
        }

        // Show instantly (no animation)
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            animator().alphaValue = 1.0
        }
    }

    func hide(animated: Bool = true, completion: (@MainActor @Sendable () -> Void)? = nil) {
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                // Slide to the left
                let currentFrame = self.frame
                let hiddenFrame = NSRect(
                    x: currentFrame.minX - currentFrame.width,
                    y: currentFrame.minY,
                    width: currentFrame.width,
                    height: currentFrame.height
                )
                animator().setFrame(hiddenFrame, display: true)
                animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor in
                    self.orderOut(nil)
                    completion?()
                }
            })
        } else {
            orderOut(nil)
            completion?()
        }
    }
}
