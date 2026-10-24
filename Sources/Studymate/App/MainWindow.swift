import AppKit
import SwiftUI

/// The single document-less window: translucent backdrop (NSVisualEffectView + optional skin tint) hosting the SwiftUI root.
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let backdrop = NSVisualEffectView()
    private let tintView = NSView()

    init<Content: View>(root: Content) {
        let size = DebugEnv.windowSize ?? CGSize(width: 1180, height: 760)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Studymate"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 920, height: 620)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unifiedCompact

        backdrop.material = .underWindowBackground
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.autoresizingMask = [.width, .height]

        tintView.wantsLayer = true
        tintView.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        hosting.sizingOptions = []

        backdrop.frame = NSRect(origin: .zero, size: size)
        tintView.frame = backdrop.bounds
        hosting.frame = backdrop.bounds
        backdrop.addSubview(tintView)
        backdrop.addSubview(hosting)
        window.contentView = backdrop

        super.init(window: window)
        window.delegate = self
        if DebugEnv.windowSize == nil {
            window.setFrameAutosaveName("StudymateMain")
            if !window.setFrameUsingName("StudymateMain") { window.center() }
        } else {
            window.center()
        }
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError() }

    func applyTheme() {
        let theme = ThemeManager.shared.current
        window?.appearance = ThemeManager.shared.effectiveAppearance
        tintView.layer?.backgroundColor = theme.tint?.cgColor
    }

    /// PNG of this window (own-window capture, no screen-recording permission needed).
    func writeSnapshot(to path: String) {
        guard let window else { return }
        let image: CGImage?
        if DebugEnv.snapshotIncludesSheets, let screen = window.screen ?? NSScreen.main {
            // Everything on screen inside the window's frame: the window plus its sheets and popovers (all ours).
            let f = window.frame
            let rect = CGRect(x: f.minX - screen.frame.minX, y: screen.frame.maxY - f.maxY, width: f.width, height: f.height)
            image = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
        } else {
            let windowID = CGWindowID(window.windowNumber)
            image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution])
        }
        guard let image else {
            NSLog("Studymate: snapshot failed")
            return
        }
        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            NSLog("Studymate: snapshot written to %@", path)
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}
