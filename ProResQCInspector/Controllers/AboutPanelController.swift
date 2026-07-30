import SwiftUI
import AppKit

final class AboutPanelController {
    static let shared = AboutPanelController()

    private var panel: NSPanel?

    func show() {
        if panel == nil {
            let contentView = AboutWindowView()

            let hosting = NSHostingController(rootView: contentView)
            hosting.view.frame = NSRect(x: 0, y: 0, width: 360, height: 430)

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 430),
                styleMask: [.titled, .closable, .utilityWindow],
                backing: .buffered,
                defer: false
            )

            panel.title = "About Media QC Inspector"
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.transient, .ignoresCycle]
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.contentViewController = hosting

            self.panel = panel
        }

        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
